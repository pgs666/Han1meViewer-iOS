import SwiftUI
import Nuke
import NukeUI

struct CachedRemoteImage: View {
    let urlString: String?
    let contentMode: ContentMode
    let resizeWidth: CGFloat?
    /// Optional: invoked once the remote image successfully loads, with the
    /// decoded image's natural pixel size. Useful for callers that want to
    /// size their container based on the actual image aspect (e.g. the
    /// home banner) rather than a hard-coded ratio.
    let onImageLoaded: ((CGSize) -> Void)?

    init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        resizeWidth: CGFloat? = nil,
        onImageLoaded: ((CGSize) -> Void)? = nil
    ) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.resizeWidth = resizeWidth
        self.onImageLoaded = onImageLoaded
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
            }
        }
        .onCompletion { result in
            if case .success(let response) = result {
                onImageLoaded?(response.image.size)
            }
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
