import SwiftUI
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    @StateObject private var viewModel: VideoDetailViewModel

    init(videoCode: String, videoFeature: VideoFeature) {
        self.videoCode = videoCode
        self.videoFeature = videoFeature
        _viewModel = StateObject(wrappedValue: VideoDetailViewModel(videoFeature: videoFeature))
    }

    var body: some View {
        content
        .navigationTitle("\u{8BE6}\u{60C5}")
        .task {
            viewModel.loadIfNeeded(videoCode: videoCode)
        }
        .refreshable {
            viewModel.load(videoCode: videoCode)
        }
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
                Text("\u{89C6}\u{9891}\u{52A0}\u{8F7D}\u{5931}\u{8D25}")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        case .loaded(let snapshot):
            List {
                Section("\u{5F71}\u{7247}") {
                    Text(snapshot.title)
                    if let chineseTitle = snapshot.chineseTitle, !chineseTitle.isEmpty {
                        Text(chineseTitle)
                            .foregroundStyle(.secondary)
                    }
                    Text(snapshot.videoCode)
                        .foregroundStyle(.secondary)
                }

                Section("\u{64AD}\u{653E}") {
                    Text("\u{64AD}\u{653E}\u{6E90}\u{FF1A}\(snapshot.sourceCount)")
                    if let label = snapshot.defaultSourceLabel {
                        Text("\u{9ED8}\u{8BA4}\u{FF1A}\(label)")
                    }
                    if !snapshot.playbackSources.isEmpty {
                        NavigationLink("\u{64AD}\u{653E}") {
                            PlayerView(
                                title: snapshot.title,
                                sources: snapshot.playbackSources
                            )
                        }
                    } else {
                        Text("\u{672A}\u{89E3}\u{6790}\u{5230}\u{53EF}\u{64AD}\u{653E}\u{6E90}")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("\u{4FE1}\u{606F}") {
                    if let views = snapshot.views {
                        Text(views)
                    }
                    if let uploadDate = snapshot.uploadDate {
                        Text(uploadDate)
                    }
                    if !snapshot.tagSummary.isEmpty {
                        Text(snapshot.tagSummary)
                    }
                    if let videoDescription = snapshot.videoDescription, !videoDescription.isEmpty {
                        Text(videoDescription)
                    }
                }

                if !snapshot.relatedVideos.isEmpty {
                    Section("\u{76F8}\u{5173}\u{5F71}\u{7247}") {
                        ForEach(snapshot.relatedVideos) { video in
                            NavigationLink {
                                VideoDetailView(
                                    videoCode: video.videoCode,
                                    videoFeature: videoFeature
                                )
                            } label: {
                                VideoRelatedRowView(video: video)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct VideoRelatedRowView: View {
    let video: VideoRelatedRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .lineLimit(2)
                if !video.metadata.isEmpty {
                    Text(video.metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
