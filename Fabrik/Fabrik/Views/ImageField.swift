import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#endif

/// Source-image picker for `image` and `images` fields.
///
/// Files are uploaded to fal storage as soon as they are chosen, so the form's
/// value is always a plain URL. That is what makes "Re-run" work from the
/// library without needing the original file.
///
/// The picker differs by platform — Photos on iOS, the file importer on Mac —
/// but both funnel into the same `upload(data:filename:contentType:)` path.
struct ImageField: View {
    let field: Field

    @Environment(StudioModel.self) private var studio

    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var urlDraft = ""
    @State private var showingImporter = false

    #if os(iOS)
    @State private var photoItems: [PhotosPickerItem] = []
    #endif

    private var allowsMultiple: Bool { field.type == .images }

    private var urls: [String] {
        (studio.values[field.name]?.arrayValue ?? []).compactMap(\.stringValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !urls.isEmpty {
                thumbnails
            }

            if allowsMultiple || urls.isEmpty {
                picker
                pasteRow
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: allowsMultiple
        ) { result in
            handleImport(result)
        }
    }

    // MARK: - Pieces

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(Theme.textFaint)
                            default:
                                ProgressView().controlSize(.small)
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )

                        Button {
                            remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Theme.text, Theme.raised)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 5, y: -5)
                        .accessibilityLabel("Remove image \(index + 1)")
                    }
                    .overlay(alignment: .bottomLeading) {
                        if allowsMultiple && index == 0 {
                            Text("base")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Theme.canvas.opacity(0.85), in: Capsule())
                                .foregroundStyle(Theme.accent)
                                .padding(4)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var picker: some View {
        #if os(iOS)
        PhotosPicker(
            selection: $photoItems,
            maxSelectionCount: allowsMultiple ? 10 : 1,
            matching: .images
        ) {
            pickerLabel
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
        #else
        Button {
            showingImporter = true
        } label: {
            pickerLabel
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        #endif
    }

    private var pickerLabel: some View {
        VStack(spacing: 3) {
            Text(isUploading ? "Uploading…" : "Choose image\(allowsMultiple ? "s" : "")")
                .font(.subheadline.weight(.medium))
            Text(allowsMultiple ? "JPG, PNG, or WebP — add as many as you need" : "JPG, PNG, or WebP")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.hairline)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isUploading ? 0.6 : 1)
    }

    private var pasteRow: some View {
        HStack(spacing: 6) {
            TextField("…or paste an image URL", text: $urlDraft)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(7)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .onSubmit(addPastedURL)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif

            Button("Use", action: addPastedURL)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 7))
                .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
        }
    }

    // MARK: - Mutating the field value

    private func append(_ newURLs: [String]) {
        let combined = allowsMultiple ? urls + newURLs : Array(newURLs.prefix(1))
        studio.values[field.name] = .array(combined.map { JSONValue.string($0) })
    }

    private func remove(at index: Int) {
        var current = urls
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        studio.values[field.name] = .array(current.map { JSONValue.string($0) })
    }

    private func addPastedURL() {
        let trimmed = urlDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        append([trimmed])
        urlDraft = ""
    }

    // MARK: - Uploading

    private func upload(_ payloads: [(data: Data, filename: String, contentType: String)]) async {
        guard !payloads.isEmpty else { return }

        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        var uploaded: [String] = []
        do {
            for payload in payloads {
                let url = try await studio.upload(
                    data: payload.data,
                    filename: payload.filename,
                    contentType: payload.contentType
                )
                uploaded.append(url.absoluteString)
            }
            append(uploaded)
        } catch {
            errorMessage = error.localizedDescription
            // Keep whatever did upload rather than discarding successful work.
            if !uploaded.isEmpty { append(uploaded) }
        }
    }

    #if os(iOS)
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var payloads: [(data: Data, filename: String, contentType: String)] = []

        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let type = item.supportedContentTypes.first
            let contentType = type?.preferredMIMEType ?? "image/jpeg"
            let ext = type?.preferredFilenameExtension ?? "jpg"
            payloads.append((data, "upload-\(index + 1).\(ext)", contentType))
        }

        photoItems = []

        if payloads.isEmpty {
            errorMessage = "Could not read that image."
            return
        }
        await upload(payloads)
    }
    #endif

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription

        case .success(let fileURLs):
            var payloads: [(data: Data, filename: String, contentType: String)] = []

            for fileURL in fileURLs {
                // Files chosen through the importer are security-scoped; without
                // this the read fails inside the sandbox.
                let scoped = fileURL.startAccessingSecurityScopedResource()
                defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: fileURL) else { continue }
                let contentType = UTType(filenameExtension: fileURL.pathExtension)?
                    .preferredMIMEType ?? "image/jpeg"
                payloads.append((data, fileURL.lastPathComponent, contentType))
            }

            if payloads.isEmpty {
                errorMessage = "Could not read that file."
                return
            }
            Task { await upload(payloads) }
        }
    }
}
