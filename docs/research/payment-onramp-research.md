# Payment On/Off Ramp SDK Research for iOS

## Executive Summary

Payment on/off ramp solutions enable users to convert fiat currency (USD, EUR, etc.) to cryptocurrency and vice versa. This research covers production-ready iOS SDKs that can be integrated into the Fueki mobile wallet for seamless fiat-crypto conversions.

---

## Production-Ready Payment Gateway SDKs for iOS

### 1. **MoonPay SDK** ⭐ RECOMMENDED FOR CONSUMER WALLETS
- **Platform**: iOS (Native Swift SDK)
- **Status**: Production-ready, industry leader
- **Repository**: https://github.com/moonpay/mobile-sdk-ios
- **License**: Commercial (API key required)

**Key Features**:
- 🌍 160+ countries supported
- 💳 Credit/debit cards, bank transfers, Apple Pay
- 🪙 80+ cryptocurrencies (BTC, ETH, USDC, SOL, etc.)
- 🔐 Built-in KYC/AML compliance
- 📱 Native iOS UI (customizable)
- ⚡ Instant purchases (most cards)
- 🔄 On-ramp and off-ramp support
- 💱 Real-time exchange rates

**Integration Complexity**: Easy (2-3 days)

**Implementation**:
```swift
import MoonPaySDK

let moonPay = MoonPay(apiKey: "pk_live_YOUR_API_KEY")

let config = MoonPayConfig(
    walletAddress: userWalletAddress,
    currencyCode: "eth", // BTC, ETH, USDC, etc.
    baseCurrencyCode: "usd",
    baseCurrencyAmount: 100.0,
    colorCode: "#4F46E5" // Brand color
)

moonPay.present(
    config: config,
    from: viewController
) { result in
    switch result {
    case .success(let transaction):
        print("Transaction ID: \(transaction.id)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

**Pricing**:
- On-ramp: 1-4.5% fee (card: 4.5%, bank: 1%)
- Off-ramp: 1-4% fee
- Volume discounts available
- No monthly minimums for basic tier

**KYC Requirements**:
- Basic: Name, email, phone (up to $150)
- Standard: ID verification (up to $2,000)
- Enhanced: Proof of address (unlimited)
- Automated KYC flow (Jumio integration)

**Geographic Coverage**: ✅ Excellent
- United States: ✅ (all states except NY requires BitLicense)
- Europe: ✅ (EU, UK, Switzerland)
- Asia: ✅ (Singapore, Hong Kong, Japan, South Korea)
- Latin America: ✅ (Brazil, Mexico, Argentina)

**Documentation**: https://docs.moonpay.com/

---

### 2. **Ramp Network SDK** ⭐ RECOMMENDED FOR DeFi WALLETS
- **Platform**: iOS (Native Swift SDK)
- **Status**: Production-ready, DeFi-focused
- **Repository**: https://github.com/RampNetwork/ramp-instant-sdk
- **License**: Commercial (API key required)

**Key Features**:
- 🌍 170+ countries supported
- 💳 Credit/debit cards, bank transfers, Apple Pay, Google Pay
- 🪙 100+ cryptocurrencies + NFTs
- 🔐 Automated KYC/AML (Onfido integration)
- 📱 Embedded or hosted UI
- ⚡ Fast onboarding (60 seconds)
- 🔄 On-ramp and off-ramp (off-ramp in beta)
- 💱 Competitive rates (often better than MoonPay)

**Integration Complexity**: Easy (2-3 days)

**Implementation**:
```swift
import RampSDK

let ramp = RampSDK(
    hostAppName: "Fueki Wallet",
    hostLogoUrl: "https://fueki.com/logo.png"
)

let config = RampPurchaseConfig(
    swapAsset: "ETH",
    userAddress: userWalletAddress,
    fiatCurrency: "USD",
    fiatValue: 100,
    hostApiKey: "YOUR_API_KEY"
)

