import SwiftUI

/// First-run gate. Fabrik cannot do anything without a key, so this blocks the
/// UI until one is saved rather than letting every action fail.
struct OnboardingView: View {
    @Environment(StudioModel.self) private var studio

    @State private var draft = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Fabrik")
                    .font(.largeTitle.weight(.bold))

                Text("AI asset creation, powered by fal.ai")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .padding(.top, 2)

                Text("Fabrik ships with no API key of its own. Paste yours to get started — it is stored in your Keychain and sent only to fal. Generations are billed to your own fal account.")
                    .font(.callout)
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)

                SecureField("fal-…", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding(10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(errorMessage == nil ? Theme.hairline : Theme.danger, lineWidth: 1)
                    )
                    .padding(.top, 18)
                    .onSubmit(save)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 6)
                }

                Button(action: save) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(Theme.canvas)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                .padding(.top, 12)

                Link("Get a key at fal.ai/dashboard/keys ↗",
                     destination: URL(string: "https://fal.ai/dashboard/keys")!)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 14)
            }
            .frame(maxWidth: 420)
            .padding(28)
        }
        .onAppear { isFocused = true }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try studio.saveAPIKey(trimmed)
            draft = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
