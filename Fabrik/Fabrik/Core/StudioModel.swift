import Foundation
import Observation

enum JobPhase: Equatable, Sendable {
    case idle
    case uploading
    case queued(position: Int?)
    case running
    case finished
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .uploading, .queued, .running: return true
        case .idle, .finished, .failed: return false
        }
    }

    var label: String {
        switch self {
        case .idle: return ""
        case .uploading: return "Uploading source files"
        case .queued(let position):
            if let position, position > 0 { return "Queued at fal — position \(position)" }
            return "Queued at fal"
        case .running: return "Generating"
        case .finished: return "Done"
        case .failed: return "Failed"
        }
    }
}

/// What the sidebar has selected.
enum SidebarItem: Hashable, Sendable {
    case model(String)
    case library
}

/// The app's single source of truth for the generate screen.
@MainActor
@Observable
final class StudioModel {
    /// Navigation lives here rather than in `RootView` so that actions taken
    /// elsewhere — notably "Re-run" from the library — can move the sidebar.
    var sidebarSelection: SidebarItem? = .model(Catalog.models[0].id)

    // Selection and form.
    //
    // Changing models must also clear the form, which is done through `select`
    // rather than a `didSet` observer: `@Observable` rewrites stored properties
    // into computed accessors, and property observers do not mix cleanly with
    // that. An explicit method is unambiguous.
    private(set) var selectedModel: FalModel = Catalog.models[0]
    var values: [String: JSONValue] = [:]
    var showValidation = false

    // Job
    private(set) var phase: JobPhase = .idle
    private(set) var logs: [String] = []
    private(set) var results: [Asset] = []
    private(set) var startedAt: Date?

    // API key
    private(set) var apiKey: String?
    var hasAPIKey: Bool { !(apiKey ?? "").isEmpty }

    let store: AssetStore
    private let client = FalClient()
    private var jobTask: Task<Void, Never>?

    init(store: AssetStore = AssetStore()) {
        self.store = store
        self.apiKey = KeychainStore.read()
        self.values = InputBuilder.initialValues(model: selectedModel)
    }

    // MARK: - API key

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try KeychainStore.save(trimmed)
        apiKey = trimmed
    }

    func clearAPIKey() {
        KeychainStore.delete()
        apiKey = nil
    }

    // MARK: - Form

    /// Switches models and clears the form. A no-op if already selected, so
    /// re-entrant navigation updates do not wipe a form mid-edit.
    func select(_ model: FalModel) {
        guard model.id != selectedModel.id else { return }
        selectedModel = model
        resetForm()
    }

    private func resetForm() {
        values = InputBuilder.initialValues(model: selectedModel)
        showValidation = false
        results = []
        logs = []
        phase = .idle
    }

    var missingFields: [Field] {
        InputBuilder.missingRequired(model: selectedModel, values: values)
    }

    /// Loads a past generation's inputs back into the form and navigates to it.
    ///
    /// Re-run is triggered from the library, so it has to move the sidebar too
    /// — otherwise the form is repopulated on a screen the user cannot see.
    func rerun(_ asset: Asset) {
        guard let model = Catalog.model(id: asset.modelId) else { return }

        // `select` clears the form, so the prefill has to be applied after it.
        select(model)
        sidebarSelection = .model(model.id)
        values = InputBuilder.initialValues(model: model, prefill: asset.input)

        showValidation = false
        results = []
        logs = []
        phase = .idle
    }

    // MARK: - Uploads

    /// Uploads a local file to fal storage and returns its URL.
    func upload(data: Data, filename: String, contentType: String) async throws -> URL {
        guard let key = apiKey, !key.isEmpty else { throw FalError.missingAPIKey }
        return try await client.upload(
            data: data,
            filename: filename,
            contentType: contentType,
            apiKey: key
        )
    }

    // MARK: - Generation

    func generate() {
        guard !phase.isBusy else { return }

        guard let key = apiKey, !key.isEmpty else {
            phase = .failed(FalError.missingAPIKey.localizedDescription)
            return
        }

        guard missingFields.isEmpty else {
            showValidation = true
            return
        }

        let model = selectedModel
        let input = InputBuilder.build(model: model, values: values)

        phase = .queued(position: nil)
        startedAt = Date()
        logs = []
        results = []

        jobTask = Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await self.client.run(
                    endpointId: model.endpointId,
                    input: input,
                    apiKey: key,
                    onUpdate: { status in
                        Task { @MainActor [weak self] in
                            self?.apply(status: status)
                        }
                    }
                )

                let outputs = OutputExtractor.extract(from: outcome.result, fallback: model.outputKind)
                guard !outputs.isEmpty else {
                    self.phase = .failed(FalError.noOutput.localizedDescription)
                    return
                }

                let assets = outputs.map { output in
                    Asset(
                        modelId: model.id,
                        modelTitle: model.title,
                        endpointId: model.endpointId,
                        input: input,
                        output: output,
                        requestId: outcome.requestId
                    )
                }

                self.results = assets
                self.phase = .finished
                self.store.add(assets)
            } catch is CancellationError {
                self.phase = .idle
                self.logs = []
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        jobTask?.cancel()
        jobTask = nil
    }

    private func apply(status: FalClient.StatusResponse) {
        if status.isInQueue {
            phase = .queued(position: status.queuePosition)
        } else if !status.isCompleted {
            phase = .running
        }

        if let entries = status.logs, !entries.isEmpty {
            logs = entries.map(\.message).filter { !$0.isEmpty }
        }
    }
}
