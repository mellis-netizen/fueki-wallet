//
//  ReceiveCryptoView.swift
//  Fueki Wallet
//
//  Receive cryptocurrency with QR code generation
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveCryptoView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var selectedAsset: CryptoAsset?
    @State private var showAssetPicker = false
    @State private var amount = ""
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Asset Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Asset")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        Button(action: { showAssetPicker = true }) {
                            HStack {
                                if let asset = selectedAsset {
                                    Image(systemName: asset.icon)
                                        .foregroundColor(asset.color)
                                    Text(asset.symbol)
                                        .fontWeight(.semibold)
                                    Text("- \(asset.name)")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                } else {
                                    Text("Choose an asset")
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                        }
                        .foregroundColor(Color("TextPrimary"))
                    }
                    .padding(.horizontal, 16)

                    if let asset = selectedAsset {
                        // QR Code Section
                        VStack(spacing: 16) {
                            Text("Scan to receive \(asset.symbol)")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            // QR Code
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .frame(width: 280, height: 280)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                                if let qrImage = generateQRCode(from: asset.address) {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 240, height: 240)
                                }
                            }

                            // Amount (Optional)
                            VStack(spacing: 12) {
                                Text("Request Amount (Optional)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .padding(12)
                                    .background(Color("CardBackground"))
                                    .cornerRadius(12)
                                    .frame(width: 200)

                                if let amountDecimal = Decimal(string: amount), amountDecimal > 0 {
                                    Text("≈ $\((amountDecimal * asset.priceUSD).formatted())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 24)

                        // Address Section
                        VStack(spacing: 16) {
                            Text("Your \(asset.symbol) Address")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            // Address Display
                            HStack {
                                Text(asset.address)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(Color("TextPrimary"))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(16)
                                    .background(Color("CardBackground"))
                                    .cornerRadius(12)

                                Button(action: {
                                    UIPasteboard.general.string = asset.address
                                    // Show copied feedback
                                }) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.title3)
                                        .foregroundColor(Color("AccentPrimary"))
                                        .frame(width: 50, height: 50)
                                        .background(Color("CardBackground"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Action Buttons
                        HStack(spacing: 12) {
                            // Copy Address Button
                            Button(action: {
                                UIPasteboard.general.string = asset.address
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Address")
                                }
                                .font(.headline)
                                .foregroundColor(Color("AccentPrimary"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color("AccentPrimary").opacity(0.1))
                                .cornerRadius(16)
                            }

                            // Share Button
                            Button(action: {
                                shareAddress(asset: asset)
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color("AccentPrimary"))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Important Notice
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color("AccentPrimary"))

                                Text("Important")
                                    .font(.headline)
                                    .foregroundColor(Color("TextPrimary"))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                BulletPoint(text: "Only send \(asset.symbol) to this address")
                                BulletPoint(text: "Sending other cryptocurrencies may result in permanent loss")
                                BulletPoint(text: "Always verify the address before sharing")
                            }
                        }
                        .padding(16)
                        .background(Color("AccentPrimary").opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    } else {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("Select an Asset")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            Text("Choose which cryptocurrency you'd like to receive")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Receive")
            .sheet(isPresented: $showAssetPicker) {
                AssetPickerView(
                    assets: walletViewModel.assets,
                    selectedAsset: $selectedAsset
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func shareAddress(asset: CryptoAsset) {
        var items: [Any] = []

        // Add address text
        if !amount.isEmpty, let amountDecimal = Decimal(string: amount) {
            items.append("Send \(amountDecimal.formatted()) \(asset.symbol) to:\n\(asset.address)")
        } else {
            items.append("My \(asset.symbol) address:\n\(asset.address)")
        }

        // Add QR code image
        if let qrImage = generateQRCode(from: asset.address) {
            items.append(qrImage)
        }

        shareItems = items
        showShareSheet = true
    }
}

// MARK: - Bullet Point
struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
                .foregroundColor(Color("TextPrimary"))

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
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

#Preview {
    ReceiveCryptoView()
        .environmentObject(WalletViewModel())
}
