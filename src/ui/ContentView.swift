//
//  ContentView.swift
//  Fueki Wallet
//
//  Main content view with authentication flow
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var appState: AppState
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView(message: "Initializing Wallet...")
            } else if authViewModel.isAuthenticated {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                if showOnboarding || !authViewModel.hasSeenOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletDashboardView()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard.fill")
                }
                .tag(0)

            TransactionHistoryView()
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(1)

            SendCryptoView()
                .tabItem {
                    Label("Send", systemImage: "arrow.up.circle.fill")
                }
                .tag(2)

            ReceiveCryptoView()
                .tabItem {
                    Label("Receive", systemImage: "arrow.down.circle.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(Color("AccentPrimary"))
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color("AccentPrimary").opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        Color("AccentPrimary"),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationViewModel())
        .environmentObject(AppState())
        .environmentObject(WalletViewModel())
}
