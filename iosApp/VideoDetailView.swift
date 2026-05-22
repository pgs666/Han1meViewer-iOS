import SwiftUI

struct VideoDetailView: View {
    let videoCode: String
    @StateObject private var viewModel = VideoDetailViewModel()

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
                    if let description = snapshot.description, !description.isEmpty {
                        Text(description)
                    }
                }
            }
        }
    }
}
