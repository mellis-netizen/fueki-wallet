# QR Code Implementation Documentation

## Overview

Complete QR code scanning and generation system for Fueki Mobile Wallet supporting Bitcoin (BIP-21) and Ethereum (EIP-681) payment URIs.

## Components

### 1. QRScannerViewController
Production-ready QR scanner using AVFoundation with:
- Real-time camera scanning
- Camera permission handling
- Flash light toggle
- Gallery image scanning (QR from photos)
- Visual feedback (vibration, sound)
- Scan area overlay with corner indicators
- Duplicate scan prevention
- Support for BIP-21, EIP-681, and plain addresses

**Usage:**
```swift
let scanner = QRScannerViewController()
scanner.delegate = self
scanner.allowedFormats = [.bitcoin, .ethereum, .generic]
scanner.vibrationEnabled = true
present(scanner, animated: true)

// Delegate methods
func qrScanner(_ scanner: QRScannerViewController, didScanCode code: String) {
    // Handle plain address
}

func qrScanner(_ scanner: QRScannerViewController, didScanPaymentURI uri: PaymentURI) {
    // Handle payment URI with amount, label, etc.
}
```

### 2. QRGeneratorView
QR code generator using CoreImage with:
- High-quality QR generation
- Error correction level control
- Logo overlay support
- Address formatting
- Copy to clipboard
- Share functionality
- Payment URI support

**Usage:**
```swift
let generator = QRGeneratorView()
generator.correctionLevel = .high
generator.qrSize = 250
generator.enableLogo = true

// Generate simple address QR
generator.generateQRCode(for: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", logo: walletLogo)

// Generate payment request QR
let paymentURI = try PaymentQRBuilder
    .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
    .amount("0.5")
    .label("Coffee")
    .build()
generator.generatePaymentQRCode(for: paymentURI, logo: walletLogo)
```

### 3. PaymentURIParser
Parser supporting BIP-21 and EIP-681 standards:

**BIP-21 (Bitcoin):**
```
bitcoin:<address>[?amount=<amount>][&label=<label>][&message=<message>]
```

**EIP-681 (Ethereum):**
```
ethereum:<address>[@<chainId>][?value=<value>][&gas=<gas>][&data=<data>]
```

**Usage:**
```swift
// Parse any format
if let paymentURI = PaymentURIParser.parse(scannedCode) {
    print("Address: \(paymentURI.address)")
    print("Amount: \(paymentURI.amount ?? "none")")
    print("Currency: \(paymentURI.currency)")
}
```

### 4. AddressValidator
Comprehensive address validation:

**Bitcoin Support:**
- Legacy P2PKH (starts with 1)
- Script P2SH (starts with 3)
- SegWit Bech32 (starts with bc1)
- Testnet addresses (m, n, 2, tb1)

**Ethereum Support:**
- Standard 0x addresses (40 hex characters)
- Checksum validation

**Usage:**
```swift
if AddressValidator.isValidBitcoinAddress(address) {
    // Valid Bitcoin address
}

if AddressValidator.isValidEthereumAddress(address) {
    // Valid Ethereum address
}
```

### 5. PaymentQRBuilder
Fluent builder for creating payment URIs:

**Bitcoin:**
```swift
let uri = try PaymentQRBuilder
    .bitcoin(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
    .amount("0.5")
    .label("Coffee Shop")
    .message("Medium Latte")
    .build()
```

**Ethereum:**
```swift
let uri = try PaymentQRBuilder
    .ethereum(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
    .amount("1.5")
    .chainId(1)
    .gas("21000")
    .gasPrice("50000000000")
    .build()
```

## Features

### Camera Permissions
- Automatic permission request
- Settings redirect for denied access
- User-friendly error messages

### Scanner Features
- Real-time detection
- Visual scan area with animated corners
- Flash light control
- Gallery import for QR images
- Duplicate scan prevention (configurable interval)
- Haptic feedback on successful scan

### Generator Features
- Multiple error correction levels (L, M, Q, H)
- Logo overlay (centered, with padding)
- Address truncation for display
- Copy to clipboard with visual feedback
- Share functionality
- Amount display for payment requests

### Security
- Address validation before QR generation
- Amount format validation
- Safe URI parsing (prevents injection)
- URL encoding for parameters

## Error Handling

```swift
enum QRScannerError: Error {
    case cameraNotAvailable
    case cameraAccessDenied
    case invalidQRCode
    case unsupportedFormat
    case captureSessionFailed
}

enum PaymentQRError: Error {
    case invalidAddress
    case invalidAmount
    case invalidScheme
    case missingRequiredField
}
```

## Testing

Comprehensive test suite covering:
- Address validation (Bitcoin & Ethereum)
- BIP-21 parsing
- EIP-681 parsing
- Plain address parsing
- URI builder validation
- Round-trip parsing (build → string → parse)
- Error cases

Run tests:
```bash
xcodebuild test -scheme FuekiWallet -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Integration Example

```swift
class WalletViewController: UIViewController {

    @IBAction func scanQRCode() {
        let scanner = QRScannerViewController()
        scanner.delegate = self
        present(scanner, animated: true)
    }

    @IBAction func showReceiveQR() {
        let generator = QRGeneratorView()
        generator.frame = view.bounds
        view.addSubview(generator)

        // Get current wallet address
        let address = wallet.getCurrentAddress()
        generator.generateQRCode(for: address, logo: UIImage(named: "wallet-logo"))

        generator.onCopyTapped = { address in
            showToast("Address copied to clipboard")
        }

        generator.onShareTapped = { image, address in
            let activityVC = UIActivityViewController(
                activityItems: [image, address],
                applicationActivities: nil
            )
            present(activityVC, animated: true)
        }
    }
}

extension WalletViewController: QRScannerDelegate {
    func qrScanner(_ scanner: QRScannerViewController, didScanPaymentURI uri: PaymentURI) {
        scanner.dismiss(animated: true)

        // Pre-fill send transaction
        sendViewController.setRecipient(uri.address)
        if let amount = uri.amount {
            sendViewController.setAmount(amount)
        }
        if let message = uri.message {
            sendViewController.setNote(message)
        }

        navigationController?.pushViewController(sendViewController, animated: true)
    }

    func qrScanner(_ scanner: QRScannerViewController, didScanCode code: String) {
        scanner.dismiss(animated: true)
        sendViewController.setRecipient(code)
        navigationController?.pushViewController(sendViewController, animated: true)
    }

    func qrScannerDidCancel(_ scanner: QRScannerViewController) {
        scanner.dismiss(animated: true)
    }

    func qrScanner(_ scanner: QRScannerViewController, didFailWithError error: QRScannerError) {
        showError(error.localizedDescription)
    }
}
```

## Performance Considerations

- QR generation is performed on main thread (CoreImage is efficient)
- Camera session runs on background thread
- Image detection from gallery uses high-accuracy mode
- Scan interval prevents duplicate processing
- Memory-efficient image scaling

## Accessibility

- VoiceOver support for buttons
- Dynamic type support for labels
- High contrast mode compatible
- Haptic feedback for visual impairment

## Future Enhancements

- [ ] Support for additional cryptocurrencies
- [ ] Animated QR codes for large data
- [ ] NFC payment integration
- [ ] Lightning Network invoices (BOLT-11)
- [ ] Contact name integration
- [ ] Transaction history QR export

## References

- [BIP-21: URI Scheme](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki)
- [EIP-681: URL Format for Transaction Requests](https://eips.ethereum.org/EIPS/eip-681)
- [Apple AVFoundation Documentation](https://developer.apple.com/av-foundation/)
- [Core Image Filter Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