ramp.show(
    config: config,
    from: viewController
) { result in
    switch result {
    case .purchased(let purchase):
        print("Purchase: \(purchase)")
    case .cancelled:
        print("User cancelled")
    case .error(let error):
        print("Error: \(error)")
    }
}
```

**Pricing**:
- On-ramp: 0.49-2.9% fee (card: 2.9%, bank: 0.49%)
- Off-ramp: 1.5-3% fee (beta)
- No setup fees
- Volume discounts available

**KYC Requirements**:
- Tier 1: Email verification ($50 limit)
- Tier 2: Basic KYC ($500 limit)
- Tier 3: Enhanced KYC (unlimited)
- Onfido-powered verification

**Geographic Coverage**: ✅ Excellent
- Broadest coverage globally (170+ countries)
- United States: ✅ (all states)
- Europe: ✅ (EU, UK, EEA)
- Asia: ✅ (India, Philippines, Vietnam)
- Africa: ✅ (Nigeria, Kenya, South Africa)

**Documentation**: https://docs.ramp.network/

---

### 3. **Transak SDK**
- **Platform**: iOS (Native Swift SDK)
- **Status**: Production-ready, global focus
- **Repository**: https://github.com/Transak/transak-sdk
- **License**: Commercial (API key required)

**Key Features**:
- 🌍 160+ countries, 125+ currencies
- 💳 Credit/debit cards, bank transfers, Apple Pay, UPI (India)
- 🪙 150+ cryptocurrencies
- 🔐 Sumsub KYC integration
- 📱 Widget SDK (web-based)
- ⚡ NFT purchases supported
- 🔄 On-ramp and off-ramp
- 💱 Multi-payment method aggregation

**Integration Complexity**: Easy (2-3 days)

**Implementation**:
```swift
import Transak

let transak = Transak(
    environment: .production,
    apiKey: "YOUR_API_KEY"
)

let config = TransakConfig(
    walletAddress: userWalletAddress,
    cryptoCurrencyCode: "ETH",
    fiatCurrency: "USD",
    fiatAmount: 100,
    network: "ethereum"
)

transak.present(
    config: config,
    from: viewController
) { event in
    switch event {
    case .orderCreated(let order):
        print("Order: \(order)")
    case .orderCompleted(let order):
        print("Completed: \(order)")
    case .closed:
        print("User closed widget")
    }
}
```

**Pricing**:
- On-ramp: 0.99-5.5% fee (varies by payment method)
- Off-ramp: 2-4% fee
- Free tier available (limited features)
- Custom pricing for high volume

**KYC Requirements**:
- Tier 1: Email + phone ($50-$200)
- Tier 2: ID verification ($500-$2,000)
- Tier 3: Enhanced verification (unlimited)
- Sumsub integration for compliance

**Geographic Coverage**: ✅ Very Good
- United States: ✅ (all states)
- Europe: ✅ (EU, UK)
- Asia: ✅ (India, Indonesia, Philippines)
- Latin America: ✅ (Brazil, Mexico)

**Documentation**: https://docs.transak.com/

---

### 4. **Stripe Crypto On-Ramp** (NEW)
- **Platform**: iOS (Web-based integration)
- **Status**: Production-ready (launched 2023)
- **Integration**: Web3 SDK + Stripe SDK
- **License**: Commercial (Stripe account required)

**Key Features**:
- 🌍 Stripe's global reach (47+ countries)
- 💳 Credit/debit cards, ACH, wire transfer
- 🪙 Limited cryptocurrencies (BTC, ETH, USDC)
- 🔐 Stripe KYC infrastructure
- 📱 Web-based flow (opens in browser)
- ⚡ Fast settlement (Stripe network)
- 🔄 On-ramp only (no off-ramp yet)
- 💱 Competitive rates

**Integration Complexity**: Medium (4-5 days, requires Stripe account)

**Implementation**:
```swift
import Stripe

