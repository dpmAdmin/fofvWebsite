import Foundation

/// A thin client for the fal.ai queue and storage REST APIs.
///
/// There is no official fal SDK for Swift, so this speaks the HTTP API
/// directly. The shapes below mirror fal's queue protocol:
///
///   submit   POST https://queue.fal.run/{endpoint}
///            -> { request_id, status_url, response_url, cancel_url }
///   status   GET  {status_url}?logs=1
///   result   GET  {response_url}
///   cancel   PUT  {cancel_url}
///
/// Note that submit returns fully-formed URLs for the follow-up calls, and this
/// client uses them verbatim rather than rebuilding them from the endpoint id.
/// That keeps polling correct even if fal changes its URL layout.
///
/// Uploads are two steps: ask fal for a presigned URL, then PUT the bytes to it.
///
///   initiate POST https://rest.fal.ai/storage/upload/initiate?storage_type=fal-cdn-v3
///            -> { upload_url, file_url }
///   upload   PUT  {upload_url}   (presigned; no credentials)
///
/// The API key is passed per call rather than held here. The key lives in the
/// Keychain and is read on the main actor, so handing it in at the call site
/// avoids any cross-actor access to shared state.
struct FalClient: Sendable {
    private static let queueBase = "https://queue.fal.run"
    private static let restBase = "https://rest.fal.ai"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Types

    struct SubmitResponse: Decodable, Sendable {
        let requestId: String
        let statusURL: URL
        let responseURL: URL
        let cancelURL: URL?

        enum CodingKeys: String, CodingKey {
            case requestId = "request_id"
            case statusURL = "status_url"
            case responseURL = "response_url"
            case cancelURL = "cancel_url"
        }
    }

    struct LogEntry: Decodable, Sendable {
        let message: String
        let level: String?
    }

    struct StatusResponse: Decodable, Sendable {
        let status: String
        let queuePosition: Int?
        let logs: [LogEntry]?

        enum CodingKeys: String, CodingKey {
            case status
            case queuePosition = "queue_position"
            case logs
        }

        var isCompleted: Bool { status == "COMPLETED" }
        var isInQueue: Bool { status == "IN_QUEUE" }
    }

    private struct InitiateUploadResponse: Decodable {
        let uploadURL: URL
        let fileURL: URL

        enum CodingKeys: String, CodingKey {
            case uploadURL = "upload_url"
            case fileURL = "file_url"
        }
    }

    // MARK: - Queue

