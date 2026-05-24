import SwiftUI
import Han1meShared

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let environment: SharedAppEnvironment

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: HomeViewModel(homeFeature: environment.homeFeature()))
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Home")
                .task {
                    viewModel.loadIfNeeded()
                }
                .refreshable {
                    viewModel.load()
                }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Unable to load home")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        case .loaded(let snapshot):
            List {
                if let banner = snapshot.banner {
                    Section("Featured") {
                        if let videoCode = banner.videoCode, !videoCode.isEmpty {
                            NavigationLink {
                                VideoDetailView(videoCode: videoCode, videoFeature: environment.videoFeature())
                            } label: {
                                HomeBannerView(banner: banner)
                            }
                        } else {
                            HomeBannerView(banner: banner)
                        }
                    }
                }

                ForEach(snapshot.sections) { section in
                    Section(section.title) {
                        ForEach(section.videos) { video in
                            NavigationLink {
                                VideoDetailView(videoCode: video.videoCode, videoFeature: environment.videoFeature())
                            } label: {
                                HomeVideoListRow(video: video)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HomeBannerView: View {
    let banner: HomeBannerRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CachedRemoteImage(urlString: banner.imageUrl)
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.headline)
                    .lineLimit(2)

                if let description = banner.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HomeVideoListRow: View {
    let video: HomeVideoRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl)
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
