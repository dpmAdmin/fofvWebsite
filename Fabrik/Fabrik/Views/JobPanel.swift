import Combine
import SwiftUI

struct JobPanel: View {
    @Environment(StudioModel.self) private var studio

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch studio.phase {
            case .idle where studio.results.isEmpty:
                placeholder
            case .failed(let message):
                failure(message)
                results
            default:
                if studio.phase.isBusy { progress }
                results
            }
        }
    }

    // MARK: - States

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: studio.selectedModel.category.symbol)
                .font(.system(size: 28))
                .foregroundStyle(Theme.textFaint)

            Text(studio.selectedModel.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textDim)

            Text(studio.selectedModel.blurb)
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if let docsURL = studio.selectedModel.docsURL {
                Link("View this model on fal ↗", destination: docsURL)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(24)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Theme.hairline)
        )
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)

                Text(studio.phase.label)
                    .font(.subheadline.weight(.semibold))

                if let eta = studio.selectedModel.eta {
                    Text("typically \(eta)")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer()

                if let startedAt = studio.startedAt {
                    ElapsedLabel(since: startedAt)
                }

                Button("Cancel") { studio.cancel() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textDim)
            }

            if !studio.logs.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(studio.logs.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 110)
                .padding(8)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .panel()
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("That generation failed.", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.danger)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)

            if let docsURL = studio.selectedModel.docsURL {
                Text("If this names a field you are sending, the model's input schema has probably changed. Check it on fal and update Catalog.swift.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Link("Open the model on fal ↗", destination: docsURL)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.danger.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var results: some View {
        if !studio.results.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 14)],
                spacing: 14
            ) {
                ForEach(studio.results) { asset in
                    AssetTile(asset: asset, showsRemove: false)
                }
            }
        }
    }
}

/// Ticking elapsed-time readout, so a multi-minute video job never looks frozen.
struct ElapsedLabel: View {
    let since: Date

    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(format(now.timeIntervalSince(since)))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Theme.textFaint)
            .onReceive(tick) { now = $0 }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        if total < 60 { return "\(total)s" }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
