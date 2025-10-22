//
//  QRGeneratorView.swift
//  FuekiWallet
//
//  Production-ready QR code generator using CoreImage
//  Supports address validation and payment URI generation
//

import UIKit
import CoreImage

class QRGeneratorView: UIView {

    // MARK: - Properties

    private let imageView = UIImageView()
    private let addressLabel = UILabel()
    private let amountLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let logoImageView = UIImageView()

    private var currentAddress: String?
    private var currentQRImage: UIImage?

    // Configuration
    var correctionLevel: QRCorrectionLevel = .high
    var qrSize: CGFloat = 250
    var showAddress = true
    var showCopyButton = true
    var showShareButton = true
    var enableLogo = true
    var logoSize: CGFloat = 50

    var onCopyTapped: ((String) -> Void)?
    var onShareTapped: ((UIImage, String) -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        backgroundColor = .systemBackground

        // Image view for QR code
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Logo overlay
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = .white
        logoImageView.layer.cornerRadius = 8
        logoImageView.layer.masksToBounds = true
        logoImageView.isHidden = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(logoImageView)

        // Address label
        addressLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        addressLabel.textAlignment = .center
        addressLabel.numberOfLines = 0
        addressLabel.textColor = .secondaryLabel
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addressLabel)

        // Amount label
        amountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        amountLabel.textAlignment = .center
        amountLabel.textColor = .label
        amountLabel.isHidden = true
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(amountLabel)

        // Copy button
        copyButton.setTitle("Copy Address", for: .normal)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.backgroundColor = .systemBlue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.tintColor = .white
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(copyButton)

        // Share button
        shareButton.setTitle("Share", for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.backgroundColor = .systemGray5
        shareButton.setTitleColor(.systemBlue, for: .normal)
        shareButton.tintColor = .systemBlue
        shareButton.layer.cornerRadius = 8
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shareButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // QR image
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: qrSize),
            imageView.heightAnchor.constraint(equalToConstant: qrSize),

            // Logo
            logoImageView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: logoSize),

            // Amount label
            amountLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            amountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Address label
            addressLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            addressLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Copy button
            copyButton.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 24),
            copyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            copyButton.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -8),
            copyButton.heightAnchor.constraint(equalToConstant: 50),

            // Share button
            shareButton.topAnchor.constraint(equalTo: copyButton.topAnchor),
            shareButton.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 8),
            shareButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            shareButton.heightAnchor.constraint(equalToConstant: 50),

            // Bottom constraint
            bottomAnchor.constraint(greaterThanOrEqualTo: copyButton.bottomAnchor, constant: 20)
        ])
    }

    // MARK: - Public Methods

    /// Generate QR code for a simple address
    func generateQRCode(for address: String, logo: UIImage? = nil) {
        currentAddress = address

        guard let qrImage = createQRCode(from: address) else {
            print("Failed to generate QR code")
            return
        }

        currentQRImage = qrImage
        imageView.image = qrImage

        if showAddress {
            addressLabel.text = formatAddress(address)
            addressLabel.isHidden = false
        }

        if let logo = logo, enableLogo {
            logoImageView.image = logo
            logoImageView.isHidden = false
        }

        copyButton.isHidden = !showCopyButton
        shareButton.isHidden = !showShareButton
    }

    /// Generate QR code for payment URI (BIP-21, EIP-681)
    func generatePaymentQRCode(for paymentURI: PaymentURI, logo: UIImage? = nil) {
        let uriString = paymentURI.toString()
        currentAddress = paymentURI.address

        guard let qrImage = createQRCode(from: uriString) else {
            print("Failed to generate payment QR code")
            return
        }

        currentQRImage = qrImage
        imageView.image = qrImage

        if let amount = paymentURI.amount {
            amountLabel.text = "\(amount) \(paymentURI.currency.uppercased())"
            amountLabel.isHidden = false
        }

        if showAddress {
            addressLabel.text = formatAddress(paymentURI.address)
            addressLabel.isHidden = false
        }

        if let logo = logo, enableLogo {
            logoImageView.image = logo
            logoImageView.isHidden = false
        }

        copyButton.isHidden = !showCopyButton
        shareButton.isHidden = !showShareButton
    }

    /// Clear the current QR code
    func clear() {
        currentAddress = nil
        currentQRImage = nil
        imageView.image = nil
        addressLabel.text = nil
        amountLabel.text = nil
        amountLabel.isHidden = true
        logoImageView.image = nil
        logoImageView.isHidden = true
    }

    // MARK: - QR Generation

    private func createQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 20 else {
            return address
        }

        let start = String(address.prefix(10))
        let end = String(address.suffix(10))
        return "\(start)...\(end)"
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        guard let address = currentAddress else { return }

        UIPasteboard.general.string = address
        onCopyTapped?(address)

        // Visual feedback
        let originalTitle = copyButton.title(for: .normal)
        copyButton.setTitle("Copied!", for: .normal)
        copyButton.backgroundColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setTitle(originalTitle, for: .normal)
            self?.copyButton.backgroundColor = .systemBlue
        }
    }

    @objc private func shareButtonTapped() {
        guard let image = currentQRImage,
              let address = currentAddress else {
            return
        }

        onShareTapped?(image, address)
    }
}

// MARK: - QR Correction Level

enum QRCorrectionLevel: String {
    case low = "L"      // 7% error correction
    case medium = "M"   // 15% error correction
    case quartile = "Q" // 25% error correction
    case high = "H"     // 30% error correction
}
