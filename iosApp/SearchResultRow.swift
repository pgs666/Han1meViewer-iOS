import SwiftUI

struct SearchResultRow: View {
    let video: SearchVideoRow
    var coverLayout: VideoCoverLayout = .landscape

    var body: some View {
        HStack(spacing: 12) {
            VideoCardCover(
                urlString: video.coverUrl,
                resizeWidth: 96,
                layout: coverLayout,
                cornerRadius: 6
            )
            .frame(width: 96)

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
        .videoCardSurface()
    }
}
