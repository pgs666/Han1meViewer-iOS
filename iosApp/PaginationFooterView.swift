import SwiftUI

struct PaginationFooterView: View {
    let isLoadingMore: Bool
    let hasNext: Bool
    let loadMoreError: String?
    let isEmpty: Bool
    let onRetry: () -> Void

    var body: some View {
        if isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 10)
        } else if let message = loadMoreError {
            VStack(alignment: .leading, spacing: 8) {
                Text("加载更多失败")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        } else if hasNext {
            HStack {
                Spacer()
                ProgressView()
                    .onAppear {
                        onRetry()
                    }
                Spacer()
            }
            .padding(.vertical, 10)
        } else if !isEmpty {
            Text("已全部加载")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }
}
