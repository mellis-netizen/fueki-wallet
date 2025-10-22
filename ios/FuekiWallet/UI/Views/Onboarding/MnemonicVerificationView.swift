import SwiftUI

struct MnemonicVerificationView: View {
    let mnemonic: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel: MnemonicVerificationViewModel

    init(mnemonic: String) {
        self.mnemonic = mnemonic
        _viewModel = StateObject(wrappedValue: MnemonicVerificationViewModel(mnemonic: mnemonic))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("Verify Recovery Phrase")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Select the words in the correct order to verify you've saved them")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)

                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Word \(viewModel.selectedWords.count + 1) of \(viewModel.wordsToVerify.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        ProgressView(value: Double(viewModel.selectedWords.count), total: Double(viewModel.wordsToVerify.count))
                            .tint(.blue)
                    }
                    .padding(.horizontal, 24)

                    // Current Word Prompt
                    if let current = viewModel.currentWordToVerify {
                        Text("Select word #\(current.index + 1)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Selected Words Display
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(viewModel.selectedWords, id: \.index) { item in
                                SelectedWordCard(index: item.index, word: item.word) {
                                    viewModel.removeWord(item)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: 120)

                    // Word Options
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(viewModel.shuffledWords, id: \.self) { word in
                            WordOptionButton(
                                word: word,
                                isSelected: viewModel.selectedWords.contains(where: { $0.word == word }),
                                isCorrect: viewModel.isCorrect,
                                showResult: viewModel.showResult
                            ) {
                                viewModel.selectWord(word)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Action Buttons
                    VStack(spacing: 16) {
                        if viewModel.isComplete && viewModel.isCorrect {
                            CustomButton(
                                title: "Complete Setup",
                                icon: "checkmark.circle.fill",
                                style: .primary
                            ) {
                                completeSetup()
                            }
                        } else if viewModel.showResult && !viewModel.isCorrect {
                            CustomButton(
                                title: "Try Again",
                                icon: "arrow.clockwise",
                                style: .primary
                            ) {
                                viewModel.reset()
                            }
                        }

                        CustomButton(
                            title: "Back to Recovery Phrase",
                            style: .tertiary
                        ) {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func completeSetup() {
        Task {
            // Save wallet
            do {
                let walletService = WalletService.shared
                try await walletService.saveWallet(mnemonic: mnemonic)

                await MainActor.run {
                    appCoordinator.completeOnboarding()
                    dismiss()
                }
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Selected Word Card
struct SelectedWordCard: View {
    let index: Int
    let word: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(word)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}

// MARK: - Word Option Button
struct WordOptionButton: View {
    let word: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let onTap: () -> Void

    var backgroundColor: Color {
        if showResult && isSelected {
            return isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        } else if isSelected {
            return Color.blue.opacity(0.1)
        }
        return Color(UIColor.tertiarySystemBackground)
    }

    var borderColor: Color {
        if showResult && isSelected {
            return isCorrect ? .green : .red
        } else if isSelected {
            return .blue
        }
        return .clear
    }

    var body: some View {
        Button(action: onTap) {
            Text(word)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .disabled(isSelected)
    }
}

// MARK: - View Model
class MnemonicVerificationViewModel: ObservableObject {
    @Published var selectedWords: [(index: Int, word: String)] = []
    @Published var shuffledWords: [String] = []
    @Published var isComplete = false
    @Published var isCorrect = false
    @Published var showResult = false

    let mnemonic: String
    let allWords: [String]
    let wordsToVerify: [(index: Int, word: String)]

    var currentWordToVerify: (index: Int, word: String)? {
        guard selectedWords.count < wordsToVerify.count else { return nil }
        return wordsToVerify[selectedWords.count]
    }

    init(mnemonic: String) {
        self.mnemonic = mnemonic
        self.allWords = mnemonic.components(separatedBy: " ")

        // Select random words to verify (e.g., 4 words)
        let indicesToVerify = (0..<allWords.count).shuffled().prefix(4)
        self.wordsToVerify = indicesToVerify.map { ($0, allWords[$0]) }.sorted { $0.0 < $1.0 }

        setupShuffledWords()
    }

    private func setupShuffledWords() {
        // Create a pool of words including correct ones and some random others
        var wordPool = Set(wordsToVerify.map { $0.word })

        // Add some random words from the mnemonic to make it challenging
        let randomWords = allWords.filter { !wordPool.contains($0) }.shuffled().prefix(4)
        wordPool.formUnion(randomWords)

        shuffledWords = Array(wordPool).shuffled()
    }

    func selectWord(_ word: String) {
        guard let current = currentWordToVerify else { return }

        selectedWords.append((current.index, word))

        if selectedWords.count == wordsToVerify.count {
            verifySelection()
        }
    }

    func removeWord(_ item: (index: Int, word: String)) {
        if let index = selectedWords.firstIndex(where: { $0.index == item.index }) {
            selectedWords.remove(at: index)
        }
    }

    func verifySelection() {
        isCorrect = selectedWords == wordsToVerify
        isComplete = true
        showResult = true

        if isCorrect {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func reset() {
        selectedWords = []
        isComplete = false
        isCorrect = false
        showResult = false
        setupShuffledWords()
    }
}

// MARK: - Preview
struct MnemonicVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        MnemonicVerificationView(mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
            .environmentObject(AppCoordinator())
    }
}
