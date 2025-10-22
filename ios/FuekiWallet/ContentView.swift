import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            if appState.isAuthenticated {
                WalletHomeView()
            } else {
                AuthenticationView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Fueki Wallet")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Secure. Simple. Powerful.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                // Authenticate with biometrics
            }) {
                HStack {
                    Image(systemName: "faceid")
                    Text("Authenticate")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Wallet Home View
struct WalletHomeView: View {
    var body: some View {
        List {
            Section("Your Wallets") {
                Text("No wallets yet")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Wallets")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Add new wallet
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
