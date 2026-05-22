import SwiftUI

struct SearchView: View {
    @State private var keyword = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索影片、标签或作者", text: $keyword)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiquidGlassSearchButtonStyle())
                .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                List {
                    Section("搜索") {
                        Text("搜索仓库接入后，这里会显示关键词结果和历史记录。")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("搜索")
        }
        .navigationViewStyle(.stack)
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
