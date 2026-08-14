import SwiftUI

struct SettingsView: View {
    @Environment(StudioModel.self) private var studio

    @State private var draft = ""
    @State private var message: String?
    @State private var isError = false
    @State private var confirmingRemoval = false

    var body: some View {
        Form {
            Section {
                SecureField("fal-…", text: $draft)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                HStack {
                    Button("Save key") { save() }
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)

                    if studio.hasAPIKey {
                        Spacer()
                        Button("Remove", role: .destructive) { confirmingRemoval = true }
                    }
                }

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(isError ? Theme.danger : Theme.accent)
                }
            } header: {
                Text("fal API key")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        studio.hasAPIKey
                            ? "A key is saved in your Keychain. Enter a new one to replace it."
                            : "Fabrik has no key of its own — it uses yours, and generations are billed to your fal account."
                    )
                    Link("Get a key at fal.ai/dashboard/keys ↗",
                         destination: URL(string: "https://fal.ai/dashboard/keys")!)
                }
                .font(.caption)
            }

            Section {
                LabeledContent("Saved generations", value: "\(studio.store.assets.count)")
            } header: {
                Text("Library")
            } footer: {
                Text("Fabrik stores links to your generations, not the files themselves. fal expires stored outputs after a while, so save anything you want to keep.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Remove the saved API key?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove key", role: .destructive) {
                studio.clearAPIKey()
                draft = ""
                message = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() {
        do {
            try studio.saveAPIKey(draft)
            draft = ""
            isError = false
            message = "Saved to your Keychain."
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }
}
