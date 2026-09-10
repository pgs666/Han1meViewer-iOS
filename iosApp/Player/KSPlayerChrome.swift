import SwiftUI

struct KSPlayerLoadingHUD: View {
    let phase: KSPlayerPresentationPhase
    let speedText: String?

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
            Text(label)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }

    private var label: String {
        let loading: String
        switch phase {
        case .preparing:
            loading = String(localized: "正在准备播放…")
        case .buffering:
            loading = String(localized: "正在缓冲…")
        case .ready, .failed:
            loading = String(localized: "加载中")
        }
        guard let speedText else { return loading }
        return "\(loading) · \(speedText)"
    }
}

struct KSPlayerErrorHUD: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("播放失败")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.center)
            Button("重试", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 260)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct KSPlayerQualityNotice: View {
    let quality: String

    var body: some View {
        Text(String(format: String(localized: "网络不稳定，已切换至%@"), quality))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.65), in: Capsule())
            .allowsHitTesting(false)
    }
}

struct KSPlayerValueHUD: View {
    let systemImage: String
    let label: String
    let value: Float

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label)
                Spacer(minLength: 0)
                Text("\(Int((value * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .frame(width: 160)

            ProgressView(value: Double(value), total: 1.0)
                .progressViewStyle(.linear)
                .tint(.white)
                .frame(width: 160)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct KSPlayerSeekHUD: View {
    let delta: TimeInterval
    let target: TimeInterval
    let total: TimeInterval

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: delta >= 0 ? "forward.fill" : "backward.fill")
                    .font(.title3)
                Text("\(delta >= 0 ? "+" : "−")\(KSPlayerDisplayFormatter.time(abs(delta)))")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            Text("\(KSPlayerDisplayFormatter.time(target)) / \(KSPlayerDisplayFormatter.time(total))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct KSPlayerBoostHint: View {
    let rate: Float

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Label(KSPlayerDisplayFormatter.rate(rate), systemImage: "forward.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.top, 12)
            Spacer()
        }
    }
}

struct KSPlayerIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
    }
}

struct KSPlayerEmptyPlaceholder: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 10) {
                Image(systemName: "play.slash")
                    .font(.title)
                    .foregroundStyle(.white)
                Text("未解析到可播放源")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
