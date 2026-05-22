import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

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
                    Text(viewModel.smokeFetchSummary)
                    Text(snapshot.summary)
                    Text(snapshot.baseUrl)
                }

                if let bannerTitle = snapshot.bannerTitle {
                    Section("Banner") {
                        Text(bannerTitle)
                    }
                }

                if let firstVideoTitle = snapshot.firstVideoTitle {
                    Section("First video") {
                        if let videoCode = snapshot.firstVideoCode {
                            NavigationLink {
                                VideoDetailView(videoCode: videoCode)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(firstVideoTitle)
                                    Text(videoCode)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text(firstVideoTitle)
                        }
                    }
                }
            }
        }
    }
}
