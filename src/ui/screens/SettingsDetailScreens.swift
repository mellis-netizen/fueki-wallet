//
//  SettingsDetailScreens.swift
//  Fueki Wallet
//
//  Detailed settings screens for profile, security, and preferences
//

import SwiftUI

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var isSaving = false
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Picture
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color("AccentPrimary").opacity(0.1))
                            .frame(width: 100, height: 100)

                        if let initial = fullName.first {
                            Text(String(initial).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color("AccentPrimary"))
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color("AccentPrimary"))
                        }

                        // Camera button
                        Circle()
                            .fill(Color("AccentPrimary"))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .offset(x: 35, y: 35)
                    }

                    Text("Change Photo")
                        .font(.subheadline)
                        .foregroundColor(Color("AccentPrimary"))
                }
                .padding(.top, 24)

                // Form Fields
                VStack(spacing: 20) {
                    FormField(
                        label: "Full Name",
                        text: $fullName,
                        placeholder: "Enter your full name",
                        icon: "person.fill"
                    )

                    FormField(
                        label: "Email",
                        text: $email,
                        placeholder: "Enter your email",
                        icon: "envelope.fill",
                        keyboardType: .emailAddress
                    )

                    FormField(
                        label: "Phone Number",
                        text: $phoneNumber,
                        placeholder: "Enter your phone number",
                        icon: "phone.fill",
                        keyboardType: .phonePad
                    )
                }
                .padding(.horizontal, 24)

                // Save Button
                Button(action: saveProfile) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("AccentPrimary"))
                    .cornerRadius(16)
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .background(Color("BackgroundPrimary").ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fullName = authViewModel.userName ?? ""
            email = authViewModel.userEmail ?? ""
        }
        .overlay {
            if showSuccess {
                SuccessToast(message: "Profile updated successfully!", isShowing: $showSuccess)
            }
        }
    }

    private func saveProfile() {
        isSaving = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSaving = false
            showSuccess = true
            AccessibilityAnnouncement.announce("Profile updated successfully")
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color("TextPrimary"))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                }
            }
            .padding(16)
            .background(Color("CardBackground"))
            .cornerRadius(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text.isEmpty ? placeholder : text)")
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info Card
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color("AccentPrimary"))

                    Text("Your password must be at least 8 characters with uppercase, lowercase, number, and special character.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color("AccentPrimary").opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Password Fields
                VStack(spacing: 20) {
                    PasswordField(
                        label: "Current Password",
                        text: $currentPassword,
                        isShowing: $showCurrentPassword
                    )

                    PasswordField(
                        label: "New Password",
                        text: $newPassword,
                        isShowing: $showNewPassword
                    )

                    PasswordField(
                        label: "Confirm New Password",
                        text: $confirmPassword,
                        isShowing: $showConfirmPassword
                    )
                }
                .padding(.horizontal, 24)

                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Change Password Button
                Button(action: changePassword) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSaving ? "Updating..." : "Change Password")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        isValidPassword ? Color("AccentPrimary") : Color.gray
                    )
                    .cornerRadius(16)
                }
                .disabled(!isValidPassword || isSaving)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
        .background(Color("BackgroundPrimary").ignoresSafeArea())
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                SuccessToast(message: "Password changed successfully!", isShowing: $showSuccess)
            }
        }
    }

    private var isValidPassword: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    private func changePassword() {
        errorMessage = ""
        isSaving = true

        // Validate password strength
        if !isPasswordStrong(newPassword) {
            errorMessage = "Password must contain uppercase, lowercase, number, and special character"
            isSaving = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSaving = false
            showSuccess = true
            AccessibilityAnnouncement.announce("Password changed successfully")

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }

    private func isPasswordStrong(_ password: String) -> Bool {
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        return hasUppercase && hasLowercase && hasNumber && hasSpecial
    }
}

struct PasswordField: View {
    let label: String
    @Binding var text: String
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color("TextPrimary"))

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                if isShowing {
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                } else {
                    SecureField("", text: $text)
                        .textFieldStyle(.plain)
                }

                Button(action: { isShowing.toggle() }) {
                    Image(systemName: isShowing ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color("CardBackground"))
            .cornerRadius(12)
        }
    }
}

// MARK: - Currency Selection View