    /// Enqueues a job and returns the handles needed to follow it.
    func submit(
        endpointId: String,
        input: [String: JSONValue],
        apiKey: String
    ) async throws -> SubmitResponse {
        // Built as a string so the slashes inside an endpoint id (for example
        // "fal-ai/kling-video/v2/master/image-to-video") stay path separators.
        guard let url = URL(string: "\(Self.queueBase)/\(endpointId)") else {
            throw FalError.invalidURL
        }

        var request = try authorizedRequest(url: url, method: "POST", apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(input)

        return try decode(SubmitResponse.self, from: try await perform(request))
    }

    func status(
        statusURL: URL,
        apiKey: String,
        includeLogs: Bool = true
    ) async throws -> StatusResponse {
        var url = statusURL
        if includeLogs, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "logs", value: "1"))
            components.queryItems = items
            url = components.url ?? statusURL
        }

        let request = try authorizedRequest(url: url, method: "GET", apiKey: apiKey)
        return try decode(StatusResponse.self, from: try await perform(request))
    }

    /// Fetches the finished job's payload. Shape is model-specific, hence `JSONValue`.
    func result(responseURL: URL, apiKey: String) async throws -> JSONValue {
        let request = try authorizedRequest(url: responseURL, method: "GET", apiKey: apiKey)
        return try decode(JSONValue.self, from: try await perform(request))
    }

    func cancel(cancelURL: URL, apiKey: String) async throws {
        _ = try await perform(try authorizedRequest(url: cancelURL, method: "PUT", apiKey: apiKey))
    }

    /// Submits, polls to completion, and returns the result.
    ///
    /// `onUpdate` fires on every poll so the UI can show queue position and logs.
    /// Cancellation is cooperative: cancelling the surrounding `Task` also asks
    /// fal to cancel the job, so a dismissed screen does not keep burning credits.
    func run(
        endpointId: String,
        input: [String: JSONValue],
        apiKey: String,
        pollInterval: Duration = .seconds(1),
        onUpdate: @escaping @Sendable (StatusResponse) -> Void
    ) async throws -> (result: JSONValue, requestId: String) {
        let submission = try await submit(endpointId: endpointId, input: input, apiKey: apiKey)

        while true {
            if Task.isCancelled {
                if let cancelURL = submission.cancelURL {
                    // Best-effort: the job may already be running and unstoppable.
                    try? await cancel(cancelURL: cancelURL, apiKey: apiKey)
                }
                throw CancellationError()
            }

            let current = try await status(statusURL: submission.statusURL, apiKey: apiKey)
            onUpdate(current)

            if current.isCompleted {
                let payload = try await result(responseURL: submission.responseURL, apiKey: apiKey)
                return (payload, submission.requestId)
            }

            try await Task.sleep(for: pollInterval)
        }
    }

    // MARK: - Storage

    /// Uploads a file to fal storage and returns its public URL.
    func upload(
        data fileData: Data,
        filename: String,
        contentType: String,
        apiKey: String
    ) async throws -> URL {
        guard
            let initiateURL = URL(
                string: "\(Self.restBase)/storage/upload/initiate?storage_type=fal-cdn-v3"
            )
        else {
            throw FalError.invalidURL
        }

        var initiate = try authorizedRequest(url: initiateURL, method: "POST", apiKey: apiKey)
        initiate.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initiate.httpBody = try JSONEncoder().encode([
            "content_type": contentType,
            "file_name": filename,
        ])

        let ticket = try decode(InitiateUploadResponse.self, from: try await perform(initiate))

        // The upload URL is presigned — sending credentials to it can be
        // rejected as a signature mismatch, so this request is deliberately bare.
        var upload = URLRequest(url: ticket.uploadURL)
        upload.httpMethod = "PUT"
        upload.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (body, response) = try await session.upload(for: upload, from: fileData)
        try validate(response: response, data: body)

        return ticket.fileURL
    }

    // MARK: - Plumbing

    private func authorizedRequest(url: URL, method: String, apiKey: String) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw FalError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw FalError.network(error.localizedDescription)
        }

        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw FalError.http(status: http.statusCode, detail: FalClient.detail(from: data))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw FalError.decoding(String(describing: error))
        }
    }

    /// Pulls a readable message out of a fal error body.
    ///
    /// Validation failures arrive as `{"detail":[{"loc":[...],"msg":"..."}]}`,
    /// which is the most useful signal when a model's input schema has drifted.
    static func detail(from data: Data) -> String? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.isEmpty ? nil : text
        }

        guard let detail = root["detail"] else {
            return root["message"]?.stringValue
        }

        if let text = detail.stringValue { return text }
        guard let items = detail.arrayValue else { return nil }

        let messages: [String] = items.compactMap { item in
            guard let message = item["msg"]?.stringValue else { return nil }
            let field = item["loc"]?.arrayValue?
                .compactMap { $0.stringValue }
                .filter { $0 != "body" }
                .joined(separator: ".")
            if let field, !field.isEmpty { return "\(field): \(message)" }
            return message
        }

        return messages.isEmpty ? nil : messages.joined(separator: "; ")
    }
}

enum FalError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case network(String)
    case http(status: Int, detail: String?)
    case decoding(String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No fal API key is set. Add one in Settings."
        case .invalidURL:
            return "Could not build a valid fal URL."
        case .network(let message):
            return message
        case .http(let status, let detail):
            if let detail, !detail.isEmpty { return detail }
            switch status {
            case 401, 403:
                return "fal rejected the API key. Check it in Settings."
            case 402:
                return "Your fal account is out of credit."
            case 429:
                return "fal is rate limiting this key. Try again shortly."
            default:
                return "fal returned HTTP \(status)."
            }
        case .decoding(let message):
            return "Could not read fal's response. \(message)"
        case .noOutput:
            return "The job finished but returned no files. The model's output shape may have changed."
        }
    }
}
