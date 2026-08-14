import SwiftUI

struct GenerateView: View {
    @Environment(StudioModel.self) private var studio

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Side by side on Mac and iPad; stacked on iPhone.
    ///
    /// This is an explicit check rather than `ViewThatFits` because both
    /// layouts contain flexible children, so `ViewThatFits` would always pick
    /// the first one regardless of available width.
    private var isWide: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 20) {
                    form.frame(width: 380)
                    JobPanel().frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(20)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        formContent
                            .panel(padding: 18)
                        JobPanel()
                    }
                    .padding(16)
                }
            }
        }
        .background(Theme.canvas)
        .navigationTitle(studio.selectedModel.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Scrolling form, used on wide layouts where the column has a fixed height.
    private var form: some View {
        ScrollView {
            formContent.padding(18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(studio.selectedModel.title)
                    .font(.headline)
                Text(studio.selectedModel.blurb)
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(studio.selectedModel.fields) { field in
                FieldRow(field: field)
            }

            GenerateButton()
        }
    }
}

struct GenerateButton: View {
    @Environment(StudioModel.self) private var studio

    var body: some View {
        let busy = studio.phase.isBusy

        Button {
            studio.generate()
        } label: {
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small) }
                Text(busy ? "Working…" : buttonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(busy ? Theme.raised : Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(busy ? Theme.textDim : Theme.canvas)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private var buttonTitle: String {
        if let eta = studio.selectedModel.eta { return "Generate · \(eta)" }
        return "Generate"
    }
}
