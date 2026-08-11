import SwiftUI
import Nuke
import NukeUI

struct CachedRemoteImage: View {
    let urlString: String?
    let contentMode: ContentMode
    let resizeWidth: CGFloat?

    @State private var retryAttempt = 0

    private static let retryDelays: [UInt64] = [
        500_000_000,
        1_500_000_000,
        3_000_000_000,
    ]

    init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        resizeWidth: CGFloat? = nil
    ) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.resizeWidth = resizeWidth
    }

    var body: some View {
        LazyImage(request: imageRequest) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.18))
                    .overlay {
                        if state.error != nil {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task(id: retryAttempt) {
                        guard state.error != nil,
                              retryAttempt < Self.retryDelays.count else {
                            return
                        }

                        try? await Task.sleep(
                            nanoseconds: Self.retryDelays[retryAttempt]
                        )
                        guard !Task.isCancelled else { return }
                        retryAttempt += 1
                    }
            }
        }
        .id(retryAttempt)
        .onChange(of: urlString) { _ in
            retryAttempt = 0
        }
    }

    private var imageRequest: ImageRequest? {
        guard let url = urlString.flatMap(URL.init(string:)) else {
            return nil
        }
        guard let resizeWidth else {
            return ImageRequest(url: url)
        }
        return ImageRequest(url: url, processors: [.resize(width: resizeWidth)])
    }
}
