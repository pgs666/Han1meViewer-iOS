import SwiftUI
import Han1meShared

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    private let onOpenSearch: (HomeSectionRow) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                VStack(alignment: .leading, spacing: 18) {
                    if let banner = snapshot.banner {
                        HomeBannerView(
                            banner: banner,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature,
                            usesCompactBanner: horizontalSizeClass == .regular
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, horizontalSizeClass == .regular ? 10 : 0)
                    }

                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(snapshot.sections) { section in
                            HomeCategorySection(
                                section: section,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature,
                                onMore: onOpenSearch
                            )
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct HomeBannerView: View {
    let banner: HomeBannerRow
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let usesCompactBanner: Bool

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
        bannerFrame
            .aspectRatio(usesCompactBanner ? 3.2 : 16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: usesCompactBanner ? 440 : .infinity, alignment: usesCompactBanner ? .leading : .center)
    }

    private var bannerFrame: some View {
        ZStack(alignment: .bottomLeading) {
            CachedRemoteImage(urlString: banner.imageUrl, resizeWidth: 600)
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
    @State private var isVisible = false

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
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
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
            .compositingGroup()
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
