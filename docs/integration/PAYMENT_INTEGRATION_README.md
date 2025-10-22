# Payment Ramp Integration - Implementation Guide

## Overview

This document provides a comprehensive guide to the payment on-ramp and off-ramp integration implemented for the Fueki Mobile Wallet.

## Architecture

### Core Components

```
/src/services/payment/
├── PaymentRampService.swift          # Main service coordinator
├── PaymentModels.swift                # Data models and types
├── RampNetworkProvider.swift         # Ramp Network implementation
├── MoonPayProvider.swift              # MoonPay implementation (fallback)
├── PaymentWebhookService.swift       # Webhook handler
└── FraudDetectionService.swift       # Risk assessment
```

### Provider Strategy

**Primary Provider**: Ramp Network
- Lower fees (0.49% - 2.9%)
- Best geographic coverage (170+ countries)
- Fastest KYC (2-4 minutes via Onfido)
- Native iOS SDK

**Fallback Provider**: MoonPay
- More mature off-ramp
- Broader US coverage
- Higher fees (1% - 4.5%)
- Better brand recognition

## Features

### ✅ Implemented Features

1. **On-Ramp (Buy Crypto)**
   - Credit/debit card purchases
   - Bank transfer support
   - Apple Pay integration
   - Real-time quotes
   - Transaction monitoring
   - Multi-provider fallback

2. **Off-Ramp (Sell Crypto)**
   - Bank account linking
   - Crypto to fiat conversion
   - Transaction tracking
   - Settlement monitoring

3. **Security & Compliance**
   - KYC/AML verification
   - Fraud detection
   - Rate limiting
   - Webhook signature verification
   - Transaction risk assessment

4. **Error Handling**
   - Retry logic with exponential backoff
   - Provider failover
   - User-friendly error messages
   - Transaction status polling

## Configuration

### API Keys Setup

Add the following keys to your `Info.plist`:

```xml
<key>RampAPIKey</key>
<string>YOUR_RAMP_API_KEY</string>

<key>MoonPayAPIKey</key>
<string>YOUR_MOONPAY_API_KEY</string>

<key>RampWebhookSecret</key>
<string>YOUR_RAMP_WEBHOOK_SECRET</string>

<key>MoonPayWebhookSecret</key>
<string>YOUR_MOONPAY_WEBHOOK_SECRET</string>
```

### Environment Variables

For production, store API keys securely using:
- iOS Keychain
- Environment-specific configuration files
- Backend API proxy (recommended)

## Usage Examples

### Buy Cryptocurrency

```swift
import SwiftUI

struct PurchaseExample: View {
    @StateObject private var viewModel = BuyCryptoViewModel()

    func purchase() async {
        let asset = CryptoAsset(
            symbol: "ETH",
            name: "Ethereum",
            network: "ethereum",
            balance: 0,
            priceUSD: 2000
        )

        await viewModel.processPurchase(
            asset: asset,
            amount: 100.0,
            paymentMethod: .creditCard
        )
    }
}
```

### Sell Cryptocurrency

```swift
struct SellExample: View {
    @StateObject private var viewModel = SellCryptoViewModel()

    func sell() async {
        let asset = CryptoAsset(
            symbol: "ETH",
            name: "Ethereum",
            network: "ethereum",
            balance: 1.5,
            priceUSD: 2000
        )

        let bankAccount = BankAccount(
            id: "bank_1",
            bankName: "Chase",
            accountType: .checking,
            lastFourDigits: "4242",
            routingNumber: "021000021",
            isVerified: true
        )

        await viewModel.processSale(
            asset: asset,
            amount: 1.0,
            bankAccount: bankAccount
        )
    }
}
```

### Direct Service Usage

```swift
let service = PaymentRampService.shared

// Get quote
let quote = try await service.getPurchaseQuote(
    asset: ethAsset,
    fiatAmount: 500,
    paymentMethod: .creditCard
)

// Check KYC status
let kycStatus = try await service.checkKYCStatus()
print("KYC Tier: \(kycStatus.tier.displayName)")
print("Daily Limit: $\(kycStatus.limits.daily)")

// Monitor transaction
service.monitorTransaction(transactionId) { result in
    switch result {
    case .success(let status):
        print("Status: \(status.status.displayName)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

## Fraud Detection

### Risk Assessment

The `FraudDetectionService` evaluates transactions based on:

1. **Amount-based risk**: Large transactions flagged
2. **Velocity checks**: Multiple transactions in short time
3. **Daily limits**: Transaction count and volume
4. **Geographic risk**: High-risk countries
5. **Payment method risk**: Card payments for large amounts
6. **Asset risk**: Privacy coins and high-risk tokens

### Risk Levels

- **Low** (0-19): Proceed normally
- **Medium** (20-39): Additional verification recommended
- **High** (40-69): Enhanced due diligence required
- **Critical** (70+): Block transaction

### Rate Limiting

- Max 3 transactions per hour
- Max 10 transactions per day
- Max $10,000 per day (KYC dependent)

## Webhook Integration

### Backend Setup Required

To receive real-time transaction updates, set up a backend webhook receiver:

```swift
// Backend endpoint example (Node.js/Express)
app.post('/webhooks/ramp', (req, res) => {
    const signature = req.headers['x-ramp-signature'];
    const payload = req.body;

    // Verify signature
    if (!verifySignature(payload, signature)) {
        return res.status(401).send('Invalid signature');
    }

    // Process webhook
    const event = payload.type;
    const purchase = payload.purchase;

    // Notify iOS app via push notification
    sendPushNotification(purchase.userId, {
        transactionId: purchase.id,
        status: purchase.status
    });

    res.status(200).send('OK');
});
```

### iOS Webhook Processing

```swift
// When webhook notification received
let webhookService = PaymentWebhookService.shared

