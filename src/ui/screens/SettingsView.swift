//
//  SettingsView.swift
//  Fueki Wallet
//
//  Settings and account management
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var showLogoutAlert = false
    @State private var biometricEnabled = true
    @State private var notificationsEnabled = true
    @State private var currencyCode = "USD"

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Profile Picture
                        ZStack {
                            Circle()
                                .fill(Color("AccentPrimary").opacity(0.1))
                                .frame(width: 60, height: 60)

                            if let initial = authViewModel.userEmail?.first {
                                Text(String(initial).uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("AccentPrimary"))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.userName ?? "User")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            Text(authViewModel.userEmail ?? "email@example.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        NavigationLink(destination: ProfileEditView()) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color("CardBackground"))

                // Security Section
                Section("Security") {
                    Toggle(isOn: $biometricEnabled) {
                        Label {
                            Text(authViewModel.biometricType == .faceID ? "Face ID" : "Touch ID")
                        } icon: {
                            Image(systemName: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                                .foregroundColor(Color("AccentPrimary"))
                        }
                    }
                    .tint(Color("AccentPrimary"))
                    .onChange(of: biometricEnabled) { _, newValue in
                        Task {
                            await authViewModel.setBiometricEnabled(newValue)
                        }
                    }

                    NavigationLink(destination: BackupPhraseView()) {
                        Label("Backup Phrase", systemImage: "key.fill")
                    }

                    NavigationLink(destination: ChangePasswordView()) {
                        Label("Change Password", systemImage: "lock.shield.fill")
                    }

                    NavigationLink(destination: ConnectedDevicesView()) {
                        Label("Connected Devices", systemImage: "laptopcomputer.and.iphone")
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Preferences Section
                Section("Preferences") {
                    NavigationLink(destination: CurrencySelectionView(selectedCurrency: $currencyCode)) {
                        HStack {
                            Label("Currency", systemImage: "dollarsign.circle.fill")

                            Spacer()

                            Text(currencyCode)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    .tint(Color("AccentPrimary"))

                    NavigationLink(destination: LanguageSelectionView()) {
                        Label("Language", systemImage: "globe")
                    }

                    NavigationLink(destination: AppearanceView()) {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Payment Methods Section
                Section("Payment Methods") {
                    NavigationLink(destination: PaymentMethodsView()) {
                        Label("Linked Accounts", systemImage: "creditcard.fill")
                    }

                    NavigationLink(destination: KYCStatusView()) {
                        Label("Verification Status", systemImage: "checkmark.seal.fill")
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Support Section
                Section("Support") {
                    NavigationLink(destination: HelpCenterView()) {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                    }

                    Button(action: {
                        // Open support email
                        if let url = URL(string: "mailto:support@fueki.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    .foregroundColor(Color("TextPrimary"))

                    NavigationLink(destination: AboutView()) {
                        Label("About Fueki", systemImage: "info.circle.fill")
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Legal Section
                Section("Legal") {
                    NavigationLink(destination: TermsView()) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }

                    NavigationLink(destination: PrivacyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    NavigationLink(destination: LicensesView()) {
                        Label("Open Source Licenses", systemImage: "doc.plaintext.fill")
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Logout Section
                Section {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color("CardBackground"))

                // Version
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("1.0.0 (100)")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color("CardBackground"))
            }
            .listStyle(.insetGrouped)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// NOTE: All detail view implementations are in SettingsDetailScreens.swift and SupportScreens.swift

#Preview {
    SettingsView()
        .environmentObject(AuthenticationViewModel())
        .environmentObject(WalletViewModel())
}