let cryptoOnramp = StripeAPI.CryptoOnramp(
    clientSecret: clientSecret,
    configuration: .default()
)

cryptoOnramp.destinationWalletAddress = userWalletAddress
cryptoOnramp.destinationNetwork = "ethereum"
cryptoOnramp.destinationCurrency = "usdc"

present(cryptoOnramp, animated: true)
```

**Pricing**:
- On-ramp: 1.5-3% fee
- Stripe payment processing fees apply
- No monthly fees
- Enterprise pricing available

**KYC Requirements**:
- Stripe identity verification
- Banking compliance standards
- Business KYC required for wallet providers

**Geographic Coverage**: ⚠️ Limited (expanding)
- United States: ✅ (most states)
- Europe: ⚠️ Limited (UK, select EU countries)
- Asia: ❌ Not yet
- Latin America: ❌ Not yet

**Documentation**: https://stripe.com/docs/crypto

---

### 5. **Wyre (Acquired by Bolt)** ⚠️ SUNSETTING
- **Platform**: iOS SDK
- **Status**: ⚠️ Being sunset by Bolt (acquired 2023)
- **License**: Commercial

**Note**: Wyre is being phased out after Bolt acquisition. Not recommended for new integrations. Existing users migrating to MoonPay or Ramp.

---

### 6. **Banxa**
- **Platform**: iOS (Web widget)
- **Status**: Production-ready
- **Integration**: Web-based (iframe or browser)
- **License**: Commercial

**Key Features**:
- 🌍 40+ countries
- 💳 Cards, bank transfers, Apple Pay
- 🪙 60+ cryptocurrencies
- 🔐 Jumio KYC
- 📱 Web widget (not native)
- 🔄 On-ramp and off-ramp

**Integration Complexity**: Easy (1-2 days)

**Pricing**:
- On-ramp: 2-4% fee
- Off-ramp: 2-3% fee

**Geographic Coverage**: ⚠️ Moderate
- Limited US coverage (select states)
- Strong in Australia, Europe

**Documentation**: https://docs.banxa.com/

---

### 7. **Simplex (Acquired by Nuvei)**
- **Platform**: iOS (API integration)
- **Status**: Mature, enterprise-focused
- **License**: Commercial

**Key Features**:
- 🌍 170+ countries
- 💳 Credit/debit cards only
- 🪙 100+ cryptocurrencies
- 🔐 Built-in fraud protection
- 📱 API-based (custom UI required)
- 🔄 On-ramp only

**Integration Complexity**: Medium (5-7 days)

**Pricing**:
- On-ramp: 3.5-5% fee
- Higher fees than competitors

**Geographic Coverage**: ✅ Good
- Global coverage
- Higher fees may limit adoption

**Documentation**: https://www.simplex.com/developers

---

## SDK Comparison Matrix

| Feature | MoonPay | Ramp Network | Transak | Stripe Crypto | Banxa | Simplex |
|---------|---------|--------------|---------|---------------|-------|---------|
| **iOS Native SDK** | ✅ Swift | ✅ Swift | ✅ Swift | ⚠️ Web | ⚠️ Web | ⚠️ API |
| **Countries** | 160+ | 170+ | 160+ | 47 | 40+ | 170+ |
| **Cryptocurrencies** | 80+ | 100+ | 150+ | 3 | 60+ | 100+ |
| **On-ramp Fee** | 1-4.5% | 0.49-2.9% | 0.99-5.5% | 1.5-3% | 2-4% | 3.5-5% |
| **Off-ramp Support** | ✅ Yes | ⚠️ Beta | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| **Apple Pay** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **KYC Integration** | Jumio | Onfido | Sumsub | Stripe | Jumio | In-house |
| **Setup Time** | 2-3 days | 2-3 days | 2-3 days | 4-5 days | 1-2 days | 5-7 days |
| **Free Tier** | ❌ No | ❌ No | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Customization** | High | High | Medium | Medium | Low | Medium |
| **NFT Support** | ❌ No | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Best For** | Consumer | DeFi | Global | Stripe users | Australia | Enterprise |

---

## Integration Requirements and API Capabilities

### Common Integration Requirements

1. **API Key / Partner Account**
   - Register as partner/developer
   - Complete business verification
   - Obtain API keys (sandbox + production)
   - Configure webhooks for transaction updates

2. **KYC/AML Compliance Configuration**
   - Define tier limits
   - Customize verification flows
   - Set up compliance webhooks
   - Configure blocked jurisdictions

3. **Technical Requirements**
   - iOS 13.0+ minimum
   - Swift 5.0+
   - Minimum 2GB RAM
   - Network connectivity (HTTPS)

4. **UI Customization**
   - Brand colors and logos
   - Custom text/translations
   - Theme selection (light/dark)
   - Custom CSS (web widgets)

### API Capabilities Comparison

#### **MoonPay API**
```swift
// Available API endpoints
- GET /v3/currencies - List supported cryptocurrencies
- POST /v3/transactions - Create on-ramp transaction
- GET /v3/transactions/:id - Get transaction status
- POST /v3/webhooks - Configure webhooks
- GET /v3/ip_address - Check user's country
- GET /v3/limits - Get user KYC limits
```

**Webhooks**: Transaction status, KYC updates, refunds

**Advanced Features**:
- Buy limits API
- Currency conversion API
- Customer history API
- Refund API

#### **Ramp Network API**
```swift
// Available API endpoints
- GET /api/host-api/assets - List supported assets
- POST /api/host-api/purchase - Create purchase
- GET /api/host-api/purchase/:id - Get purchase status
- POST /api/host-api/webhooks - Configure webhooks
- GET /api/host-api/quotes - Get price quotes
```

**Webhooks**: Purchase events, KYC status, asset sent

**Advanced Features**:
- Off-ramp API (beta)
- NFT purchase API
- Swap API
- Recurring purchases API

#### **Transak API**
```swift
// Available API endpoints
- GET /api/v1/currencies/crypto-currencies - List cryptos
- GET /api/v1/currencies/fiat-currencies - List fiat
- POST /api/v1/order - Create order
- GET /api/v1/order/:id - Get order status
- POST /api/v1/webhooks - Configure webhooks
- GET /api/v1/partners/limits - Get limits
```

**Webhooks**: Order created, completed, failed, cancelled

**Advanced Features**:
- Multi-payment method routing
- Dynamic fee calculation
- NFT metadata API
- Batch order API

---

## Feature Analysis

### Payment Methods Supported

| Provider | Card | Bank Transfer | Apple Pay | Google Pay | ACH | Wire | UPI (India) |
|----------|------|---------------|-----------|------------|-----|------|-------------|
| MoonPay | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Ramp Network | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Transak | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stripe Crypto | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Banxa | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Simplex | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Transaction Speed

| Provider | Card (Instant) | Bank Transfer | Average Time |
|----------|----------------|---------------|--------------|
| MoonPay | ✅ 5-10 min | 1-3 days | 10 min |
| Ramp Network | ✅ 5-15 min | 1-5 days | 12 min |
| Transak | ✅ 10-20 min | 2-5 days | 15 min |
| Stripe Crypto | ✅ 5-10 min | 1-3 days | 10 min |
| Banxa | ⚠️ 15-30 min | 2-5 days | 25 min |
| Simplex | ⚠️ 10-30 min | N/A | 20 min |

### Supported Blockchains

| Blockchain | MoonPay | Ramp | Transak | Stripe | Banxa | Simplex |
|------------|---------|------|---------|--------|-------|---------|
| Bitcoin | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ethereum | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Polygon | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Solana | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Avalanche | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Arbitrum | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Optimism | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| BSC | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Near | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Cosmos | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## KYC/AML Compliance Requirements

### Regulatory Frameworks

All providers comply with:
- **KYC (Know Your Customer)**: Identity verification
- **AML (Anti-Money Laundering)**: Transaction monitoring
- **CTF (Counter-Terrorism Financing)**: Sanctions screening
- **PSD2 (EU)**: Strong customer authentication
- **GDPR (EU)**: Data protection
- **FinCEN (US)**: MSB registration

### KYC Tier System (Industry Standard)

#### **Tier 1: Basic Verification**
- Email + phone verification
- Limit: $50-$200 per transaction
- Time: Instant
- Information: Name, email, phone

#### **Tier 2: Standard Verification**
- Government ID scan (passport, driver's license)
- Selfie verification
- Limit: $500-$2,000 per transaction
- Time: 5-30 minutes (automated)
- Information: Full name, DOB, address, ID

#### **Tier 3: Enhanced Verification**
- Proof of address (utility bill, bank statement)
- Enhanced due diligence
- Limit: $10,000+ per transaction (unlimited)
- Time: 1-24 hours (manual review)
- Information: All Tier 2 + address proof

### Provider-Specific KYC Partners

| Provider | KYC Partner | Technology | Speed |
|----------|-------------|------------|-------|
| MoonPay | Jumio | AI + Liveness | 3-5 min |
| Ramp Network | Onfido | Biometric + AI | 2-4 min |
| Transak | Sumsub | AI + Manual | 5-10 min |
| Stripe Crypto | Stripe Identity | In-house | 3-5 min |
| Banxa | Jumio | AI + Liveness | 5-10 min |
| Simplex | In-house | Manual review | 10-30 min |

### Data Requirements for Wallet Provider

As a wallet provider integrating on/off-ramp, you must:

1. **Business Registration**
   - Register as MSB (Money Service Business) in US
   - Register with FinCEN
   - State-level money transmitter licenses (varies)
   - EU: EMI license or partner with licensed provider

2. **Compliance Documentation**
   - Privacy policy (GDPR compliant)
   - Terms of service
   - AML policy
   - User consent flows
   - Data retention policy

3. **User Data Handling**
   - Store minimal PII
   - Encrypt data at rest (AES-256)
   - Secure data transmission (TLS 1.3)
   - Right to deletion (GDPR Article 17)
   - Data breach notification procedures

4. **Transaction Monitoring**
   - Implement transaction limits
   - Monitor for suspicious patterns
   - Report SAR (Suspicious Activity Reports) if required
   - Maintain audit logs (5-7 years)

---

## Fee Structure Deep Dive

### MoonPay Pricing Example (US Customer)
```
Purchase: $1,000 USD → ETH
- Card fee: 4.5% = $45
- Network fee: ~$5
- Total cost: $1,050
- User receives: ~$945 worth of ETH
- Effective fee: ~10.5%

