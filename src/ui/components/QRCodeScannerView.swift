//
//  QRCodeScannerView.swift
//  Fueki Wallet
//
//  QR code scanner with camera access
//

import SwiftUI
import AVFoundation

struct QRCodeScannerView: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var scanner = QRCodeScanner()

    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    Spacer()

                    // Scanning Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 280, height: 280)

                        // Corner brackets
                        VStack {
                            HStack {
                                ScannerCorner()
                                Spacer()
                                ScannerCorner()
                                    .rotationEffect(.degrees(90))
                            }
                            Spacer()
                            HStack {
                                ScannerCorner()
                                    .rotationEffect(.degrees(270))
                                Spacer()
                                ScannerCorner()
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .frame(width: 280, height: 280)
                    }

                    Spacer()

                    // Instructions
                    VStack(spacing: 16) {
                        Text("Scan QR Code")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Position the QR code within the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        scanner.toggleTorch()
                    }) {
                        Image(systemName: scanner.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedCode) { _, newValue in
                if !newValue.isEmpty {
                    scannedCode = newValue
                    dismiss()
                }
            }
            .alert("Camera Access Required", isPresented: $scanner.showPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Please allow camera access in Settings to scan QR codes")
            }
        }
    }
}

// MARK: - Scanner Corner
struct ScannerCorner: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 4, height: 30)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 30, height: 4)

                Spacer()
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - QR Code Scanner
class QRCodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode = ""
    @Published var showPermissionAlert = false
    @Published var isTorchOn = false

    let session = AVCaptureSession()
    private var output = AVCaptureMetadataOutput()

    override init() {
        super.init()
        checkPermissions()
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupScanner()
                    } else {
                        self?.showPermissionAlert = true
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
        }
    }

    private func setupScanner() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }
        } catch {
            print("Failed to setup scanner: \(error.localizedDescription)")
        }
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopScanning() {
        session.stopRunning()
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = device.isTorchActive ? .off : .on
            isTorchOn = device.isTorchActive
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle torch: \(error.localizedDescription)")
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue,
              scannedCode.isEmpty else { return }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        scannedCode = code
    }
}

#Preview {
    QRCodeScannerView(scannedCode: .constant(""))
}
