import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Code Types

enum DetectedCodeType {
    case qr
    case barcode
}

// MARK: - Scan Mode

enum ScanMode {
    case qrCode      // Solo QR
    case barcode     // Solo códigos de barras
    case all         // Ambos

    var metadataTypes: [AVMetadataObject.ObjectType] {
        switch self {
        case .qrCode:
            return [.qr]
        case .barcode:
            return [.ean8, .ean13, .code128, .code39, .code93, .interleaved2of5, .upce]
        case .all:
            return [.qr, .ean8, .ean13, .code128, .code39, .code93, .interleaved2of5, .upce]
        }
    }
}

// MARK: - Scanner View

struct ScannerView: UIViewControllerRepresentable {
    let scanMode: ScanMode
    let onCodeDetected: (String, DetectedCodeType) -> Void
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.scanMode = scanMode
        controller.onCodeDetected = onCodeDetected
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: - Scanner View Controller

class ScannerViewController: UIViewController {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var scanMode: ScanMode = .all
    var onCodeDetected: ((String, DetectedCodeType) -> Void)?
    var onDismiss: (() -> Void)?

    private var hasDetected = false
    private var overlayView: ScannerOverlayView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
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
        hasDetected = false

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

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showPermissionDenied()
                    }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            showNoCameraError()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = scanMode.metadataTypes
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            // Set correct orientation for iPad
            updateVideoOrientation()

            // Agregar overlay
            setupOverlay()

            self.captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

        } catch {
            showCameraError(error)
        }
    }

    private func setupOverlay() {
        let overlay = ScannerOverlayView(frame: view.bounds, scanMode: scanMode)
        overlay.onClose = { [weak self] in
            self?.onDismiss?()
        }
        view.addSubview(overlay)
        self.overlayView = overlay
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        overlayView?.frame = view.bounds
        overlayView?.setNeedsDisplay()
        // Update orientation when layout changes (rotation)
        updateVideoOrientation()
    }

    private func showPermissionDenied() {
        let alert = UIAlertController(
            title: "Permiso de cámara requerido",
            message: "Necesitamos acceso a la cámara para escanear códigos. Ve a Configuración para habilitarlo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Configuración", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { [weak self] _ in
            self?.onDismiss?()
        })
        present(alert, animated: true)
    }

    private func showNoCameraError() {
        let alert = UIAlertController(
            title: "Cámara no disponible",
            message: "No se encontró una cámara en este dispositivo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onDismiss?()
        })
        present(alert, animated: true)
    }

    private func showCameraError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error de cámara",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onDismiss?()
        })
        present(alert, animated: true)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDetected,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasDetected = true

        // Feedback háptico
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        // Determinar tipo de código
        let codeType: DetectedCodeType = metadataObject.type == .qr ? .qr : .barcode

        // Highlight visual
        overlayView?.showDetection()

        // Pequeño delay para mostrar el feedback visual
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onCodeDetected?(stringValue, codeType)
        }
    }
}

// MARK: - Scanner Overlay View

class ScannerOverlayView: UIView {
    private let scanMode: ScanMode
    var onClose: (() -> Void)?

    private let scanAreaSize: CGFloat = 250
    private var scanAreaRect: CGRect = .zero
    private var detectionLayer: CAShapeLayer?

    init(frame: CGRect, scanMode: ScanMode) {
        self.scanMode = scanMode
        super.init(frame: frame)
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Botón cerrar
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)

        // Etiqueta de instrucciones
        let instructionLabel = UILabel()
        instructionLabel.text = scanMode == .qrCode ?
            "Apunta al código QR" :
            scanMode == .barcode ?
            "Apunta al código de barras" :
            "Apunta al código"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            instructionLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
            instructionLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    @objc private func closeTapped() {
        onClose?()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Calcular área de escaneo
        let centerX = rect.width / 2
        let centerY = rect.height / 2 - 50
        scanAreaRect = CGRect(
            x: centerX - scanAreaSize / 2,
            y: centerY - scanAreaSize / 2,
            width: scanAreaSize,
            height: scanAreaSize
        )

        // Fondo oscuro con recorte
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)

        // Recortar área de escaneo
        context.setBlendMode(.clear)
        context.fillEllipse(in: scanAreaRect.insetBy(dx: -10, dy: -10))
        context.fill(scanAreaRect)

        context.setBlendMode(.normal)

        // Dibujar esquinas
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        let cornerColor = UIColor(red: 13/255, green: 71/255, blue: 161/255, alpha: 1).cgColor

        context.setStrokeColor(cornerColor)
        context.setLineWidth(cornerWidth)
        context.setLineCap(.round)

        // Esquina superior izquierda
        context.move(to: CGPoint(x: scanAreaRect.minX, y: scanAreaRect.minY + cornerLength))
        context.addLine(to: CGPoint(x: scanAreaRect.minX, y: scanAreaRect.minY))
        context.addLine(to: CGPoint(x: scanAreaRect.minX + cornerLength, y: scanAreaRect.minY))

        // Esquina superior derecha
        context.move(to: CGPoint(x: scanAreaRect.maxX - cornerLength, y: scanAreaRect.minY))
        context.addLine(to: CGPoint(x: scanAreaRect.maxX, y: scanAreaRect.minY))
        context.addLine(to: CGPoint(x: scanAreaRect.maxX, y: scanAreaRect.minY + cornerLength))

        // Esquina inferior derecha
        context.move(to: CGPoint(x: scanAreaRect.maxX, y: scanAreaRect.maxY - cornerLength))
        context.addLine(to: CGPoint(x: scanAreaRect.maxX, y: scanAreaRect.maxY))
        context.addLine(to: CGPoint(x: scanAreaRect.maxX - cornerLength, y: scanAreaRect.maxY))

        // Esquina inferior izquierda
        context.move(to: CGPoint(x: scanAreaRect.minX + cornerLength, y: scanAreaRect.maxY))
        context.addLine(to: CGPoint(x: scanAreaRect.minX, y: scanAreaRect.maxY))
        context.addLine(to: CGPoint(x: scanAreaRect.minX, y: scanAreaRect.maxY - cornerLength))

        context.strokePath()
    }

    func showDetection() {
        // Flash verde al detectar
        let flashLayer = CAShapeLayer()
        flashLayer.path = UIBezierPath(roundedRect: scanAreaRect, cornerRadius: 8).cgPath
        flashLayer.fillColor = UIColor.green.withAlphaComponent(0.3).cgColor
        flashLayer.strokeColor = UIColor.green.cgColor
        flashLayer.lineWidth = 3
        layer.addSublayer(flashLayer)

        // Animación de fade out
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = 0.3
        flashLayer.add(animation, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            flashLayer.removeFromSuperlayer()
        }
    }
}

// MARK: - Scanner Sheet View (SwiftUI wrapper)

struct ScannerSheetView: View {
    @Environment(\.dismiss) var dismiss

    let scanMode: ScanMode
    let title: String
    let onCodeDetected: (String, DetectedCodeType) -> Void

    var body: some View {
        ZStack {
            ScannerView(
                scanMode: scanMode,
                onCodeDetected: { code, type in
                    onCodeDetected(code, type)
                    dismiss()
                },
                onDismiss: {
                    dismiss()
                }
            )
            .ignoresSafeArea()
        }
    }
}
