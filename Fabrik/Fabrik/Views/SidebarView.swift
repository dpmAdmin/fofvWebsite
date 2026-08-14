import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    @Environment(AssetStore.self) private var store
    @Environment(StudioModel.self) private var studio
    @Environment(\.showSettings) private var showSettings

    var body: some View {
        List(selection: $selection) {
            ForEach(ModelCategory.allCases) { category in
                Section(category.title) {
                    ForEach(Catalog.models(in: category)) { model in
                        row(for: model)
                            .tag(SidebarItem.model(model.id))
                    }
                }
            }

            Section {
                Label {
                    HStack {
                        Text("Library")
                        Spacer()
                        if !store.assets.isEmpty {
                            Text("\(store.assets.count)")
                                .font(.caption)
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                } icon: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .tag(SidebarItem.library)
            }
        }
        .navigationTitle("Fabrik")
        .toolbar {
            ToolbarItem {
                Button {
                    showSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("fal API key and app settings")
            }
        }
    }

    private func row(for model: FalModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(studio.selectedModel.id == model.id ? Theme.accentBright : Theme.text)

            Text(model.blurb)
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
