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
        .navigationTitle("Detail")
        .task {
            viewModel.load(videoCode: videoCode)
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
                Text("Unable to load video")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        case .loaded(let snapshot):
            List {
                Section("Video") {
                    Text(snapshot.title)
                    if let chineseTitle = snapshot.chineseTitle, !chineseTitle.isEmpty {
                        Text(chineseTitle)
                            .foregroundStyle(.secondary)
                    }
                    Text(snapshot.videoCode)
                        .foregroundStyle(.secondary)
                }

                Section("Playback") {
                    Text("Sources: \(snapshot.sourceCount)")
                    if let label = snapshot.defaultSourceLabel {
                        Text("Default: \(label)")
                    }
                    if let sourceUrl = snapshot.defaultSourceUrl {
                        Text(sourceUrl)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        NavigationLink("Play") {
                            PlayerView(sourceUrl: sourceUrl, title: snapshot.title)
                        }
                    } else {
                        Text("No playable source parsed")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Info") {
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
                    Section("相关影片") {
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
