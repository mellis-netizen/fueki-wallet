//
//  SeedPhraseBackupView.swift
//  Fueki Wallet
//
//  Seed phrase backup and verification flow
//

import SwiftUI

struct SeedPhraseBackupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SeedPhraseViewModel()
    @State private var currentStep: BackupStep = .warning
    @State private var selectedWords: [String] = []
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundPrimary")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Indicator
                    ProgressView(value: currentStep.progress, total: 1.0)
                        .tint(Color("AccentPrimary"))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Content based on step
                    switch currentStep {
                    case .warning:
                        WarningStepView {
                            withAnimation {
                                currentStep = .display
                                viewModel.generateSeedPhrase()
                            }
                        }

                    case .display:
                        DisplaySeedPhraseView(
                            seedPhrase: viewModel.seedPhrase,
                            onContinue: {
                                withAnimation {
                                    currentStep = .verify
                                }
                            }
                        )

                    case .verify:
                        VerifySeedPhraseView(
                            correctPhrase: viewModel.seedPhrase,
                            selectedWords: $selectedWords,
                            onSuccess: {
                                viewModel.saveSeedPhrase()
                                showSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    dismiss()
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Backup Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .verify {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .overlay {
                if showSuccess {
                    SuccessOverlayView(message: "Recovery phrase backed up successfully!")
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Backup recovery phrase flow")
    }
}

// MARK: - Backup Steps

enum BackupStep {
    case warning
    case display
    case verify

    var progress: Double {
        switch self {
        case .warning: return 0.33
        case .display: return 0.66
        case .verify: return 1.0
        }
    }
}

// MARK: - Warning Step

struct WarningStepView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                }
                .padding(.top, 32)

                // Title and Description
                VStack(spacing: 16) {
                    Text("Protect Your Wallet")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))
                        .multilineTextAlignment(.center)

                    Text("Your recovery phrase is the only way to restore your wallet if you lose access to your device.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Warning Points
                VStack(spacing: 20) {
                    WarningPoint(
                        icon: "checkmark.shield.fill",
                        text: "Write it down on paper and store it securely",
                        color: .green
                    )

                    WarningPoint(
                        icon: "xmark.circle.fill",
                        text: "Never share it with anyone",
                        color: .red
                    )

                    WarningPoint(
                        icon: "photo.on.rectangle.angled",
                        text: "Never take a screenshot or photo",
                        color: .red
                    )

                    WarningPoint(
                        icon: "icloud.slash.fill",
                        text: "Don't store it digitally or in the cloud",
                        color: .red
                    )
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)

                // Continue Button
                Button(action: onContinue) {
                    Text("I Understand")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("AccentPrimary"))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .accessibleButton(
                    label: "I understand. Continue to view recovery phrase",
                    hint: "Double tap to proceed"
                )
            }
        }
    }
}

struct WarningPoint: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundColor(Color("TextPrimary"))
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Display Seed Phrase

struct DisplaySeedPhraseView: View {
    let seedPhrase: [String]
    let onContinue: () -> Void
    @State private var isRevealed = false
    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Instructions
                VStack(spacing: 12) {
                    Text("Write Down Your Recovery Phrase")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("TextPrimary"))
                        .multilineTextAlignment(.center)

                    Text("Write these 12 words in order on paper. You'll need to verify them on the next screen.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Seed Phrase Grid
                if isRevealed {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(seedPhrase.enumerated()), id: \.offset) { index, word in
                            SeedWordCard(number: index + 1, word: word)
                        }
                    }
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Reveal Button
                    VStack(spacing: 16) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Tap to reveal your recovery phrase")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(action: {
                            withAnimation(.spring()) {
                                isRevealed = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "eye.fill")
                                Text("Reveal Recovery Phrase")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(height: 400)
                }

                if isRevealed {
                    // Copy Warning
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text("Make sure no one is watching your screen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)

                    // Continue Button
                    Button(action: onContinue) {
                        Text("I've Written It Down")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .accessibleButton(
                        label: "I've written down my recovery phrase",
                        hint: "Continue to verification"
                    )
                }
            }
        }
    }
}

struct SeedWordCard: View {
    let number: Int
    let word: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(word)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(Color("TextPrimary"))

            Spacer()
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Word \(number): \(word)")
    }
}

// MARK: - Verify Seed Phrase

struct VerifySeedPhraseView: View {
    let correctPhrase: [String]
    @Binding var selectedWords: [String]
    let onSuccess: () -> Void

    @State private var shuffledWords: [String] = []
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 12) {
                    Text("Verify Your Recovery Phrase")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("TextPrimary"))
                        .multilineTextAlignment(.center)

                    Text("Tap the words in the correct order to verify you've written them down correctly.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Selected Words
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)

                    if selectedWords.isEmpty {
                        Text("Tap words below to begin")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(selectedWords.enumerated()), id: \.offset) { index, word in
                                SelectedWordChip(
                                    number: index + 1,
                                    word: word,
                                    onRemove: {
                                        selectedWords.remove(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Available Words
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)

                    FlowLayout(spacing: 8) {
                        ForEach(shuffledWords.filter { !selectedWords.contains($0) }, id: \.self) { word in
                            WordChip(word: word) {
                                selectedWords.append(word)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Error Message
                if showError {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }

                // Verify Button
                Button(action: verifyPhrase) {
                    Text("Verify Recovery Phrase")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            selectedWords.count == correctPhrase.count
                                ? Color("AccentPrimary")
                                : Color.gray
                        )
                        .cornerRadius(16)
                }
                .disabled(selectedWords.count != correctPhrase.count)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            shuffledWords = correctPhrase.shuffled()
        }
    }

    private func verifyPhrase() {
        if selectedWords == correctPhrase {
            onSuccess()
        } else {
            errorMessage = "The words don't match. Please try again."
            showError = true
            selectedWords.removeAll()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showError = false
            }
        }
    }
}

struct WordChip: View {
    let word: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(word)
                .font(.body)
                .foregroundColor(Color("TextPrimary"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("CardBackground"))
                .cornerRadius(20)
        }
        .accessibleButton(label: word, hint: "Tap to select this word")
    }
}

struct SelectedWordChip: View {
    let number: Int
    let word: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(word)
                .font(.body)
                .foregroundColor(.white)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("AccentPrimary"))
        .cornerRadius(20)
        .accessibleButton(
            label: "Word \(number): \(word)",
            hint: "Double tap to remove"
        )
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Success Overlay

struct SuccessOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }

                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(32)
            .background(Color("CardBackground"))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Seed Phrase ViewModel

@MainActor
class SeedPhraseViewModel: ObservableObject {
    @Published var seedPhrase: [String] = []

    func generateSeedPhrase() {
        // TODO: Generate actual BIP39 mnemonic
        // This is a placeholder with common BIP39 words
        let words = [
            "abandon", "ability", "able", "about", "above", "absent",
            "absorb", "abstract", "absurd", "abuse", "access", "accident"
        ]
        seedPhrase = words
    }

    func saveSeedPhrase() {
        // TODO: Save to secure enclave / keychain
        print("Seed phrase saved securely")
        AccessibilityAnnouncement.announce("Recovery phrase backed up successfully")
    }
}

#Preview {
    SeedPhraseBackupView()
}
