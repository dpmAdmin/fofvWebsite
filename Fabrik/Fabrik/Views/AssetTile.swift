import AVKit
import SwiftUI
import UniformTypeIdentifiers

/// A generated asset: preview, plus save / re-run / open actions.
struct AssetTile: View {
    let asset: Asset
    var showsRemove: Bool = true

    @Environment(StudioModel.self) private var studio
    @Environment(AssetStore.self) private var store

    @State private var player: AVPlayer?
    @State private var isPreparingExport = false
    @State private var exportDocument: ExportedFile?
    @State private var showingExporter = false
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(Theme.canvas)
                .clipped()

            details
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: suggestedFilename
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch asset.output.kind {
        case .image:
            AsyncImage(url: asset.output.url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    expiredPlaceholder
                default:
                    ProgressView().controlSize(.small)
                }
            }

        case .video:
            VideoPlayer(player: player)
                .task {
                    // Built once here rather than in `body`, which would create
                    // a new player on every re-render.
                    if player == nil { player = AVPlayer(url: asset.output.url) }
                }
        }
    }

    private var expiredPlaceholder: some View {
        VStack(spacing: 5) {
            Image(systemName: "clock.badge.xmark")
                .foregroundStyle(Theme.textFaint)
            Text("This file is no longer available.")
                .font(.caption2)
            Text("fal expires stored outputs — save anything you want to keep.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.textDim)
        .padding(12)
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(asset.modelTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(asset.createdAt, format: .relative(presentation: .numeric))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
            }

            if let prompt = asset.promptPreview {
                Text(prompt)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let exportError {
                Text(exportError)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.danger)
            }

            HStack(spacing: 6) {
                actionButton(isPreparingExport ? "Saving…" : "Save") {
                    Task { await prepareExport() }
                }
                .disabled(isPreparingExport)

                actionButton("Re-run") { studio.rerun(asset) }

                ShareLink(item: asset.output.url) {
                    Text("Share").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 6))

                if showsRemove {
                    Spacer(minLength: 0)
                    Button {
                        store.remove(asset)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove from library")
                }
            }
            .padding(.top, 2)
        }
        .padding(10)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export
    //
    // fal's CDN is remote, so saving means downloading the bytes first and then
    // handing them to the system's save panel.

    private func prepareExport() async {
        isPreparingExport = true
        exportError = nil
        defer { isPreparingExport = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: asset.output.url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                exportError = http.statusCode == 404
                    ? "This file has expired on fal's servers."
                    : "Could not download this file (HTTP \(http.statusCode))."
                return
            }
            exportDocument = ExportedFile(data: data)
            showingExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var exportContentType: UTType {
        if let contentType = asset.output.contentType,
           let type = UTType(mimeType: contentType) {
            return type
        }
        return asset.output.kind == .video ? .mpeg4Movie : .png
    }

    private var suggestedFilename: String {
        let stamp = asset.createdAt.formatted(.iso8601.year().month().day())
        return "fabrik-\(asset.modelId)-\(stamp)"
    }
}

/// Minimal `FileDocument` used only to hand downloaded bytes to the save panel.
struct ExportedFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
