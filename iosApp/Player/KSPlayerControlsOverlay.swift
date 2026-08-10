import Han1meShared
import KSPlayer
import SwiftUI

struct KSPlayerControlsOverlay: View {
    let title: String
    let playbackSources: [VideoPlaybackSourceRow]
    let activeSource: VideoPlaybackSourceRow?
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    @Binding var isFullscreen: Bool
    let isPlaying: Bool
    @Binding var sliderValue: TimeInterval
    @Binding var isSliderEditing: Bool
    @Binding var selectedSourceID: String?
    @Binding var savedPlaybackRate: Float
    let onBack: () -> Void
    let onTogglePlayPause: () -> Void
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
                Spacer()
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

            Slider(
                value: $sliderValue,
                in: 0...total,
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
            .tint(.white)
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
                    selectedSourceID = source.id
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
