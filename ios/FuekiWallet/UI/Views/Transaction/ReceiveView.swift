import SwiftUI

struct ReceiveView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ReceiveViewModel()
    @State private var copied = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Asset Selector
                        AssetSelectorView(selectedAsset: $viewModel.selectedAsset)
                            .padding(.horizontal, 24)

                        // QR Code
                        VStack(spacing: 16) {
                            QRCodeView(content: viewModel.address, size: 250)

                            Text(viewModel.selectedAsset?.name ?? "Asset")
                                .font(.headline)

                            Text(viewModel.selectedAsset?.symbol ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Address Display
                        VStack(spacing: 12) {
                            Text("Your Address")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(viewModel.formattedAddress)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Button(action: { copyAddress() }) {
                                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                        .foregroundColor(copied ? .green : .blue)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .padding(.horizontal, 24)
                        }

                        // Warning
                        WarningCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Important",
                            message: "Only send \(viewModel.selectedAsset?.symbol ?? "") to this address. Sending other assets may result in permanent loss.",
                            color: .orange
                        )
                        .padding(.horizontal, 24)

                        // Share Button
                        CustomButton(
                            title: "Share Address",
                            icon: "square.and.arrow.up",
                            style: .secondary
                        ) {
                            shareAddress()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = viewModel.address
        withAnimation {
            copied = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }

    private func shareAddress() {
        let activityVC = UIActivityViewController(
            activityItems: [viewModel.address],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Warning Card
struct WarningCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - View Model
class ReceiveViewModel: ObservableObject {
    @Published var selectedAsset: Asset? = Asset.mockAssets().first
    @Published var address = "0x1234567890abcdef1234567890abcdef12345678"

    var formattedAddress: String {
        let prefix = String(address.prefix(10))
        let suffix = String(address.suffix(8))
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Preview
struct ReceiveView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiveView()
    }
}
