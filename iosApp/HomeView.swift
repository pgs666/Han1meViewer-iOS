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
                    viewModel.load()
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
                Section("Status") {
                    Text(snapshot.summary)
                    Text(snapshot.baseUrl)
                }

                if let bannerTitle = snapshot.bannerTitle {
                    Section("Banner") {
                        Text(bannerTitle)
                    }
                }

                Section("Videos") {
                    ForEach(snapshot.videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: environment.videoFeature())
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: video.coverUrl.flatMap(URL.init(string:))) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.18)
                                }
                                .frame(width: 96, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.title)
                                        .lineLimit(2)
                                    Text(video.sectionTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}
