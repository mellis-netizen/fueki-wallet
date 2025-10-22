//
//  QRScannerViewController.swift
//  FuekiWallet
//
//  Production-ready QR code scanner with AVFoundation
//  Supports BIP-21 (Bitcoin), EIP-681 (Ethereum), and generic address scanning
//

import UIKit
import AVFoundation

protocol QRScannerDelegate: AnyObject {
    func qrScanner(_ scanner: QRScannerViewController, didScanCode code: String)
    func qrScanner(_ scanner: QRScannerViewController, didScanPaymentURI uri: PaymentURI)
    func qrScannerDidCancel(_ scanner: QRScannerViewController)
    func qrScanner(_ scanner: QRScannerViewController, didFailWithError error: QRScannerError)
}

enum QRScannerError: Error, LocalizedError {
    case cameraNotAvailable
    case cameraAccessDenied
    case invalidQRCode
    case unsupportedFormat
    case captureSessionFailed

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .cameraAccessDenied:
            return "Camera access is denied. Please enable it in Settings"
        case .invalidQRCode:
            return "Invalid QR code format"
        case .unsupportedFormat:
            return "Unsupported payment URI format"
        case .captureSessionFailed:
            return "Failed to initialize camera session"
        }
    }
}

class QRScannerViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanningEnabled = true
    private var lastScannedCode: String?
    private var lastScannedTime: Date?

    // UI Components
    private let scannerView = UIView()
    private let overlayView = UIView()
    private let scanAreaView = UIView()
    private let instructionLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let galleryButton = UIButton(type: .system)

    // Scanning area
    private let scanAreaSize: CGFloat = 250
    private let cornerLength: CGFloat = 30
    private let cornerWidth: CGFloat = 4

    // Configuration
    var allowedFormats: [SupportedQRFormat] = [.bitcoin, .ethereum, .generic]
    var scanInterval: TimeInterval = 1.0 // Prevent duplicate scans
    var vibrationEnabled = true
    var soundEnabled = true

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCameraPermissions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = scannerView.bounds
        updateOverlay()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Scanner view
        scannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scannerView)

        // Overlay with scanning area cutout
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        // Scan area border
        scanAreaView.backgroundColor = .clear
        scanAreaView.layer.borderColor = UIColor.white.cgColor
        scanAreaView.layer.borderWidth = 2
        scanAreaView.layer.cornerRadius = 12
        scanAreaView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanAreaView)

        // Corner indicators
        addCornerIndicators(to: scanAreaView)

        // Instruction label
        instructionLabel.text = "Align QR code within frame"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        // Close button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        // Flash button
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 20
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashButton)

        // Gallery button
        galleryButton.setImage(UIImage(systemName: "photo"), for: .normal)
        galleryButton.tintColor = .white
        galleryButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        galleryButton.layer.cornerRadius = 20
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(galleryButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scanner view
            scannerView.topAnchor.constraint(equalTo: view.topAnchor),
            scannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Overlay
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Scan area
            scanAreaView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanAreaView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanAreaView.widthAnchor.constraint(equalToConstant: scanAreaSize),
            scanAreaView.heightAnchor.constraint(equalToConstant: scanAreaSize),

            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: scanAreaView.bottomAnchor, constant: 24),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Flash button
            flashButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            flashButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 60),
            flashButton.heightAnchor.constraint(equalToConstant: 60),

            // Gallery button
            galleryButton.centerYAnchor.constraint(equalTo: flashButton.centerYAnchor),
            galleryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            galleryButton.widthAnchor.constraint(equalToConstant: 50),
            galleryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func addCornerIndicators(to view: UIView) {
        let corners: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)),         // Top-left
            (CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)),         // Top-right
            (CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0)),         // Bottom-left
            (CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0))          // Bottom-right
        ]

        for (position, direction) in corners {
            let corner = createCornerView(position: position, direction: direction)
            view.addSubview(corner)
        }
    }

    private func createCornerView(position: CGPoint, direction: CGPoint) -> UIView {
        let corner = UIView()
        corner.backgroundColor = .systemBlue
        corner.translatesAutoresizingMaskIntoConstraints = false

        let horizontal = UIView()
        horizontal.backgroundColor = .systemBlue
        horizontal.translatesAutoresizingMaskIntoConstraints = false
        corner.addSubview(horizontal)

        let vertical = UIView()
        vertical.backgroundColor = .systemBlue
        vertical.translatesAutoresizingMaskIntoConstraints = false
        corner.addSubview(vertical)

        NSLayoutConstraint.activate([
            horizontal.widthAnchor.constraint(equalToConstant: cornerLength),
            horizontal.heightAnchor.constraint(equalToConstant: cornerWidth),
            vertical.widthAnchor.constraint(equalToConstant: cornerWidth),
            vertical.heightAnchor.constraint(equalToConstant: cornerLength)
        ])

        // Position based on corner
        if position.x == 0 {
            horizontal.leadingAnchor.constraint(equalTo: corner.leadingAnchor).isActive = true
        } else {
            horizontal.trailingAnchor.constraint(equalTo: corner.trailingAnchor).isActive = true
        }

        if position.y == 0 {
            horizontal.topAnchor.constraint(equalTo: corner.topAnchor).isActive = true
            vertical.topAnchor.constraint(equalTo: corner.topAnchor).isActive = true
        } else {
            horizontal.bottomAnchor.constraint(equalTo: corner.bottomAnchor).isActive = true
            vertical.bottomAnchor.constraint(equalTo: corner.bottomAnchor).isActive = true
        }

        if position.x == 0 {
            vertical.leadingAnchor.constraint(equalTo: corner.leadingAnchor).isActive = true
        } else {
            vertical.trailingAnchor.constraint(equalTo: corner.trailingAnchor).isActive = true
        }

        return corner
    }

    private func updateOverlay() {
        let path = UIBezierPath(rect: overlayView.bounds)
        let scanAreaRect = CGRect(
            x: (view.bounds.width - scanAreaSize) / 2,
            y: (view.bounds.height - scanAreaSize) / 2,
            width: scanAreaSize,
            height: scanAreaSize
        )
        let scanAreaPath = UIBezierPath(roundedRect: scanAreaRect, cornerRadius: 12)
        path.append(scanAreaPath)
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
    }

    // MARK: - Camera Setup

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.handleCameraAccessDenied()
                    }
                }
            }
        case .denied, .restricted:
            handleCameraAccessDenied()
        @unknown default:
            handleCameraAccessDenied()
        }
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            delegate?.qrScanner(self, didFailWithError: .cameraNotAvailable)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()

            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                delegate?.qrScanner(self, didFailWithError: .captureSessionFailed)
                return
            }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = [.qr]
            } else {
                delegate?.qrScanner(self, didFailWithError: .captureSessionFailed)
                return
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = scannerView.bounds
            scannerView.layer.addSublayer(preview)

            self.captureSession = session
            self.previewLayer = preview

            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

        } catch {
            delegate?.qrScanner(self, didFailWithError: .captureSessionFailed)
        }
    }

    private func handleCameraAccessDenied() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please enable camera access in Settings to scan QR codes",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.qrScannerDidCancel(self)
        })

        present(alert, animated: true)
    }

    // MARK: - Scanning Control

    private func startScanning() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        scanningEnabled = true
    }

    private func stopScanning() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
        scanningEnabled = false
    }

    private func handleScannedCode(_ code: String) {
        // Prevent duplicate scans
        if let lastCode = lastScannedCode,
           let lastTime = lastScannedTime,
           code == lastCode,
           Date().timeIntervalSince(lastTime) < scanInterval {
            return
        }

        lastScannedCode = code
        lastScannedTime = Date()

        // Provide feedback
        if vibrationEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        // Parse the code
        if let paymentURI = PaymentURIParser.parse(code) {
            delegate?.qrScanner(self, didScanPaymentURI: paymentURI)
        } else {
            delegate?.qrScanner(self, didScanCode: code)
        }
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.qrScannerDidCancel(self)
    }

    @objc private func flashButtonTapped() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .off {
                device.torchMode = .on
                flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            } else {
                device.torchMode = .off
                flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            }

            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }

    @objc private func galleryButtonTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        guard scanningEnabled,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let code = readableObject.stringValue else {
            return
        }

        handleScannedCode(code)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension QRScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage,
              let ciImage = CIImage(image: image) else {
            return
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]

        if let code = features?.first?.messageString {
            handleScannedCode(code)
        } else {
            delegate?.qrScanner(self, didFailWithError: .invalidQRCode)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - Supporting Types

enum SupportedQRFormat {
    case bitcoin    // BIP-21
    case ethereum   // EIP-681
    case generic    // Plain address
}