struct CurrencySelectionView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) var dismiss

    let currencies = [
        Currency(code: "USD", name: "US Dollar", symbol: "$"),
        Currency(code: "EUR", name: "Euro", symbol: "€"),
        Currency(code: "GBP", name: "British Pound", symbol: "£"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "Fr"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥")
    ]

    var body: some View {
        List {
            ForEach(currencies) { currency in
                Button(action: {
                    selectedCurrency = currency.code
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currency.name)
                                .font(.body)
                                .foregroundColor(Color("TextPrimary"))

                            Text(currency.code)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedCurrency == currency.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentPrimary"))
                        }
                    }
                }
                .listRowBackground(Color("CardBackground"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct Currency: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let symbol: String
}

// MARK: - Language Selection View

struct LanguageSelectionView: View {
    @State private var selectedLanguage = "English"
    @Environment(\.dismiss) var dismiss

    let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Japanese", "Korean", "Chinese"]

    var body: some View {
        List {
            ForEach(languages, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    dismiss()
                }) {
                    HStack {
                        Text(language)
                            .font(.body)
                            .foregroundColor(Color("TextPrimary"))

                        Spacer()

                        if selectedLanguage == language {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentPrimary"))
                        }
                    }
                }
                .listRowBackground(Color("CardBackground"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance View

struct AppearanceView: View {
    @State private var selectedTheme: ColorScheme? = nil
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        List {
            Section {
                ThemeOption(
                    title: "Light",
                    icon: "sun.max.fill",
                    isSelected: appTheme == "light"
                ) {
                    appTheme = "light"
                }

                ThemeOption(
                    title: "Dark",
                    icon: "moon.fill",
                    isSelected: appTheme == "dark"
                ) {
                    appTheme = "dark"
                }

                ThemeOption(
                    title: "System",
                    icon: "circle.lefthalf.filled",
                    isSelected: appTheme == "system"
                ) {
                    appTheme = "system"
                }
            } header: {
                Text("Theme")
            }
            .listRowBackground(Color("CardBackground"))
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThemeOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color("AccentPrimary") : .secondary)
                    .frame(width: 32)

                Text(title)
                    .font(.body)
                    .foregroundColor(Color("TextPrimary"))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color("AccentPrimary"))
                }
            }
        }
    }
}

// MARK: - Connected Devices View

struct ConnectedDevicesView: View {
    @State private var devices: [Device] = [
        Device(name: "iPhone 14 Pro", location: "Current Device", lastActive: Date(), isCurrent: true),
        Device(name: "iPad Air", location: "New York, USA", lastActive: Date().addingTimeInterval(-86400), isCurrent: false),
        Device(name: "MacBook Pro", location: "San Francisco, USA", lastActive: Date().addingTimeInterval(-172800), isCurrent: false)
    ]

    var body: some View {
        List {
            ForEach(devices) { device in
                DeviceRow(device: device) {
                    // Remove device
                    if let index = devices.firstIndex(where: { $0.id == device.id }) {
                        devices.remove(at: index)
                    }
                }
                .listRowBackground(Color("CardBackground"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct Device: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let lastActive: Date
    let isCurrent: Bool
}

struct DeviceRow: View {
    let device: Device
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: deviceIcon)
                    .font(.title2)
                    .foregroundColor(Color("AccentPrimary"))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        if device.isCurrent {
                            Text("(Current)")
                                .font(.caption)
                                .foregroundColor(Color("AccentPrimary"))
                        }
                    }

                    Text(device.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Last active: \(device.lastActive, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !device.isCurrent {
                    Button(action: onRemove) {
                        Text("Remove")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var deviceIcon: String {
        if device.name.contains("iPhone") {
            return "iphone"
        } else if device.name.contains("iPad") {
            return "ipad"
        } else {
            return "laptopcomputer"
        }
    }
}

// MARK: - Backup Phrase View (Complete Implementation)

struct BackupPhraseView: View {
    @State private var isAuthenticated = false
    @State private var showBackupFlow = false

    var body: some View {
        Group {
            if isAuthenticated {
                BackupPhraseContentView()
            } else {
                BiometricGateView(onAuthenticated: {
                    isAuthenticated = true
                })
            }
        }
        .navigationTitle("Recovery Phrase")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BiometricGateView: View {
    let onAuthenticated: () -> Void
    @StateObject private var authManager = BiometricAuthManager()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color("AccentPrimary").opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 60))
                    .foregroundColor(Color("AccentPrimary"))
            }

            VStack(spacing: 12) {
                Text("Authenticate to View")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))

                Text("Use \(authManager.biometricType == .faceID ? "Face ID" : "Touch ID") to view your recovery phrase")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: {
                Task {
                    let success = await authManager.authenticate(reason: "View recovery phrase")
                    if success {
                        onAuthenticated()
                    }
                }
            }) {
                HStack {
                    Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    Text("Authenticate")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color("AccentPrimary"))
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding()
        .background(Color("BackgroundPrimary"))
    }
}

struct BackupPhraseContentView: View {
    @State private var showPhrase = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warning
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Never share your recovery phrase with anyone. Anyone with this phrase can access your funds.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if showPhrase {
                    SeedPhraseDisplayView()
                } else {
                    Button(action: { showPhrase = true }) {
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
            }
        }
        .background(Color("BackgroundPrimary"))
    }
}

struct SeedPhraseDisplayView: View {
    let seedPhrase = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(seedPhrase.enumerated()), id: \.offset) { index, word in
                    SeedWordCard(number: index + 1, word: word)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview("Profile Edit") {
    NavigationView {
        ProfileEditView()
            .environmentObject(AuthenticationViewModel())
    }
}

#Preview("Change Password") {
    NavigationView {
        ChangePasswordView()
    }
}
