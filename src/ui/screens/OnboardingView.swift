//
//  OnboardingView.swift
//  Fueki Wallet
//
//  Onboarding flow with feature introduction
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Fueki",
            description: "Your secure gateway to the world of cryptocurrency. Buy, sell, send, and receive crypto with ease.",
            imageName: "wallet.fill",
            color: Color("AccentPrimary")
        ),
        OnboardingPage(
            title: "Bank-Grade Security",
            description: "Your assets are protected with military-grade encryption, biometric authentication, and secure key storage.",
            imageName: "lock.shield.fill",
            color: Color("SecondaryAccent")
        ),
        OnboardingPage(
            title: "Easy Crypto On-Ramp",
            description: "Buy crypto instantly with your credit card, debit card, or bank transfer. Sell and cash out just as easily.",
            imageName: "creditcard.and.123",
            color: Color("TertiaryAccent")
        ),
        OnboardingPage(
            title: "Send & Receive",
            description: "Transfer crypto to anyone, anywhere in the world. Simply scan a QR code or enter an address.",
            imageName: "qrcode.viewfinder",
            color: Color("AccentPrimary")
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color("AccentPrimary") : Color.gray.opacity(0.3))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.top, 40)

            // Onboarding Pages
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Action Buttons
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    // Get Started Button
                    Button(action: {
                        withAnimation {
                            authViewModel.completeOnboarding()
                            showOnboarding = false
                        }
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(16)
                    }
                    .transition(.scale)
                } else {
                    // Next Button
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(16)
                    }
                }

                // Skip Button
                if currentPage < pages.count - 1 {
                    Button(action: {
                        withAnimation {
                            authViewModel.completeOnboarding()
                            showOnboarding = false
                        }
                    }) {
                        Text("Skip")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color("BackgroundPrimary").ignoresSafeArea())
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: page.imageName)
                    .font(.system(size: 72))
                    .foregroundColor(page.color)
            }

            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .environmentObject(AuthenticationViewModel())
}
