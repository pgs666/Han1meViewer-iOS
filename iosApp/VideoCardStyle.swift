import SwiftUI

enum VideoCoverLayout {
    case landscape
    case hanimePortrait

    var aspectRatio: CGFloat {
        switch self {
        case .landscape: 16.0 / 9.0
        case .hanimePortrait: 268.0 / 394.0
        }
    }
}

private struct VideoCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cardBackground: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .secondarySystemBackground
                : .systemBackground
        })
    }
}

extension View {
    func videoCardSurface() -> some View {
        modifier(VideoCardSurfaceModifier())
    }
}

