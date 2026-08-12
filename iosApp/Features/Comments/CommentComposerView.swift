import SwiftUI

struct CommentComposerView: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let submitTitle: LocalizedStringKey
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        CompatibleNavigationStack {
            VStack {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, action: onSubmit)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
    }
}
