import SwiftUI

struct CreateWalletView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel = CreateWalletViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView(message: "Creating your wallet...")
                } else {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)

                            Text("Create New Wallet")
                                .font(.title)
                                .fontWeight(.bold)

                            Text("Your wallet will be secured with a 12-word recovery phrase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)

                        Spacer()

                        // Security Notice
                        SecurityNoticeCard()

                        Spacer()

                        // Action Buttons
                        VStack(spacing: 16) {
                            CustomButton(
                                title: "Continue",
                                icon: "arrow.right.circle.fill",
                                style: .primary,
                                isLoading: viewModel.isLoading
                            ) {
                                createWallet()
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
            .navigationBarHidden(true)
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func createWallet() {
        Task {
            await viewModel.createWallet()
            if viewModel.mnemonic != nil {
                // Navigate to mnemonic display
                await MainActor.run {
                    // This will be handled by navigation
                }
            }
        }
    }
}

// MARK: - Security Notice Card
struct SecurityNoticeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("Important Security Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 12) {
                SecurityNoticeItem(
                    icon: "checkmark.circle.fill",
                    text: "Write down your recovery phrase"
                )
                SecurityNoticeItem(
                    icon: "checkmark.circle.fill",
                    text: "Store it in a safe place offline"
                )
                SecurityNoticeItem(
                    icon: "checkmark.circle.fill",
                    text: "Never share it with anyone"
                )
                SecurityNoticeItem(
                    icon: "xmark.circle.fill",
                    text: "Fueki cannot recover your wallet without it",
                    color: .red
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 24)
    }
}

struct SecurityNoticeItem: View {
    let icon: String
    let text: String
    var color: Color = .green

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - View Model
class CreateWalletViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var mnemonic: String?
    @Published var showError = false
    @Published var errorMessage: String?

    func createWallet() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let walletService = WalletService.shared
            let mnemonic = try await walletService.generateMnemonic()

            await MainActor.run {
                self.mnemonic = mnemonic
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Preview
struct CreateWalletView_Previews: PreviewProvider {
    static var previews: some View {
        CreateWalletView()
            .environmentObject(AppCoordinator())
    }
}
