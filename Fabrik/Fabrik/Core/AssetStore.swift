import Foundation
import Observation

/// The local asset library, persisted as a JSON file in Application Support.
///
/// A flat file rather than SwiftData or Core Data: the library is a small,
/// append-mostly list that is always loaded whole, so a database buys nothing
/// and costs a schema to migrate.
///
/// Only metadata and fal URLs are stored, never file bytes. fal expires stored
/// outputs, so old entries eventually point at files that 404 — the UI shows a
/// placeholder for those, and anything worth keeping should be exported.
@MainActor
@Observable
final class AssetStore {
    private(set) var assets: [Asset] = []
    private(set) var loadError: String?

    private let fileURL: URL

    init(filename: String = "library.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL.temporaryDirectory
        let directory = base.appendingPathComponent("Fabrik", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(filename)

        load()
    }

    // MARK: - Reading

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            assets = try decoder.decode([Asset].self, from: data).sorted { $0.createdAt > $1.createdAt }
        } catch {
            // A corrupt library should not stop the app from generating.
            loadError = "Could not read your library: \(error.localizedDescription)"
            assets = []
        }
    }

    // MARK: - Writing

    func add(_ newAssets: [Asset]) {
        guard !newAssets.isEmpty else { return }
        assets.insert(contentsOf: newAssets, at: 0)
        persist()
    }

    func remove(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        persist()
    }

    func removeAll() {
        assets.removeAll()
        persist()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(assets)
            try data.write(to: fileURL, options: .atomic)
            loadError = nil
        } catch {
            loadError = "Could not save your library: \(error.localizedDescription)"
        }
    }

    // MARK: - Derived

    /// Model ids present in the library, with titles, for the filter bar.
    var presentModels: [(id: String, title: String)] {
        var order: [String] = []
        var titles: [String: String] = [:]
        for asset in assets where titles[asset.modelId] == nil {
            titles[asset.modelId] = asset.modelTitle
            order.append(asset.modelId)
        }
        return order.map { (id: $0, title: titles[$0] ?? $0) }
    }
}
