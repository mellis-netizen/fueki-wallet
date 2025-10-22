import SwiftUI
import AVFoundation

struct QRCodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = QRCodeScannerViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                QRCodeCameraView(viewModel: viewModel)
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    Spacer()

                    // Scan Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        // Corner Accents
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
                        .frame(width: 250, height: 250)
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

                        // Torch Button
                        Button(action: { viewModel.toggleTorch() }) {
                            Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(.bottom, 60)
                }

                // Scanned Indicator
                if viewModel.isScanned {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                            )
                    }
                    .transition(.scale)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: viewModel.scannedCode) { newValue in
                if let code = newValue {
                    onScan(code)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scanner Corner
struct ScannerCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 30, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 30))
        }
        .stroke(Color.blue, lineWidth: 4)
        .frame(width: 30, height: 30)
    }
}

// MARK: - QR Code Camera View
struct QRCodeCameraView: UIViewRepresentable {
    @ObservedObject var viewModel: QRCodeScannerViewModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        guard let captureSession = viewModel.setupCaptureSession() else {
            return view
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - View Model
class QRCodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanned = false
    @Published var isTorchOn = false

    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?

    func setupCaptureSession() -> AVCaptureSession? {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return nil
        }

        self.captureDevice = videoCaptureDevice

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return nil
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return nil
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return nil
        }

        self.captureSession = session
        return session
    }

    func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            isTorchOn = device.torchMode == .on
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
}

// MARK: - Metadata Output Delegate
extension QRCodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {

            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

            withAnimation {
                isScanned = true
            }

            scannedCode = stringValue

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.captureSession?.stopRunning()
            }
        }
    }
}

// MARK: - Preview
struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView { _ in }
    }
}
