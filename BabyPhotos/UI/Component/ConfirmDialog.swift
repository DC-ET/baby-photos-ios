import SwiftUI

struct ConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = "确认"
    var dismissLabel: String = "取消"
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button(dismissLabel) { onDismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button(confirmLabel) { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}
