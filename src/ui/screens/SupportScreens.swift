//
//  SupportScreens.swift
//  Fueki Wallet
//
//  Support and informational screens (Help, About, Terms, Privacy)
//

import SwiftUI

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var searchText = ""

    let helpTopics = [
        HelpTopic(
            icon: "questionmark.circle.fill",
            title: "Getting Started",
            description: "Learn the basics of using Fueki Wallet",
            articles: 12
        ),
        HelpTopic(
            icon: "dollarsign.circle.fill",
            title: "Buying & Selling",
            description: "How to buy and sell cryptocurrency",
            articles: 8
        ),
        HelpTopic(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "Sending & Receiving",
            description: "Transfer crypto to and from your wallet",
            articles: 6
        ),
        HelpTopic(
            icon: "lock.shield.fill",
            title: "Security",
            description: "Keep your wallet and funds secure",
            articles: 10
        ),
        HelpTopic(
            icon: "creditcard.fill",
            title: "Payment Methods",
            description: "Managing cards and bank accounts",
            articles: 5
        ),
        HelpTopic(
            icon: "exclamationmark.triangle.fill",
            title: "Troubleshooting",
            description: "Solutions to common issues",
            articles: 15
        )
    ]

    var body: some View {
        List {
            // Search Bar
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search help articles", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color("CardBackground"))
                .cornerRadius(12)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Help Topics
            Section {
                ForEach(helpTopics) { topic in
                    NavigationLink(destination: HelpArticlesView(topic: topic)) {
                        HelpTopicRow(topic: topic)
                    }
                }
            }
            .listRowBackground(Color("CardBackground"))

            // Contact Support
            Section {
                Button(action: {
                    if let url = URL(string: "mailto:support@fueki.com") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color("AccentPrimary"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Contact Support")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            Text("Get help from our team")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(Color("CardBackground"))
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpTopic: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let articles: Int
}

struct HelpTopicRow: View {
    let topic: HelpTopic

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color("AccentPrimary").opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: topic.icon)
                    .foregroundColor(Color("AccentPrimary"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline)
                    .foregroundColor(Color("TextPrimary"))

                Text(topic.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("\(topic.articles)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct HelpArticlesView: View {
    let topic: HelpTopic

    var body: some View {
        List {
            ForEach(0..<topic.articles, id: \.self) { index in
                NavigationLink(destination: ArticleDetailView(title: "Article \(index + 1)")) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(Color("AccentPrimary"))

                        Text("How to \(topic.title) - Part \(index + 1)")
                            .font(.body)
                            .foregroundColor(Color("TextPrimary"))
                    }
                }
                .listRowBackground(Color("CardBackground"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArticleDetailView: View {
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))

                Text("This is a placeholder for help article content. In a production app, this would contain detailed instructions, screenshots, and step-by-step guides to help users with specific topics.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                Divider()

                Text("Was this article helpful?")
                    .font(.headline)
                    .foregroundColor(Color("TextPrimary"))

                HStack(spacing: 12) {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("Yes")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(8)
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "hand.thumbsdown.fill")
                            Text("No")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(24)
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Help Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo
                ZStack {
                    Circle()
                        .fill(Color("AccentPrimary").opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("AccentPrimary"))
                }
                .padding(.top, 32)

                // App Info
                VStack(spacing: 8) {
                    Text("Fueki Wallet")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("TextPrimary"))

                    Text("Version 1.0.0 (100)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Description
                Text("Your secure gateway to the world of cryptocurrency. Buy, sell, send, and receive crypto with bank-grade security.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Links
                VStack(spacing: 16) {
                    AboutLink(
                        icon: "globe",
                        title: "Website",
                        url: "https://fueki.com"
                    )

                    AboutLink(
                        icon: "envelope.fill",
                        title: "Support",
                        url: "mailto:support@fueki.com"
                    )

                    AboutLink(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        destination: TermsView()
                    )

                    AboutLink(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        destination: PrivacyView()
                    )
                }
                .padding(.horizontal, 24)

                // Copyright
                Text("© 2024 Fueki Technologies, Inc.\nAll rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutLink<Destination: View>: View {
    let icon: String
    let title: String
    var url: String?
    var destination: Destination?

    init(icon: String, title: String, url: String) {
        self.icon = icon
        self.title = title
        self.url = url
        self.destination = nil
    }

    init(icon: String, title: String, destination: Destination) {
        self.icon = icon
        self.title = title
        self.url = nil
        self.destination = destination
    }

    var body: some View {
        Group {
            if let url = url, let urlObj = URL(string: url) {
                Button(action: {
                    UIApplication.shared.open(urlObj)
                }) {
                    linkContent
                }
            } else if let destination = destination {
                NavigationLink(destination: destination) {
                    linkContent
                }
            }
        }
    }

    private var linkContent: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color("AccentPrimary"))
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundColor(Color("TextPrimary"))

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(12)
    }
}

// MARK: - Terms of Service View

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))

                Text("Last Updated: January 2024")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                LegalSection(
                    title: "1. Acceptance of Terms",
                    content: "By accessing and using Fueki Wallet, you accept and agree to be bound by the terms and provision of this agreement."
                )

                LegalSection(
                    title: "2. Use License",
                    content: "Permission is granted to temporarily download one copy of Fueki Wallet per device for personal, non-commercial transitory viewing only."
                )

                LegalSection(
                    title: "3. User Responsibilities",
                    content: "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account."
                )

                LegalSection(
                    title: "4. Privacy",
                    content: "Your use of Fueki Wallet is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices."
                )

                LegalSection(
                    title: "5. Cryptocurrency Risks",
                    content: "Cryptocurrency trading carries inherent risks. You acknowledge that the value of cryptocurrencies can fluctuate significantly."
                )

                LegalSection(
                    title: "6. Limitation of Liability",
                    content: "Fueki Technologies shall not be liable for any indirect, incidental, special, consequential or punitive damages resulting from your use of the service."
                )

                LegalSection(
                    title: "7. Changes to Terms",
                    content: "We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms."
                )
            }
            .padding(24)
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy View

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))

                Text("Last Updated: January 2024")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                LegalSection(
                    title: "Information We Collect",
                    content: "We collect information you provide directly to us, such as when you create an account, make a transaction, or contact customer support."
                )

                LegalSection(
                    title: "How We Use Your Information",
                    content: "We use the information we collect to provide, maintain, and improve our services, process transactions, and communicate with you."
                )

                LegalSection(
                    title: "Information Sharing",
                    content: "We do not share your personal information with third parties except as described in this policy or with your consent."
                )

                LegalSection(
                    title: "Data Security",
                    content: "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access."
                )

                LegalSection(
                    title: "Your Rights",
                    content: "You have the right to access, correct, or delete your personal information. You may also object to or restrict certain processing of your data."
                )

                LegalSection(
                    title: "Cookies and Tracking",
                    content: "We use cookies and similar tracking technologies to collect and track information about your use of our services."
                )

                LegalSection(
                    title: "Children's Privacy",
                    content: "Our services are not directed to children under 18. We do not knowingly collect personal information from children under 18."
                )

                LegalSection(
                    title: "Contact Us",
                    content: "If you have any questions about this Privacy Policy, please contact us at privacy@fueki.com"
                )
            }
            .padding(24)
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Licenses View

struct LicensesView: View {
    let licenses = [
        License(name: "SwiftUI", version: "iOS 14+", license: "Apple Inc."),
        License(name: "Combine", version: "iOS 13+", license: "Apple Inc."),
        License(name: "CryptoKit", version: "iOS 13+", license: "Apple Inc."),
        License(name: "LocalAuthentication", version: "iOS 8+", license: "Apple Inc.")
    ]

    var body: some View {
        List {
            ForEach(licenses) { license in
                VStack(alignment: .leading, spacing: 8) {
                    Text(license.name)
                        .font(.headline)
                        .foregroundColor(Color("TextPrimary"))

                    HStack {
                        Text("Version: \(license.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(license.license)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color("CardBackground"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct License: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let license: String
}

// MARK: - Payment Methods View

struct PaymentMethodsView: View {
    @State private var paymentMethods: [PaymentMethod] = [
        PaymentMethod(type: .card, name: "Visa •••• 1234", isDefault: true),
        PaymentMethod(type: .bank, name: "Chase Checking", isDefault: false)
    ]
    @State private var showAddPayment = false

    var body: some View {
        List {
            Section {
                ForEach(paymentMethods) { method in
                    PaymentMethodRow(method: method)
                }
                .onDelete(perform: deleteMethod)
            }
            .listRowBackground(Color("CardBackground"))

            Section {
                Button(action: { showAddPayment = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("AccentPrimary"))

                        Text("Add Payment Method")
                            .font(.body)
                            .foregroundColor(Color("AccentPrimary"))
                    }
                }
            }
            .listRowBackground(Color("CardBackground"))
        }
        .listStyle(.insetGrouped)
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddPayment) {
            AddPaymentMethodView()
        }
    }

    private func deleteMethod(at offsets: IndexSet) {
        paymentMethods.remove(atOffsets: offsets)
    }
}

struct PaymentMethod: Identifiable {
    let id = UUID()
    let type: PaymentMethodType
    let name: String
    let isDefault: Bool

    enum PaymentMethodType {
        case card
        case bank
    }
}

struct PaymentMethodRow: View {
    let method: PaymentMethod

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: method.type == .card ? "creditcard.fill" : "building.columns.fill")
                .foregroundColor(Color("AccentPrimary"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(method.name)
                    .font(.body)
                    .foregroundColor(Color("TextPrimary"))

                if method.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundColor(Color("AccentPrimary"))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AddPaymentMethodView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add Payment Method")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This feature is coming soon")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - KYC Status View

struct KYCStatusView: View {
    @State private var verificationStatus: VerificationStatus = .pending

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(verificationStatus.color.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: verificationStatus.icon)
                        .font(.system(size: 60))
                        .foregroundColor(verificationStatus.color)
                }
                .padding(.top, 32)

                // Status Info
                VStack(spacing: 12) {
                    Text(verificationStatus.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("TextPrimary"))

                    Text(verificationStatus.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Verification Levels
                VStack(spacing: 16) {
                    VerificationLevelRow(
                        level: "Level 1",
                        description: "Basic verification",
                        limit: "$1,000/day",
                        isCompleted: true
                    )

                    VerificationLevelRow(
                        level: "Level 2",
                        description: "Enhanced verification",
                        limit: "$10,000/day",
                        isCompleted: verificationStatus == .verified
                    )

                    VerificationLevelRow(
                        level: "Level 3",
                        description: "Full verification",
                        limit: "Unlimited",
                        isCompleted: false
                    )
                }
                .padding(.horizontal, 24)

                if verificationStatus != .verified {
                    Button(action: {}) {
                        Text("Continue Verification")
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
            .padding(.bottom, 32)
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Verification Status")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum VerificationStatus {
    case pending
    case verified
    case rejected

    var title: String {
        switch self {
        case .pending: return "Verification Pending"
        case .verified: return "Account Verified"
        case .rejected: return "Verification Required"
        }
    }

    var description: String {
        switch self {
        case .pending: return "We're reviewing your documents. This usually takes 1-2 business days."
        case .verified: return "Your account is fully verified. Enjoy higher limits and full access to all features."
        case .rejected: return "Please submit additional documents to complete verification."
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .verified: return "checkmark.seal.fill"
        case .rejected: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .verified: return .green
        case .rejected: return .red
        }
    }
}

struct VerificationLevelRow: View {
    let level: String
    let description: String
    let limit: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(level)
                    .font(.headline)
                    .foregroundColor(Color("TextPrimary"))

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(limit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(12)
    }
}

#Preview("Help Center") {
    NavigationView {
        HelpCenterView()
    }
}

#Preview("About") {
    NavigationView {
        AboutView()
    }
}
