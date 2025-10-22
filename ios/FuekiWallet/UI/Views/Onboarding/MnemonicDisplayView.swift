import SwiftUI

struct MnemonicDisplayView: View {
    let mnemonic: String
    @Environment(\.dismiss) var dismiss
    @State private var isBlurred = true
    @State private var showConfirmation = false
    @State private var copied = false

    private var words: [String] {
        mnemonic.components(separatedBy: " ")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("Your Recovery Phrase")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Write down these \(words.count) words in order and keep them safe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)

                    // Warning Banner
                    WarningBanner()

                    // Mnemonic Display
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(words.indices, id: \.self) { index in
                                MnemonicWordCard(
                                    index: index + 1,
                                    word: words[index],
                                    isBlurred: isBlurred
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        // Reveal/Copy Buttons
                        HStack(spacing: 16) {
                            CustomButton(
                                title: isBlurred ? "Reveal" : "Hide",
                                icon: isBlurred ? "eye.fill" : "eye.slash.fill",
                                style: .secondary
                            ) {
                                withAnimation {
                                    isBlurred.toggle()
                                }
                                if !isBlurred {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }

                            CustomButton(
                                title: copied ? "Copied!" : "Copy",
                                icon: "doc.on.doc.fill",
                                style: .secondary
                            ) {
                                copyToClipboard()
                            }
                            .disabled(isBlurred)
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Continue Button
                    VStack(spacing: 12) {
                        CustomButton(
                            title: "I've Written It Down",
                            icon: "checkmark.circle.fill",
                            style: .primary
                        ) {
                            showConfirmation = true
                        }
                        .padding(.horizontal, 24)

                        Text("You'll verify this in the next step")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showConfirmation) {
                MnemonicVerificationView(mnemonic: mnemonic)
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = mnemonic
        withAnimation {
            copied = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

// MARK: - Mnemonic Word Card
struct MnemonicWordCard: View {
    let index: Int
    let word: String
    let isBlurred: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(word)
                .font(.body)
                .fontWeight(.medium)
                .blur(radius: isBlurred ? 8 : 0)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

// MARK: - Warning Banner
struct WarningBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Never share your recovery phrase")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Anyone with these words can access your funds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
struct MnemonicDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        MnemonicDisplayView(mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
    }
}
