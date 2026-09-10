import Han1meShared
import KSPlayer
import SwiftUI
import UIKit

struct KSPlayerControlsOverlay: View {
    let title: String
    let playbackSources: [VideoPlaybackSourceRow]
    let activeSource: VideoPlaybackSourceRow?
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    @Binding var isFullscreen: Bool
    let isPlaying: Bool
    @Binding var sliderValue: TimeInterval
    @Binding var isSliderEditing: Bool
    let bufferedFraction: Double
    @Binding var savedPlaybackRate: Float
    let onBack: () -> Void
    let onTogglePlayPause: () -> Void
    let onSelectSource: (VideoPlaybackSourceRow) -> Void
    let onCancelAutoHide: () -> Void
    let onScheduleAutoHide: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            KSPlayerIconButton(systemImage: "chevron.left", label: isFullscreen ? "退出全屏" : "返回") {
                if isFullscreen {
                    withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = false }
                } else {
                    onBack()
                }
            }
            if isFullscreen {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 8)
            KSPlayerIconButton(
                systemImage: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: coordinator.isMuted ? "取消静音" : "静音"
            ) {
                coordinator.isMuted.toggle()
            }
            KSPlayerIconButton(
                systemImage: coordinator.isScaleAspectFill
                    ? "rectangle.arrowtriangle.2.inward"
                    : "rectangle.arrowtriangle.2.outward",
                label: coordinator.isScaleAspectFill ? "适配" : "填充"
            ) {
                coordinator.isScaleAspectFill.toggle()
            }
        }
    }

    private var bottomBar: some View {
        let total = max(TimeInterval(coordinator.timemodel.totalTime), 1)
        return HStack(spacing: 10) {
            KSPlayerIconButton(
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "暂停" : "播放"
            ) {
                onTogglePlayPause()
                onScheduleAutoHide()
            }

            Text(KSPlayerDisplayFormatter.time(sliderValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)

            KSPlayerBufferedSlider(
                value: $sliderValue,
                range: 0...total,
                bufferedFraction: bufferedFraction,
                onEditingChanged: { editing in
                    if editing {
                        isSliderEditing = true
                        onCancelAutoHide()
                    } else {
                        isSliderEditing = false
                        coordinator.seek(time: sliderValue)
                        onScheduleAutoHide()
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .onAppear {
                if !isSliderEditing {
                    sliderValue = TimeInterval(coordinator.timemodel.currentTime)
                }
            }
            .onReceive(coordinator.timemodel.$currentTime) { newTime in
                guard !isSliderEditing else { return }
                let asTime = TimeInterval(newTime)
                if abs(asTime - sliderValue) > 0.5 {
                    sliderValue = asTime
                }
            }

            Text(KSPlayerDisplayFormatter.time(TimeInterval(coordinator.timemodel.totalTime)))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)

            playbackRateMenu

            if playbackSources.count > 1 {
                qualityMenu
            }

            KSPlayerIconButton(
                systemImage: isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right",
                label: isFullscreen ? "退出全屏" : "全屏"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) { isFullscreen.toggle() }
            }
        }
    }

    private var playbackRateMenu: some View {
        Menu {
            ForEach(KSPlayerDisplayFormatter.playbackRates, id: \.self) { rate in
                Button {
                    coordinator.playbackRate = rate
                    savedPlaybackRate = rate
                } label: {
                    HStack {
                        Text(KSPlayerDisplayFormatter.rate(rate))
                        Spacer()
                        if abs(coordinator.playbackRate - rate) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            menuLabel(KSPlayerDisplayFormatter.rate(coordinator.playbackRate))
        }
    }

    private var qualityMenu: some View {
        Menu {
            ForEach(playbackSources) { source in
                Button {
                    onSelectSource(source)
                } label: {
                    HStack {
                        Text(source.label)
                        Spacer()
                        if activeSource?.id == source.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            menuLabel(activeSource?.label ?? "画质")
        }
    }

    private func menuLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 38)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct KSPlayerBufferedSlider: UIViewRepresentable {
    @Binding var value: TimeInterval
    let range: ClosedRange<TimeInterval>
    let bufferedFraction: Double
    let onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> BufferedSliderView {
        let view = BufferedSliderView()
        view.slider.addTarget(context.coordinator, action: #selector(Coordinator.editingBegan), for: .touchDown)
        view.slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged), for: .valueChanged)
        view.slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingEnded),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        view.slider.accessibilityLabel = String(localized: "播放进度")
        return view
    }

    func updateUIView(_ uiView: BufferedSliderView, context: Context) {
        context.coordinator.parent = self
        uiView.slider.minimumValue = Float(range.lowerBound)
        uiView.slider.maximumValue = Float(range.upperBound)
        if !uiView.slider.isTracking {
            uiView.slider.value = Float(min(max(value, range.lowerBound), range.upperBound))
        }
        uiView.bufferedFraction = CGFloat(min(max(bufferedFraction, 0), 1))
    }

    final class Coordinator: NSObject {
        var parent: KSPlayerBufferedSlider

        init(parent: KSPlayerBufferedSlider) {
            self.parent = parent
        }

        @objc func editingBegan() {
            parent.onEditingChanged(true)
        }

        @objc func valueChanged(_ sender: UISlider) {
            parent.value = TimeInterval(sender.value)
        }

        @objc func editingEnded(_ sender: UISlider) {
            parent.value = TimeInterval(sender.value)
            parent.onEditingChanged(false)
        }
    }
}

private final class BufferedSliderView: UIView {
    let slider = UISlider()
    private let baseTrack = UIView()
    private let bufferedTrack = UIView()

    var bufferedFraction: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        baseTrack.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        bufferedTrack.backgroundColor = UIColor.white.withAlphaComponent(0.48)
        baseTrack.layer.cornerRadius = 1.5
        bufferedTrack.layer.cornerRadius = 1.5
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = .clear
        addSubview(baseTrack)
        addSubview(bufferedTrack)
        addSubview(slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 32)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        slider.frame = bounds
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let converted = slider.convert(trackRect, to: self)
        let trackFrame = CGRect(x: converted.minX, y: converted.midY - 1.5, width: converted.width, height: 3)
        baseTrack.frame = trackFrame
        bufferedTrack.frame = CGRect(
            x: trackFrame.minX,
            y: trackFrame.minY,
            width: trackFrame.width * bufferedFraction,
            height: trackFrame.height
        )
        sendSubviewToBack(baseTrack)
        insertSubview(bufferedTrack, aboveSubview: baseTrack)
    }
}
