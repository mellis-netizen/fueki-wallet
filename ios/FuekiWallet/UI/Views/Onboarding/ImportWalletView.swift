import SwiftUI

struct ImportWalletView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel = ImportWalletViewModel()
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView(message: "Importing your wallet...")
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue)

                                Text("Import Wallet")
                                    .font(.title)
                                    .fontWeight(.bold)

                                Text("Enter your 12 or 24-word recovery phrase")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.top, 20)

                            // Word Count Selector
                            Picker("Word Count", selection: $viewModel.wordCount) {
                                Text("12 words").tag(12)
                                Text("24 words").tag(24)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 24)

                            // Mnemonic Input Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(0..<viewModel.wordCount, id: \.self) { index in
                                    MnemonicWordField(
                                        index: index,
                                        word: $viewModel.words[index],
                                        isFocused: focusedField == index
                                    )
                                    .focused($focusedField, equals: index)
                                }
                            }
                            .padding(.horizontal, 24)

                            // Paste Button
                            CustomButton(
                                title: "Paste from Clipboard",
                                icon: "doc.on.clipboard",
                                style: .secondary
                            ) {
                                pasteFromClipboard()
                            }
                            .padding(.horizontal, 24)

                            // Action Buttons
                            VStack(spacing: 16) {
                                CustomButton(
                                    title: "Import Wallet",
                                    icon: "arrow.down.circle.fill",
                                    style: .primary,
                                    isLoading: viewModel.isLoading,
                                    isDisabled: !viewModel.isValid
                                ) {
                                    importWallet()
                                }

                                CustomButton(
                                    title: "Cancel",
                                    style: .tertiary
                                ) {
                                    dismiss()
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Import Failed"),
                    message: Text(viewModel.errorMessage ?? "Invalid recovery phrase"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func pasteFromClipboard() {
        if let clipboard = UIPasteboard.general.string {
            viewModel.parseAndSetWords(clipboard)
        }
    }

    private func importWallet() {
        Task {
            let success = await viewModel.importWallet()
            if success {
                await MainActor.run {
                    appCoordinator.completeOnboarding()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Mnemonic Word Field
struct MnemonicWordField: View {
    let index: Int
    @Binding var word: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            TextField("word", text: $word)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - View Model
class ImportWalletViewModel: ObservableObject {
    @Published var wordCount = 12 {
        didSet {
            words = Array(repeating: "", count: wordCount)
        }
    }
    @Published var words: [String] = Array(repeating: "", count: 12)
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    var isValid: Bool {
        words.allSatisfy { !$0.isEmpty && $0.count > 2 }
    }

    func parseAndSetWords(_ text: String) {
        let parsedWords = text
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if parsedWords.count == 12 || parsedWords.count == 24 {
            wordCount = parsedWords.count
            words = parsedWords
        }
    }

    func importWallet() async -> Bool {
        await MainActor.run {
            isLoading = true
        }

        do {
            let mnemonic = words.joined(separator: " ")
            let walletService = WalletService.shared
            try await walletService.importWallet(mnemonic: mnemonic)

            await MainActor.run {
                isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
            return false
        }
    }
}

// MARK: - Preview
struct ImportWalletView_Previews: PreviewProvider {
    static var previews: some View {
        ImportWalletView()
            .environmentObject(AppCoordinator())
    }
}
