import SwiftUI

enum VideoCoverLayout: Equatable {
    case landscape
    case hanimePortrait

    var aspectRatio: CGFloat {
        switch self {
        case .landscape: 16.0 / 9.0
        case .hanimePortrait: 268.0 / 394.0
        }
    }
}

struct VideoCardCover<Overlay: View>: View {
    let urlString: String?
    let resizeWidth: CGFloat
    let layout: VideoCoverLayout
    let cornerRadius: CGFloat
    private let overlay: Overlay

    init(
        urlString: String?,
        resizeWidth: CGFloat,
        layout: VideoCoverLayout,
        cornerRadius: CGFloat = 10,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.urlString = urlString
        self.resizeWidth = resizeWidth
        self.layout = layout
        self.cornerRadius = cornerRadius
        self.overlay = overlay()
    }

    var body: some View {
        ZStack {
            Color.gray.opacity(0.18)

            CachedRemoteImage(urlString: urlString, resizeWidth: resizeWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            overlay
        }
        .aspectRatio(layout.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension VideoCardCover where Overlay == EmptyView {
    init(
        urlString: String?,
        resizeWidth: CGFloat,
        layout: VideoCoverLayout,
        cornerRadius: CGFloat = 10
    ) {
        self.init(
            urlString: urlString,
            resizeWidth: resizeWidth,
            layout: layout,
            cornerRadius: cornerRadius,
            overlay: { EmptyView() }
        )
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
