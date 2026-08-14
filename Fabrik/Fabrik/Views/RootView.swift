import SwiftUI

struct RootView: View {
    @Environment(StudioModel.self) private var studio

    @State private var showingSettings = false

    var body: some View {
        @Bindable var studio = studio

        NavigationSplitView {
            SidebarView(selection: $studio.sidebarSelection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            switch studio.sidebarSelection {
            case .library:
                LibraryView()
            case .model, .none:
                GenerateView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .environment(\.showSettings, { showingSettings = true })
        .sheet(isPresented: $showingSettings) {
            // Environment is passed explicitly: sheets get their own hosting
            // context, and relying on inheritance here is a common source of
            // "no Observable object" crashes.
            SettingsSheet()
                .environment(studio)
        }
        // On first launch there is no key and nothing can run, so this is a
        // blocking overlay rather than a second sheet — stacking two `.sheet`
        // modifiers on one view is unreliable, and this state is not
        // dismissable anyway.
        .overlay {
            if !studio.hasAPIKey {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: studio.hasAPIKey)
        .onChange(of: studio.sidebarSelection) { _, newValue in
            if case .model(let id) = newValue, let model = Catalog.model(id: id) {
                studio.select(model)
            }
        }
    }
}

// MARK: - Settings presentation

/// Lets any view ask for the settings sheet without threading a binding down.
///
/// macOS also has a real Settings scene; this is the in-window route that works
/// identically on both platforms.
private struct ShowSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showSettings: () -> Void {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }
}
