import SwiftUI
import UIKit

/// Single-line text that auto-scrolls horizontally when its content
/// overflows the available width, otherwise renders as a regular Text.
///
/// Uses a "cylinder" pattern when scrolling: two copies of the text laid
/// out side-by-side with a fixed gap, the whole pair sliding leftward
/// continuously so the second copy reaches the start position exactly as
/// the first scrolls out — looks like a seamless loop with no jump.
///
/// Natural text width is measured via `NSAttributedString.size()` against
/// the supplied UIFont (the only reliable way; SwiftUI's `Font` doesn't
/// expose enough metrics for this). Layout is done inside a
/// GeometryReader so the marquee/static decision is recomputed when the
/// container resizes (e.g. on rotation, or when an adaptive grid changes
/// column count).
struct MarqueeText: View {
    let text: String
    var uiFont: UIFont = .preferredFont(forTextStyle: .caption1)
    var color: Color = .secondary
    /// Scrolling speed, in points per second.
    var speed: CGFloat = 28
    /// Gap inserted between the two copies (also between the tail of
    /// one loop and the head of the next).
    var gap: CGFloat = 32

    var body: some View {
        let naturalWidth = measuredWidth(text: text, font: uiFont)
        GeometryReader { container in
            let needsScroll = naturalWidth > container.size.width && container.size.width > 0
            ZStack(alignment: .leading) {
                if needsScroll {
                    TimelineView(.animation) { timeline in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        let distance = naturalWidth + gap
                        let phase = CGFloat(
                            (elapsed * Double(speed))
                                .truncatingRemainder(dividingBy: Double(distance))
                        )
                        HStack(spacing: gap) {
                            singleLine
                            singleLine
                        }
                        .offset(x: -phase)
                    }
                } else {
                    singleLine
                }
            }
            .frame(width: container.size.width, alignment: .leading)
            .clipped()
        }
        // Fix vertical extent to a single line of the given font; without
        // this the GeometryReader fills its parent's full height.
        .frame(height: uiFont.lineHeight)
    }

    private var singleLine: some View {
        Text(text)
            .font(Font(uiFont))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func measuredWidth(text: String, font: UIFont) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
    }
}
