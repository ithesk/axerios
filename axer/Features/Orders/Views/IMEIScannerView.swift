import SwiftUI
import AVFoundation
import Vision
import AudioToolbox

struct IMEIScannerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var scannedIMEI: String

    @State private var scanMode: IMEIScanMode = .barcode
    @State private var showOCRHint = false
    @State private var detectedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    enum IMEIScanMode {
        case barcode
        case ocr
    }

    var body: some View {
        ZStack {
            // Scanner base
            if scanMode == .barcode {
                ScannerView(
                    scanMode: .barcode,
                    onCodeDetected: handleBarcodeDetection,
                    onDismiss: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                OCRScannerView(
                    onTextDetected: handleOCRDetection,
                    onDismiss: { dismiss() }
                )
                .ignoresSafeArea()
            }

            // Overlay UI
            VStack {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(L10n.IMEIScanner.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Instructions
                VStack(spacing: 16) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text(L10n.IMEIScanner.processing)
                            .foregroundColor(.white)
                    } else {
                        Text(scanMode == .barcode ?
                             L10n.IMEIScanner.barcodeHint :
                             L10n.IMEIScanner.ocrHint)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        if scanMode == .barcode {
                            Text(L10n.IMEIScanner.imeiLocation)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }

                    // Mode switch button
                    if showOCRHint && scanMode == .barcode {
                        Button {
                            withAnimation {
                                scanMode = .ocr
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.viewfinder")
                                Text(L10n.IMEIScanner.switchOcr)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                        }
                    }

                    if scanMode == .ocr {
                        Button {
                            withAnimation {
                                scanMode = .barcode
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "barcode.viewfinder")
                                Text(L10n.IMEIScanner.switchBarcode)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Mostrar hint de OCR después de 5 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if scanMode == .barcode {
                    withAnimation {
                        showOCRHint = true
                    }
                }
            }
        }
    }

    private func handleBarcodeDetection(_ code: String, _ type: DetectedCodeType) {
        // Limpiar código (solo números)
        let cleaned = code.filter { $0.isNumber }

        // Validar formato IMEI (15 dígitos)
        if cleaned.count == 15 {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedIMEI = cleaned
            dismiss()
        } else if cleaned.count >= 14 && cleaned.count <= 16 {
            // IMEI cercano, podría ser válido
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedIMEI = cleaned
            dismiss()
        } else {
            errorMessage = L10n.IMEIScanner.invalidFormat(cleaned.count)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                errorMessage = nil
            }
        }
    }

    private func handleOCRDetection(_ text: String) {
        // Buscar secuencias de 15 dígitos en el texto
        let pattern = "\\d{15}"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let imei = String(text[Range(match.range, in: text)!])
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedIMEI = imei
            dismiss()
        }
    }
}

// MARK: - OCR Scanner View

struct OCRScannerView: UIViewControllerRepresentable {
    let onTextDetected: (String) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> OCRScannerViewController {
        let controller = OCRScannerViewController()
        controller.onTextDetected = onTextDetected
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: OCRScannerViewController, context: Context) {}
}

class OCRScannerViewController: UIViewController {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onTextDetected: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private var isProcessing = false
    private let videoOutput = AVCaptureVideoDataOutput()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    // MARK: - Video Orientation (iPad fix)

    private func updateVideoOrientation() {
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported else { return }

        let orientation: AVCaptureVideoOrientation

        if let windowScene = view.window?.windowScene {
            switch windowScene.interfaceOrientation {
            case .portrait:
                orientation = .portrait
            case .portraitUpsideDown:
                orientation = .portraitUpsideDown
            case .landscapeLeft:
                orientation = .landscapeLeft
            case .landscapeRight:
                orientation = .landscapeRight
            @unknown default:
                orientation = .portrait
            }
        } else {
            orientation = .portrait
        }

        connection.videoOrientation = orientation
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ocr.queue"))

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            // Set correct orientation for iPad
            updateVideoOrientation()

            // Add scan area overlay
            addScanAreaOverlay()

            self.captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

        } catch {
            print("Error setting up OCR camera: \(error)")
        }
    }

    private func addScanAreaOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Cut out scan area
        let scanAreaWidth: CGFloat = view.bounds.width - 60
        let scanAreaHeight: CGFloat = 100
        let scanAreaY = view.bounds.height / 2 - 100

        let path = UIBezierPath(rect: overlayView.bounds)
        let scanRect = CGRect(
            x: 30,
            y: scanAreaY,
            width: scanAreaWidth,
            height: scanAreaHeight
        )
        path.append(UIBezierPath(roundedRect: scanRect, cornerRadius: 12))
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer

        view.addSubview(overlayView)

        // Add border around scan area
        let borderView = UIView(frame: scanRect)
        borderView.layer.borderColor = UIColor(red: 13/255, green: 71/255, blue: 161/255, alpha: 1).cgColor
        borderView.layer.borderWidth = 3
        borderView.layer.cornerRadius = 12
        borderView.backgroundColor = .clear
        view.addSubview(borderView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        // Update orientation when layout changes (rotation)
        updateVideoOrientation()
    }
}

extension OCRScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true

        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { self?.isProcessing = false }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            // Combine all detected text
            let allText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")

            // Look for 15-digit sequences
            let pattern = "\\d{15}"
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: allText, range: NSRange(allText.startIndex..., in: allText)) != nil {
                DispatchQueue.main.async {
                    self?.onTextDetected?(allText)
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("OCR Error: \(error)")
            isProcessing = false
        }
    }
}
