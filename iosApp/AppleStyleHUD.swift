import SwiftUI

/// Apple-Music-style centred HUD: a 200×200 rounded-rect material panel
/// with a single big SF Symbol over a bold caption. Same design family
/// as the system volume / AirPods-connected indicators. Caller renders
/// it inside an `.overlay(alignment: .center)` and is responsible for
/// the appear/disappear animation; this view only describes the panel.
struct AppleStyleHUD: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            iconView
                .font(.system(size: 72, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Text(message)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
        }
        .frame(width: 200, height: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    /// Icon glyph. iOS 17+ gets the smooth replace contentTransition so
    /// updating the systemImage while the HUD is on screen cross-fades
    /// the glyph; pre-17 falls back to a plain swap.
    @ViewBuilder
    private var iconView: some View {
        if #available(iOS 17.0, *) {
            Image(systemName: systemImage)
                .contentTransition(.symbolEffect(.replace))
        } else {
            Image(systemName: systemImage)
        }
    }
}
