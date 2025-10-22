//
//  AssetPickerView.swift
//  Fueki Wallet
//
//  Asset selection picker
//

import SwiftUI

struct AssetPickerView: View {
    let assets: [CryptoAsset]
    @Binding var selectedAsset: CryptoAsset?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var filteredAssets: [CryptoAsset] {
        if searchText.isEmpty {
            return assets
        }
        return assets.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredAssets) { asset in
                    Button(action: {
                        selectedAsset = asset
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            // Asset Icon
                            ZStack {
                                Circle()
                                    .fill(asset.color.opacity(0.1))
                                    .frame(width: 44, height: 44)

                                Image(systemName: asset.icon)
                                    .font(.title3)
                                    .foregroundColor(asset.color)
                            }

                            // Asset Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.name)
                                    .font(.headline)
                                    .foregroundColor(Color("TextPrimary"))

                                Text(asset.symbol)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Balance
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(asset.balance.formatted()) \(asset.symbol)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("TextPrimary"))

                                Text("$\(asset.balanceUSD.formatted())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Checkmark
                            if selectedAsset?.id == asset.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color("BackgroundPrimary"))
                }
            }
            .listStyle(.plain)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Select Asset")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search assets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AssetPickerView(
        assets: [],
        selectedAsset: .constant(nil)
    )
}
