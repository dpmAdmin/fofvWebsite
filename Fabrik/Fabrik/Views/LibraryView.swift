import SwiftUI

struct LibraryView: View {
    @Environment(AssetStore.self) private var store

    @State private var filter: String?
    @State private var confirmingClear = false

    private var visible: [Asset] {
        guard let filter else { return store.assets }
        return store.assets.filter { $0.modelId == filter }
    }

    var body: some View {
        Group {
            if store.assets.isEmpty {
                empty
            } else {
                populated
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Library")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            "Clear the whole library?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear \(store.assets.count) items", role: .destructive) {
                store.removeAll()
                filter = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes them from Fabrik. Files already saved to disk are untouched.")
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textFaint)
            Text("Nothing here yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textDim)
            Text("Everything you generate is saved here automatically.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var populated: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let message = store.loadError {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                filterBar

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 240), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(visible) { asset in
                        AssetTile(asset: asset)
                    }
                }
            }
            .padding(16)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                chip(title: "All (\(store.assets.count))", isActive: filter == nil) {
                    filter = nil
                }

                ForEach(store.presentModels, id: \.id) { entry in
                    chip(title: entry.title, isActive: filter == entry.id) {
                        filter = entry.id
                    }
                }

                Divider().frame(height: 16)

                Button("Clear library") { confirmingClear = true }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    isActive ? Theme.accent.opacity(0.16) : Theme.raised,
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Theme.accentBright : Theme.textDim)
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? Theme.accent.opacity(0.5) : Theme.hairline,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
