import SwiftUI

/// Shared visual language.
///
/// Generated imagery reads better against a neutral dark ground, so the app
/// pins itself to a dark appearance rather than following the system theme.
enum Theme {
    static let accent = Color(red: 0.78, green: 0.64, blue: 0.42)      // warm gold
    static let accentBright = Color(red: 0.87, green: 0.74, blue: 0.51)

    static let canvas = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let surface = Color(red: 0.071, green: 0.071, blue: 0.078)
    static let raised = Color(red: 0.118, green: 0.118, blue: 0.129)
    static let hairline = Color.white.opacity(0.10)

    static let text = Color(red: 0.957, green: 0.937, blue: 0.906)
    static let textDim = Color(red: 0.659, green: 0.643, blue: 0.616)
    static let textFaint = Color(red: 0.436, green: 0.424, blue: 0.404)

    static let danger = Color(red: 0.886, green: 0.447, blue: 0.357)

    static let cardRadius: CGFloat = 14
}

extension View {
    /// Standard panel treatment: raised surface, hairline border, rounded.
    func panel(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}
