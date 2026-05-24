import SwiftUI
import NukeUI

struct CachedRemoteImage: View {
    let urlString: String?
    let contentMode: ContentMode

    init(urlString: String?, contentMode: ContentMode = .fill) {
        self.urlString = urlString
        self.contentMode = contentMode
    }

    var body: some View {
        LazyImage(url: urlString.flatMap(URL.init(string:))) { state in
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
    }
}
