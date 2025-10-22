//
//  LoadingView.swift
//  Fueki Wallet
//
//  Reusable loading state views
//

import SwiftUI

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false

    init(message: String = "Loading...") {
        self.message = message
    }

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
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundPrimary"))
        .onAppear {
            isAnimating = true
            AccessibilityAnnouncement.announce(message)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Skeleton Loading View

struct SkeletonLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            // Asset Cards
            ForEach(0..<3) { _ in
                SkeletonCard()
            }
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

struct SkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // Title placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 16)

                    // Subtitle placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 12)
                }

                Spacer()

                // Value placeholder
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 16)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 12)
                }
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(shimmer ? 360 : 0))
                .offset(x: shimmer ? 300 : -300)
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: shimmer
                )
        )
        .onAppear {
            shimmer = true
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Pull to Refresh Loading

struct PullToRefreshView: View {
    @Binding var isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())

                Text("Refreshing...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Inline Loading

struct InlineLoadingView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Button Loading State

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }

                Text(isLoading ? "Loading..." : title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isLoading ? Color.gray : Color("AccentPrimary")
            )
            .cornerRadius(16)
        }
        .disabled(isLoading)
        .accessibleButton(
            label: title,
            hint: isLoading ? "Please wait" : "Double tap to activate"
        )
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isAnimating ? 300 : -300)
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Previews

#Preview("Loading View") {
    LoadingView(message: "Loading your wallet...")
}

#Preview("Skeleton Loading") {
    SkeletonLoadingView()
        .background(Color("BackgroundPrimary"))
}

#Preview("Loading Button") {
    VStack(spacing: 16) {
        LoadingButton(title: "Send", isLoading: false) { }
        LoadingButton(title: "Send", isLoading: true) { }
    }
    .padding()
}
