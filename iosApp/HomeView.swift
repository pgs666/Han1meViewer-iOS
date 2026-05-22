import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Home")
                .task {
                    viewModel.load()
                }
                .refreshable {
                    viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView("Unable to load home", systemImage: "wifi.exclamationmark", description: Text(message))
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

                if let firstVideoTitle = snapshot.firstVideoTitle {
                    Section("First video") {
                        Text(firstVideoTitle)
                        if let videoCode = snapshot.firstVideoCode {
                            Text(videoCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
