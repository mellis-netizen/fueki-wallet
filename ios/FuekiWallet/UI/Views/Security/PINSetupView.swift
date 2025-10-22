import SwiftUI

struct PINSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PINSetupViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Title
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text(viewModel.step == .create ? "Create PIN" : "Confirm PIN")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(viewModel.step == .create ?
                         "Create a 6-digit PIN to secure your wallet" :
                         "Re-enter your PIN to confirm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // PIN Dots
                HStack(spacing: 16) {
                    ForEach(0..<6) { index in
                        Circle()
                            .fill(index < viewModel.pin.count ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.pin.count)

                Spacer()

                // Number Pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 24) {
                            ForEach(1...3, id: \.self) { col in
                                let number = row * 3 + col
                                PINButton(number: "\(number)") {
                                    viewModel.addDigit(number)
                                }
                            }
                        }
                    }

                    HStack(spacing: 24) {
                        // Empty space
                        Color.clear.frame(width: 75, height: 75)

                        PINButton(number: "0") {
                            viewModel.addDigit(0)
                        }

                        Button(action: { viewModel.removeDigit() }) {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                                .frame(width: 75, height: 75)
                        }
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("PIN Mismatch", isPresented: $viewModel.showError) {
                Button("Try Again", role: .cancel) {
                    viewModel.reset()
                }
            } message: {
                Text("The PINs you entered don't match. Please try again.")
            }
            .onChange(of: viewModel.isComplete) { isComplete in
                if isComplete {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - PIN Button
struct PINButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 75, height: 75)
                .background(
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
        }
    }
}

// MARK: - PIN Entry View (for unlocking)
struct PINEntryView: View {
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PINEntryViewModel()

    var body: some View {
        VStack(spacing: 40) {
            // Title
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Enter PIN")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your 6-digit PIN to unlock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)

            // PIN Dots
            HStack(spacing: 16) {
                ForEach(0..<6) { index in
                    Circle()
                        .fill(index < viewModel.pin.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.pin.count)

            if viewModel.showError {
                Text("Incorrect PIN")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            // Number Pad
            VStack(spacing: 16) {
                ForEach(0..<3) { row in
                    HStack(spacing: 24) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            PINButton(number: "\(number)") {
                                viewModel.addDigit(number)
                            }
                        }
                    }
                }

                HStack(spacing: 24) {
                    Color.clear.frame(width: 75, height: 75)

                    PINButton(number: "0") {
                        viewModel.addDigit(0)
                    }

                    Button(action: { viewModel.removeDigit() }) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                            .frame(width: 75, height: 75)
                    }
                }
            }

            Spacer()
        }
        .onChange(of: viewModel.isCorrect) { isCorrect in
            if isCorrect {
                onSuccess()
                dismiss()
            }
        }
    }
}

// MARK: - PIN Setup View Model
class PINSetupViewModel: ObservableObject {
    @Published var pin = ""
    @Published var step: Step = .create
    @Published var showError = false
    @Published var isComplete = false

    private var firstPIN = ""

    enum Step {
        case create, confirm
    }

    func addDigit(_ digit: Int) {
        guard pin.count < 6 else { return }
        pin += "\(digit)"

        if pin.count == 6 {
            handlePINComplete()
        }
    }

    func removeDigit() {
        if !pin.isEmpty {
            pin.removeLast()
        }
    }

    private func handlePINComplete() {
        switch step {
        case .create:
            firstPIN = pin
            pin = ""
            step = .confirm
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        case .confirm:
            if pin == firstPIN {
                savePIN(pin)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isComplete = true
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showError = true
            }
        }
    }

    func reset() {
        pin = ""
        firstPIN = ""
        step = .create
    }

    private func savePIN(_ pin: String) {
        // Save to Keychain
        let secureStorage = SecureStorage.shared
        try? secureStorage.savePIN(pin)
    }
}

// MARK: - PIN Entry View Model
class PINEntryViewModel: ObservableObject {
    @Published var pin = ""
    @Published var showError = false
    @Published var isCorrect = false

    func addDigit(_ digit: Int) {
        guard pin.count < 6 else { return }
        pin += "\(digit)"

        if pin.count == 6 {
            verifyPIN()
        }
    }

    func removeDigit() {
        if !pin.isEmpty {
            pin.removeLast()
            showError = false
        }
    }

    private func verifyPIN() {
        let secureStorage = SecureStorage.shared

        if let savedPIN = try? secureStorage.retrievePIN(), savedPIN == pin {
            isCorrect = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.pin = ""
            }
        }
    }
}

// MARK: - Preview
struct PINSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PINSetupView()
    }
}
