import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var currentPage = 0
    @State private var showCreateWallet = false
    @State private var showImportWallet = false

    let features = [
        Feature(
            icon: "lock.shield.fill",
            title: "Secure & Private",
            description: "Your keys, your crypto. Non-custodial wallet with military-grade encryption.",
            color: .blue
        ),
        Feature(
            icon: "bolt.fill",
            title: "Fast Transactions",
            description: "Send and receive crypto instantly with low fees on multiple networks.",
            color: .orange
        ),
        Feature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Portfolio",
            description: "Monitor your assets in real-time with detailed analytics and price alerts.",
            color: .green
        ),
        Feature(
            icon: "faceid",
            title: "Biometric Security",
            description: "Protect your wallet with Face ID, Touch ID, or secure PIN.",
            color: .purple
        )
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 60)

                    Text("Fueki Wallet")
                        .font(.system(size: 36, weight: .bold))

                    Text("Your Gateway to Digital Assets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)

                // Feature Carousel
                TabView(selection: $currentPage) {
                    ForEach(features.indices, id: \.self) { index in
                        FeatureCard(feature: features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 320)

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    CustomButton(
                        title: "Create New Wallet",
                        icon: "plus.circle.fill",
                        style: .primary
                    ) {
                        showCreateWallet = true
                    }

                    CustomButton(
                        title: "Import Existing Wallet",
                        icon: "arrow.down.circle.fill",
                        style: .secondary
                    ) {
                        showImportWallet = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletView()
        }
        .sheet(isPresented: $showImportWallet) {
            ImportWalletView()
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let feature: Feature

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: feature.icon)
                .font(.system(size: 60))
                .foregroundColor(feature.color)

            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Feature Model
struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(AppCoordinator())
    }
}
