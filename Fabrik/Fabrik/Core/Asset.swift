import Foundation

enum OutputKind: String, Codable, Sendable {
    case image
    case video
}

/// A single file produced by a generation.
struct AssetOutput: Codable, Hashable, Sendable {
    var url: URL
    var kind: OutputKind
    var contentType: String?
    var width: Int?
    var height: Int?
}

/// One completed generation, as kept in the local library.
///
/// Only metadata and the fal URL are stored, never the file bytes — see
/// `AssetStore` for what that means for longevity.
struct Asset: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var modelId: String
    var modelTitle: String
    var endpointId: String
    /// The exact payload sent to fal, so a generation can be reproduced.
    var input: [String: JSONValue]
    var output: AssetOutput
    /// fal's request id — worth quoting when asking fal support about a job.
    var requestId: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modelId: String,
        modelTitle: String,
        endpointId: String,
        input: [String: JSONValue],
        output: AssetOutput,
        requestId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modelId = modelId
        self.modelTitle = modelTitle
        self.endpointId = endpointId
        self.input = input
        self.output = output
        self.requestId = requestId
    }

    /// The prompt, when the model had one — used as the library caption.
    var promptPreview: String? {
        for key in ["prompt", "instruction"] {
            if let text = input[key]?.displayText, !text.isEmpty { return text }
        }
        return nil
    }
}

// MARK: - Output extraction

enum OutputExtractor {
    /// Pulls every produced file out of a fal response.
    ///
    /// fal endpoints do not share one output shape — some return
    /// `{ images: [...] }`, others `{ image: {...} }` or `{ video: {...} }`, and
    /// some nest files deeper. Rather than hard-coding a shape per model (which
    /// breaks silently when a model is versioned), this walks the response and
    /// collects anything that looks like a file, in the order it appears.
    static func extract(from payload: JSONValue, fallback: OutputKind) -> [AssetOutput] {
        var found: [AssetOutput] = []
        var seen: Set<URL> = []

        func classify(url: URL, contentType: String?) -> OutputKind {
            if let contentType {
                if contentType.hasPrefix("video/") { return .video }
                if contentType.hasPrefix("image/") { return .image }
            }
            switch url.pathExtension.lowercased() {
            case "mp4", "webm", "mov", "m4v": return .video
            case "png", "jpg", "jpeg", "webp", "gif", "avif": return .image
            default: return fallback
            }
        }

        func visit(_ node: JSONValue, depth: Int) {
            guard depth <= 6 else { return }

            switch node {
            case .object(let fields):
                if let urlString = fields["url"]?.stringValue, let url = URL(string: urlString) {
                    guard !seen.contains(url) else { return }
                    seen.insert(url)
                    let contentType = fields["content_type"]?.stringValue
                    found.append(
                        AssetOutput(
                            url: url,
                            kind: classify(url: url, contentType: contentType),
                            contentType: contentType,
                            width: fields["width"]?.intValue,
                            height: fields["height"]?.intValue
                        )
                    )
                    return
                }
                // Sort keys so repeated runs return files in a stable order.
                for key in fields.keys.sorted() {
                    if let value = fields[key] { visit(value, depth: depth + 1) }
                }

            case .array(let items):
                for item in items { visit(item, depth: depth + 1) }

            default:
                break
            }
        }

        visit(payload, depth: 0)
        return found
    }
}