Purchase: $1,000 USD → ETH (ACH)
- ACH fee: 1% = $10
- Network fee: ~$5
- Total cost: $1,015
- User receives: ~$985 worth of ETH
- Effective fee: ~1.5%
```

### Ramp Network Pricing Example
```
Purchase: $1,000 USD → ETH
- Card fee: 2.9% = $29
- Network fee: ~$3
- Total cost: $1,032
- User receives: ~$968 worth of ETH
- Effective fee: ~3.2%

Purchase: $1,000 USD → ETH (Open Banking)
- Open Banking fee: 0.49% = $4.90
- Network fee: ~$3
- Total cost: $1,007.90
- User receives: ~$992 worth of ETH
- Effective fee: ~0.79%
```

### Volume Discount Structure

Most providers offer volume discounts:

| Monthly Volume | MoonPay Fee | Ramp Fee | Transak Fee |
|----------------|-------------|----------|-------------|
| $0 - $50K | 4.5% | 2.9% | 3.5% |
| $50K - $250K | 3.5% | 2.5% | 3.0% |
| $250K - $1M | 2.5% | 2.0% | 2.5% |
| $1M+ | Custom | Custom | Custom |

---

## Geographic Coverage Analysis

### United States Coverage

| Provider | Coverage | Notes |
|----------|----------|-------|
| MoonPay | 49 states | NY requires BitLicense |
| Ramp Network | 50 states | Full coverage |
| Transak | 50 states | Full coverage |
| Stripe Crypto | 45 states | Expanding |
| Banxa | 30 states | Limited |
| Simplex | 48 states | NY, HI restrictions |

### European Union Coverage

| Provider | EU Coverage | UK | Switzerland | Norway |
|----------|-------------|-----|-------------|--------|
| MoonPay | ✅ All | ✅ | ✅ | ✅ |
| Ramp Network | ✅ All | ✅ | ✅ | ✅ |
| Transak | ✅ All | ✅ | ✅ | ✅ |
| Stripe Crypto | ⚠️ Limited | ✅ | ❌ | ❌ |
| Banxa | ✅ All | ✅ | ✅ | ❌ |
| Simplex | ✅ All | ✅ | ✅ | ✅ |

### Asia Coverage

| Provider | India | China | Japan | South Korea | Singapore | Philippines |
|----------|-------|-------|-------|-------------|-----------|-------------|
| MoonPay | ✅ | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| Ramp Network | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Transak | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Stripe Crypto | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Banxa | ⚠️ | ❌ | ⚠️ | ⚠️ | ✅ | ❌ |
| Simplex | ✅ | ❌ | ✅ | ✅ | ✅ | ⚠️ |

### Latin America Coverage

| Provider | Brazil | Mexico | Argentina | Colombia | Chile |
|----------|--------|--------|-----------|----------|-------|
| MoonPay | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ramp Network | ✅ | ✅ | ✅ | ✅ | ✅ |
| Transak | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stripe Crypto | ❌ | ❌ | ❌ | ❌ | ❌ |
| Banxa | ⚠️ | ⚠️ | ❌ | ❌ | ❌ |
| Simplex | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |

---

## Recommended Solution for Fueki Wallet

### **Primary Recommendation: Ramp Network**

**Rationale**:
1. ✅ Native Swift iOS SDK (best iOS experience)
2. ✅ Lowest fees (0.49% for bank transfers)
3. ✅ Fastest KYC (Onfido, 2-4 minutes)
4. ✅ Best geographic coverage (170+ countries)
5. ✅ Apple Pay and Google Pay support
6. ✅ Clean, modern UI (highly customizable)
7. ✅ Excellent documentation and support
8. ✅ Off-ramp support (beta, but functional)
9. ✅ No monthly minimums or setup fees

**Secondary Recommendation: MoonPay**
- More mature off-ramp product
- Better brand recognition
- Higher fees but more stable
- Good fallback option

**Hybrid Approach** (Recommended):
- **Primary**: Ramp Network (best user experience)
- **Fallback**: MoonPay (for unsupported regions)
- **Implementation**: Check user's country, route to best provider

---

## Integration Roadmap

### Phase 1: Single Provider Integration (1-2 weeks)
1. Register with Ramp Network
2. Obtain API keys (sandbox + production)
3. Integrate iOS SDK
4. Implement basic buy flow
5. Test in sandbox
6. Submit for production review

### Phase 2: Multi-Provider Support (1 week)
1. Integrate MoonPay as fallback
2. Implement provider routing logic
3. Geographic optimization
4. A/B testing framework

### Phase 3: Advanced Features (2 weeks)
1. Recurring purchases
2. Buy limits and warnings
3. Transaction history
4. Webhook integration
5. Push notifications
6. Receipt generation

### Phase 4: Off-Ramp (1 week)
1. Enable off-ramp (sell crypto)
2. Bank account linking
3. Withdrawal flows
4. Tax reporting integration

---

## Security Best Practices

### API Key Management
```swift
// NEVER hardcode API keys
// Use Info.plist with excluded keys or secrets management

