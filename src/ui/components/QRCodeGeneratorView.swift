//
//  QRCodeGeneratorView.swift
//  Fueki Wallet
//
//  QR code generator for receive addresses
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeGeneratorView: View {
    let address: String
    let assetName: String
    @State private var showCopied = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Receive \(assetName)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("TextPrimary"))

            // QR Code
            VStack(spacing: 16) {
                if let qrImage = generateQRCode(from: address) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10)
                        .accessibilityLabel("QR code for receiving \(assetName)")
                        .accessibilityHint("Share this code for others to send you \(assetName)")
                } else {
                    // Fallback if QR generation fails
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("CardBackground"))
                            .frame(width: 250, height: 250)

                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("Unable to generate QR code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text("Scan this code to receive \(assetName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Address
            VStack(spacing: 12) {
                Text("Your \(assetName) Address")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Text(address)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color("TextPrimary"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding()
                        .background(Color("CardBackground"))
                        .cornerRadius(12)

                    Button(action: copyAddress) {
                        Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.title3)
                            .foregroundColor(showCopied ? .green : Color("AccentPrimary"))
                            .frame(width: 44, height: 44)
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                    }
                    .accessibleButton(
                        label: "Copy address",
                        hint: showCopied ? "Address copied" : "Double tap to copy address"
                    )
                }
            }
            .padding(.horizontal)

            // Share Button
            Button(action: { showShareSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Address")
                }
                .font(.headline)
                .foregroundColor(Color("AccentPrimary"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color("AccentPrimary").opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .accessibleButton(
                label: "Share address",
                hint: "Double tap to share your address"
            )

            // Warning
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color("AccentPrimary"))

                Text("Only send \(assetName) to this address. Other assets may be lost permanently.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color("AccentPrimary").opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [address])
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func copyAddress() {
        UIPasteboard.general.string = address
        showCopied = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Accessibility announcement
        AccessibilityAnnouncement.announce("Address copied to clipboard")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    QRCodeGeneratorView(
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        assetName: "Bitcoin"
    )
    .background(Color("BackgroundPrimary"))
}
