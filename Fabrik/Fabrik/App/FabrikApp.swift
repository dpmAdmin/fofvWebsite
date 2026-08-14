import SwiftUI

@main
struct FabrikApp: App {
    @State private var studio = StudioModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(studio)
                .environment(studio.store)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(studio)
                .frame(width: 460)
        }
        #endif
    }
}