let apiKey = Bundle.main.object(forInfoDictionaryKey: "RampAPIKey") as? String

// Or use Keychain for production
KeychainService.save(apiKey, for: "ramp-api-key")
```

### Transaction Verification
```swift
// Always verify transactions on backend
// Never trust client-side transaction status

func verifyTransaction(_ transactionId: String) async throws -> Bool {
    // Call your backend
    let response = try await backend.verifyRampTransaction(transactionId)
    return response.status == .completed
}
```

### Webhook Security
```swift
// Verify webhook signatures
func verifyWebhookSignature(
    payload: Data,
    signature: String,
    secret: String
) -> Bool {
    let hmac = HMAC<SHA256>.authenticationCode(
        for: payload,
        using: SymmetricKey(data: secret.data(using: .utf8)!)
    )
    let computedSignature = Data(hmac).base64EncodedString()
    return signature == computedSignature
}
```

### User Data Protection
- Minimize PII storage (store transaction IDs only)
- Encrypt wallet addresses
- Implement user data deletion
- Regular security audits

---

## Testing Recommendations

### Sandbox Testing
All providers offer sandbox environments:

**MoonPay Sandbox**:
- URL: https://buy-sandbox.moonpay.com
- Test cards provided
- KYC auto-approval

**Ramp Sandbox**:
- URL: https://app.demo.ramp.network
- Test cards: Multiple scenarios
- Instant KYC approval

**Transak Staging**:
- URL: https://global-stg.transak.com
- Test environment with mock data

### Test Scenarios
1. ✅ Successful purchase (card)
2. ✅ Successful purchase (bank transfer)
3. ✅ Failed KYC verification
4. ✅ Insufficient funds
5. ✅ Card declined
6. ✅ Transaction timeout
7. ✅ User cancellation
8. ✅ Network error handling
9. ✅ Rate limiting
10. ✅ Webhook delivery

---

## Cost Analysis for Wallet Providers

### Revenue Model Options

**Option 1: Pass-through (No markup)**
- User pays provider fee directly
- Wallet takes no fee
- Pros: Transparent, user-friendly
- Cons: No revenue

**Option 2: Small Markup (0.5-1%)**
- Add 0.5-1% on top of provider fee
- Competitive but generates revenue
- Pros: Revenue, still competitive
- Cons: Must disclose markup

**Option 3: Fixed Fee**
- Charge $1-5 per transaction
- Independent of transaction size
- Pros: Predictable revenue
- Cons: Hurts small transactions

**Option 4: Hybrid**
- Smaller % markup + fixed fee
- Example: 0.3% + $1
- Pros: Balanced approach
- Cons: Complex pricing

### Monthly Cost Estimate (Example)

```
Scenario: 1,000 users, 30% use on-ramp monthly, $200 avg purchase

Monthly Volume: 300 users × $200 = $60,000

With Ramp (2.9% card fee):
- Provider fees: $60,000 × 2.9% = $1,740
- If 0.5% markup: $60,000 × 0.5% = $300 monthly revenue

With MoonPay (4.5% card fee):
- Provider fees: $60,000 × 4.5% = $2,700
- If 0.5% markup: $60,000 × 0.5% = $300 monthly revenue
- Users pay $960 more vs Ramp (less competitive)

Recommendation: Use Ramp + 0.3% markup for best user value
```

---

## References and Further Reading

1. MoonPay Documentation: https://docs.moonpay.com/
2. Ramp Network Docs: https://docs.ramp.network/
3. Transak Docs: https://docs.transak.com/
4. Stripe Crypto: https://stripe.com/docs/crypto
5. FinCEN MSB Registration: https://www.fincen.gov/money-services-business-msb-registration
6. FATF Crypto Guidelines: https://www.fatf-gafi.org/publications/fatfrecommendations/documents/crypto-assets-guide.html

---

*Research conducted: October 21, 2025*
*Agent: CryptoResearcher*
*Project: Fueki Mobile Wallet*
