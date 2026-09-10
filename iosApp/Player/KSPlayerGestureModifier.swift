import SwiftUI

/// Keeps the competing tap, pinch, long-press, and swipe recognizers in one
/// place. Gesture state and player commands stay owned by `KSPlayerView`;
/// this modifier only defines arbitration and forwards events.
struct KSPlayerGestureModifier: ViewModifier {
    let onDoubleTap: (CGPoint) -> Void
    let onSingleTap: () -> Void
    let onPinchChanged: () -> Void
    let onPinchEnded: (CGFloat) -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .exclusively(before: SpatialTapGesture())
                    .onEnded { gesture in
                        switch gesture {
                        case let .first(doubleTap):
                            onDoubleTap(doubleTap.location)
                        case .second:
                            onSingleTap()
                        }
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { _ in onPinchChanged() }
                    .onEnded(onPinchEnded)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(onDragChanged)
                    .onEnded { _ in onDragEnded() }
            )
    }
}
