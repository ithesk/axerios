import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - Label Size

enum LabelSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"

    var displayName: String {
        switch self {
        case .small: return L10n.PrintLabel.sizeSmall
        case .medium: return L10n.PrintLabel.sizeMedium
        }
    }

    var shortName: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        }
    }

    // Dimensions in points (72 points = 1 inch)
    // 30mm = 1.18in = 85pt, 40mm = 1.57in = 113pt, 50mm = 1.97in = 142pt
    // Both labels are HORIZONTAL (width > height)
    var widthPoints: CGFloat {
        switch self {
        case .small: return 113   // 40mm
        case .medium: return 142  // 50mm
        }
    }

    var heightPoints: CGFloat {
        return 85  // 30mm for both
    }

    var qrSize: CGFloat {
        switch self {
        case .small: return 45
        case .medium: return 50
        }
    }
}

// MARK: - Device Type Letter

extension DeviceType {
    var labelLetter: String {
        switch self {
        case .iphone, .android: return "C"  // Cell
        case .tablet: return "T"
        case .watch: return "S"  // Smartwatch
        case .laptop: return "L"
        case .other: return "O"
        }
    }
}

// MARK: - Print Label View

struct PrintLabelView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore

    let order: Order

    @State private var selectedSize: LabelSize = .small
    @State private var copies: Int = 1
    @State private var isGeneratingPDF = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let trackingBaseURL = "https://axer-tracking.vercel.app/"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview
                previewSection

                // Size selector
                sizeSelector

                // Copies selector
                copiesSelector

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(20)
            .background(AxerColors.background)
            .navigationTitle(L10n.PrintLabel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
                }
            }
            .alert(L10n.Common.error, isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 12) {
            Text(L10n.PrintLabel.preview)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Label preview (scaled up for visibility)
            LabelPreview(
                order: order,
                size: selectedSize,
                workshopName: sessionStore.workshop?.name ?? "Taller",
                trackingURL: trackingURL
            )
            .frame(width: selectedSize.widthPoints * 2.5, height: selectedSize.heightPoints * 2.5)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Size Selector

    private var sizeSelector: some View {
        VStack(spacing: 12) {
            Text(L10n.PrintLabel.size)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach(LabelSize.allCases, id: \.self) { size in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSize = size
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(size.shortName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(selectedSize == size ? .white : AxerColors.primary)

                            Text(size.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(selectedSize == size ? .white.opacity(0.9) : AxerColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedSize == size ? AxerColors.primary : AxerColors.surfaceSecondary)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Copies Selector

    private var copiesSelector: some View {
        VStack(spacing: 12) {
            Text(L10n.PrintLabel.copies)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button {
                    if copies > 1 {
                        copies -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(copies > 1 ? AxerColors.primary : AxerColors.textTertiary)
                }
                .disabled(copies <= 1)

                Text("\(copies)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)
                    .frame(width: 60)

                Button {
                    if copies < 3 {
                        copies += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(copies < 3 ? AxerColors.primary : AxerColors.textTertiary)
                }
                .disabled(copies >= 3)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(AxerColors.surface)
        .cornerRadius(16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Print button
            Button {
                printLabel()
            } label: {
                HStack {
                    if isGeneratingPDF {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "printer.fill")
                    }
                    Text(L10n.PrintLabel.print)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AxerColors.primary)
                .cornerRadius(26)
            }
            .disabled(isGeneratingPDF)

            // Share PDF button
            Button {
                sharePDF()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.PrintLabel.sharePdf)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AxerColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AxerColors.primaryLight)
                .cornerRadius(26)
            }
            .disabled(isGeneratingPDF)
        }
    }

    // MARK: - Helpers

    private var trackingURL: String {
        if let token = order.publicToken {
            return "\(trackingBaseURL)\(token)"
        }
        return trackingBaseURL
    }

    // MARK: - Actions

    private func printLabel() {
        isGeneratingPDF = true

        Task {
            do {
                let pdfData = try generatePDF()
                await presentPrintController(pdfData: pdfData)
            } catch {
                errorMessage = "\(L10n.PrintLabel.errorGenerating): \(error.localizedDescription)"
                showError = true
            }

            isGeneratingPDF = false
        }
    }

    private func sharePDF() {
        isGeneratingPDF = true

        Task {
            do {
                let pdfData = try generatePDF()
                await sharePDFFile(pdfData: pdfData)
            } catch {
                errorMessage = "\(L10n.PrintLabel.errorGenerating): \(error.localizedDescription)"
                showError = true
            }

            isGeneratingPDF = false
        }
    }

    private func generatePDF() throws -> Data {
        let renderer = LabelPDFRenderer(
            order: order,
            size: selectedSize,
            copies: copies,
            workshopName: sessionStore.workshop?.name ?? "Taller",
            trackingURL: trackingURL
        )
        return try renderer.generatePDF()
    }

    @MainActor
    private func presentPrintController(pdfData: Data) {
        let printController = UIPrintInteractionController.shared

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Label-\(order.orderNumber)"
        printInfo.outputType = .general

        printController.printInfo = printInfo
        printController.printingItem = pdfData

        printController.present(animated: true) { _, completed, error in
            if let error = error {
                print("Print error: \(error)")
            } else if completed {
                print("Print completed")
            }
        }
    }

    @MainActor
    private func sharePDFFile(pdfData: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Label-\(order.orderNumber).pdf")

        do {
            try pdfData.write(to: tempURL)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(activityVC, animated: true)
            }
        } catch {
            errorMessage = "\(L10n.PrintLabel.errorSaving): \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Label Preview

struct LabelPreview: View {
    let order: Order
    let size: LabelSize
    let workshopName: String
    let trackingURL: String

    private var customerName: String {
        order.customer?.name ?? "Cliente"
    }

    private var customerPhone: String {
        order.customer?.phone ?? ""
    }

    private var deviceModel: String {
        if let brand = order.deviceBrand, let model = order.deviceModel {
            return "\(brand) \(model)"
        }
        return order.deviceModel ?? order.deviceType.displayName
    }

    private var formattedDate: String {
        if let date = order.receivedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yy"
            return formatter.string(from: date)
        }
        return ""
    }

    private var problemShort: String {
        let problem = order.problemDescription
        if problem.count > 25 {
            return String(problem.prefix(22)) + "..."
        }
        return problem
    }

    var body: some View {
        GeometryReader { geometry in
            if size == .small {
                smallLabelLayout(geometry: geometry)
            } else {
                mediumLabelLayout(geometry: geometry)
            }
        }
    }

    // MARK: - Small Label (40x30mm) - Horizontal

    private func smallLabelLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            // Header: Circle + Workshop | Fecha
            HStack {
                // Device type circle
                Circle()
                    .fill(Color.black)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text(order.deviceType.labelLetter)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(workshopName)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 5))
                    .foregroundColor(AxerColors.textSecondary)
            }
            .padding(.horizontal, 5)
            .padding(.top, 4)

            // Content row
            HStack(alignment: .top, spacing: 3) {
                // Left: Customer details
                VStack(alignment: .leading, spacing: 1) {
                    Text(customerName)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text(deviceModel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text(problemShort)
                        .font(.system(size: 5))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Vertical separator
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 0.5)

                // Right: QR + Order
                VStack(spacing: 1) {
                    if let qrImage = generateQRCode(from: trackingURL) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.qrSize, height: size.qrSize)
                    }

                    Text(order.orderNumber)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 4)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    // MARK: - Medium Label (50x30mm) - Horizontal

    private func mediumLabelLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            // Header: Circle + Workshop | Fecha
            HStack {
                // Device type circle
                Circle()
                    .fill(Color.black)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text(order.deviceType.labelLetter)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(workshopName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 6))
                    .foregroundColor(AxerColors.textSecondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)

            // Content row
            HStack(alignment: .top, spacing: 4) {
                // Left: Customer details
                VStack(alignment: .leading, spacing: 1) {
                    Text(customerName)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text(deviceModel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    if !customerPhone.isEmpty {
                        Text(customerPhone)
                            .font(.system(size: 6))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }

                    if let password = order.devicePassword, !password.isEmpty {
                        Text(password)
                            .font(.system(size: 6))
                            .foregroundColor(AxerColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Vertical separator
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1)

                // Right: Problem + QR + Order
                VStack(alignment: .trailing, spacing: 2) {
                    Text(problemShort)
                        .font(.system(size: 5))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)

                    if let qrImage = generateQRCode(from: trackingURL) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.qrSize, height: size.qrSize)
                    }

                    Text(order.orderNumber)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    // MARK: - QR Generator

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale: CGFloat = 3
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
