import SwiftUI
import Han1meShared

struct SearchView: View {
    @State private var keyword = ""
    @StateObject private var viewModel: SearchViewModel
    private let environment: SharedAppEnvironment

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: environment.searchFeature()))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                searchControls
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("搜索")
        }
        .navigationViewStyle(.stack)
    }

    private var searchControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索影片、标签或作者", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.search(keyword: keyword)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                viewModel.search(keyword: keyword)
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .searchProminentGlassButton()
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            List {
                Section("搜索") {
                    Text("输入关键词开始搜索。")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
        case .loading:
            Spacer()
            ProgressView()
            Spacer()
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("搜索失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            List {
                Section("结果") {
                    if snapshot.results.isEmpty {
                        Text("没有找到结果。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.results) { video in
                            NavigationLink {
                                VideoDetailView(
                                    videoCode: video.videoCode,
                                    videoFeature: environment.videoFeature()
                                )
                            } label: {
                                SearchResultRow(video: video)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct SearchResultRow: View {
    let video: SearchVideoRow

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

private extension View {
    @ViewBuilder
    func searchProminentGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            self.buttonStyle(LiquidGlassSearchButtonStyle())
        }
    }
}

private struct LiquidGlassSearchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .foregroundStyle(.primary)
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(configuration.isPressed ? 0.10 : 0.28),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
