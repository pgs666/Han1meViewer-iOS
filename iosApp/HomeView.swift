import SwiftUI
import Han1meShared

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    private let onOpenSearch: (HomeSectionRow) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// First-render measurement of the banner image's natural aspect ratio
    /// (width / height). Once captured, HomeBannerView passes it through
    /// to `aspectRatio(_:.fit)` so the banner's height tracks the actual
    /// image proportions instead of a hard-coded 3.2 / 16:9. Without this,
    /// images taller than the hard-coded ratio were getting cropped, and
    /// images shorter left empty bands — both manifested as visual
    /// "overlap" with adjacent rows.
    @State private var measuredBannerAspect: CGFloat?
    /// User-customised home-section ordering. Stored as a comma-separated
    /// list of section keys in NSUserDefaults under `home_section_order`.
    /// Edited by HomeSectionOrderView (设置 → 首页栏目排序). Empty = use
    /// the order the server returned. Sections present in the snapshot
    /// but absent from the saved order are appended at the end (so newly
    /// added server sections still surface).
    @AppStorage("home_section_order") private var homeSectionOrderRaw: String = ""

    init(environment: SharedAppEnvironment, onOpenSearch: @escaping (HomeSectionRow) -> Void = { _ in }) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        self.onOpenSearch = onOpenSearch
        _viewModel = StateObject(wrappedValue: HomeViewModel(homeFeature: environment.homeFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                .navigationTitle("首页")
                .task {
                    viewModel.loadIfNeeded()
                }
                .refreshable {
                    await viewModel.refresh()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            GeometryReader { proxy in
                ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("首页加载失败")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.load()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height * 0.65)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        case .loaded(let snapshot):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let banner = snapshot.banner {
                        HomeBannerView(
                            banner: banner,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature,
                            usesCompactBanner: horizontalSizeClass == .regular,
                            measuredAspect: measuredBannerAspect,
                            onAspectMeasured: { aspect in
                                guard aspect.isFinite, aspect > 0 else { return }
                                if measuredBannerAspect == nil {
                                    measuredBannerAspect = aspect
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, horizontalSizeClass == .regular ? 10 : 0)
                    }

                    ForEach(orderedSections(snapshot.sections)) { section in
                        HomeCategorySection(
                            section: section,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature,
                            onMore: onOpenSearch
                        )
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .onValueChange(of: horizontalSizeClass) { _ in
                // size class change can swap which banner shape is rendered
                // (compact 3.2 vs full 16:9 fallback); re-measure once
                // the new image actually loads.
                measuredBannerAspect = nil
            }
        }
    }

    /// Reorders the snapshot's home sections according to the user's
    /// saved preference. Sections in the saved order are emitted first;
    /// any snapshot sections not yet ordered (e.g. new server sections)
    /// keep their original relative order at the end. Saved keys that
    /// no longer correspond to any current snapshot section are
    /// silently ignored.
    private func orderedSections(_ sections: [HomeSectionRow]) -> [HomeSectionRow] {
        let preferred = homeSectionOrderRaw
            .split(separator: ",")
            .map(String.init)
        guard !preferred.isEmpty else { return sections }
        let bySectionKey = Dictionary(uniqueKeysWithValues: sections.map { ($0.key, $0) })
        var seen = Set<String>()
        var result: [HomeSectionRow] = []
        for key in preferred {
            if let section = bySectionKey[key], !seen.contains(key) {
                result.append(section)
                seen.insert(key)
            }
        }
        for section in sections where !seen.contains(section.key) {
            result.append(section)
        }
        return result
    }
}

private struct HomeBannerView: View {
    let banner: HomeBannerRow
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let usesCompactBanner: Bool
    /// Image's natural width / height. Once known, drives
    /// `aspectRatio(_:.fit)` so the rendered banner matches the actual
    /// proportions of the downloaded image — no cropping, no leftover
    /// empty band.
    let measuredAspect: CGFloat?
    /// Called once the underlying remote image successfully decodes,
    /// reporting (image.size.width / image.size.height).
    let onAspectMeasured: (CGFloat) -> Void

    var body: some View {
        Group {
            if let videoCode = banner.videoCode, !videoCode.isEmpty {
                NavigationLink {
                    VideoDetailView(videoCode: videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                } label: {
                    bannerContent
                }
                .buttonStyle(.plain)
            } else {
                bannerContent
            }
        }
        .frame(maxWidth: .infinity, alignment: usesCompactBanner ? .leading : .center)
    }

    private var bannerContent: some View {
        // Use the measured aspect ratio when we have it; fall back to the
        // hard-coded values so the placeholder still has a sensible shape
        // before the image lands.
        let aspect = measuredAspect ?? (usesCompactBanner ? 3.2 : 16.0 / 9.0)
        return bannerFrame
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: usesCompactBanner ? 440 : .infinity, alignment: usesCompactBanner ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: usesCompactBanner ? .leading : .center)
    }

    private var bannerFrame: some View {
        ZStack(alignment: .bottomLeading) {
            CachedRemoteImage(
                urlString: banner.imageUrl,
                resizeWidth: 900,
                onImageLoaded: { size in
                    guard size.width > 0, size.height > 0 else { return }
                    onAspectMeasured(size.width / size.height)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(banner.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let description = banner.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HomeCategorySection: View {
    let section: HomeSectionRow
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let onMore: (HomeSectionRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(section.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Spacer()

                Button("更多") {
                    onMore(section)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(section.videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                        } label: {
                            HomeVideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct HomeVideoCard: View {
    let video: HomeVideoRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 184)
                    .frame(width: 184, height: 104)
                    .clipped()

                LinearGradient(
                    colors: [
                        .clear,
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)

                HStack(spacing: 5) {
                    if let views = video.views, !views.isEmpty {
                        Label(views, systemImage: "play.circle")
                            .labelStyle(.titleAndIcon)
                    }

                    Spacer(minLength: 8)

                    if let duration = video.duration, !duration.isEmpty {
                        Label(duration, systemImage: "clock")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.bottom, 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(minHeight: 36, alignment: .topLeading)

            Text(video.artistLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !video.footerMetadata.isEmpty {
                Text(video.footerMetadata)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 184, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension HomeVideoRow {
    var artistLabel: String {
        guard let artist, !artist.isEmpty else {
            return String(localized: "common.artist")
        }
        return artist
    }
}