// Verify and process
if webhookService.verifyRampWebhook(payload: data, signature: signature) {
    let event = try webhookService.processRampWebhook(data)
    print("Transaction \(event.transactionId): \(event.status)")
}
```

## Provider Comparison

| Feature | Ramp Network | MoonPay |
|---------|--------------|---------|
| **On-ramp Fee** | 0.49% - 2.9% | 1% - 4.5% |
| **Off-ramp Fee** | 1.5% - 3% | 1% - 4% |
| **Countries** | 170+ | 160+ |
| **KYC Provider** | Onfido | Jumio |
| **KYC Speed** | 2-4 min | 3-5 min |
| **Transaction Speed** | 5-15 min | 5-10 min |
| **Off-ramp Status** | Beta | Production |
| **iOS SDK** | Native Swift | Native Swift |

## KYC Tiers

### Tier 1: Basic
- **Requirements**: Email + phone
- **Limits**: $50 - $200 per transaction
- **Verification**: Instant

### Tier 2: Standard
- **Requirements**: Government ID + selfie
- **Limits**: $500 - $2,000 per transaction
- **Verification**: 2-30 minutes (automated)

### Tier 3: Enhanced
- **Requirements**: Proof of address
- **Limits**: $10,000+ per transaction
- **Verification**: 1-24 hours (manual review)

## Error Handling

### Common Errors

```swift
enum PaymentError {
    case invalidAmount(String)       // Min/max validation
    case invalidWalletAddress        // Address format invalid
    case kycRequired                 // KYC verification needed
    case kycPending                  // KYC under review
    case insufficientFunds           // Not enough crypto to sell
    case providerError(String)       // Provider API error
    case networkError(Error)         // Network connectivity
    case rateLimited                 // Too many requests
    case timeout                     // Request timeout
}
```

### Retry Strategy

- Maximum 3 retry attempts
- 2-second delay between retries
- Exponential backoff for network errors
- No retry for validation errors

## Testing

### Sandbox Environment

**Ramp Network**:
- URL: https://app.demo.ramp.network
- Test cards provided in docs
- Auto-approve KYC

**MoonPay**:
- URL: https://buy-sandbox.moonpay.com
- Test cards in documentation
- Instant KYC approval

### Test Scenarios

1. ✅ Successful purchase (card)
2. ✅ Successful purchase (bank transfer)
3. ✅ Failed KYC verification
4. ✅ Insufficient funds
5. ✅ Card declined
6. ✅ Transaction timeout
7. ✅ User cancellation
8. ✅ Network error
9. ✅ Rate limiting
10. ✅ Webhook delivery

## Security Best Practices

### API Key Security
- ❌ Never hardcode API keys in source code
- ✅ Use Info.plist with .gitignore exclusion
- ✅ Use iOS Keychain for production
- ✅ Implement backend proxy for sensitive operations

### Webhook Security
- ✅ Always verify webhook signatures
- ✅ Use HTTPS for webhook endpoints
- ✅ Implement replay attack prevention
- ✅ Rate limit webhook endpoints

### User Data Protection
- ✅ Minimize PII storage
- ✅ Encrypt sensitive data (AES-256)
- ✅ Implement data deletion on request
- ✅ Follow GDPR/CCPA compliance

## Performance Optimization

### Caching Strategy
- Cache quotes for 60 seconds
- Cache KYC status for 5 minutes
- Cache supported currencies for 1 hour

### Network Optimization
- Implement request debouncing
- Use connection pooling
- Compress request payloads
- Implement request timeout (30s)

## Monitoring & Analytics

### Key Metrics to Track

1. **Transaction Success Rate**: % of completed transactions
2. **Average Transaction Time**: From initiation to completion
3. **Provider Performance**: Success rate per provider
4. **Error Rate**: By error type
5. **KYC Conversion**: % of users completing KYC
6. **Fee Revenue**: Total fees collected

### Logging

```swift
// Transaction lifecycle logging
print("🔵 Transaction initiated: \(transactionId)")
print("⏳ Awaiting payment: \(transactionId)")
print("✅ Transaction completed: \(transactionId)")
print("❌ Transaction failed: \(transactionId) - \(reason)")
```

## Compliance Considerations

### Regulatory Requirements

1. **MSB Registration** (US): Register with FinCEN
2. **State Licenses**: Money transmitter licenses
3. **KYC/AML**: Customer verification and monitoring
4. **SAR Reporting**: Suspicious activity reporting
5. **Data Privacy**: GDPR, CCPA compliance

### User Consent

Ensure users agree to:
- Terms of service
- Privacy policy
- Third-party data sharing (KYC providers)
- Transaction fees disclosure

## Roadmap

### Phase 1: ✅ Complete
- Basic on-ramp integration
- Multi-provider support
- Fraud detection
- Transaction monitoring

### Phase 2: 🔄 In Progress
- Advanced off-ramp features
- Recurring purchases
- Price alerts
- Transaction history

### Phase 3: 📋 Planned
- Fiat wallet integration
- DCA (Dollar-Cost Averaging)
- Limit orders
- Tax reporting

## Support & Resources

### Documentation
- Ramp Network: https://docs.ramp.network/
- MoonPay: https://docs.moonpay.com/

### API Status Pages
- Ramp Network: https://status.ramp.network/
- MoonPay: https://status.moonpay.com/

### Developer Support
- Ramp Network: support@ramp.network
- MoonPay: developers@moonpay.com

## License

This integration is proprietary to Fueki Wallet. See LICENSE for details.

---

**Last Updated**: October 21, 2025
**Version**: 1.0.0
**Author**: Backend Integration Developer (Claude Code Agent)
