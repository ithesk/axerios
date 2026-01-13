import UIKit
import CoreImage.CIFilterBuiltins

struct LabelPDFRenderer {
    let order: Order
    let size: LabelSize
    let copies: Int
    let workshopName: String
    let trackingURL: String

    // Computed properties
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
        if problem.count > 30 {
            return String(problem.prefix(27)) + "..."
        }
        return problem
    }

    func generatePDF() throws -> Data {
        let pageWidth = size.widthPoints
        let pageHeight = size.heightPoints
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for _ in 0..<copies {
                context.beginPage()
                if size == .small {
                    drawSmallLabel(in: context.cgContext, rect: pageRect)
                } else {
                    drawMediumLabel(in: context.cgContext, rect: pageRect)
                }
            }
        }

        return data
    }

    // MARK: - Small Label (40x30mm) - Horizontal

    private func drawSmallLabel(in context: CGContext, rect: CGRect) {
        let margin: CGFloat = 4
        var yOffset: CGFloat = margin

        // Header row: Circle + Workshop | Date
        let circleSize: CGFloat = 11
        let circleRect = CGRect(x: margin, y: yOffset, width: circleSize, height: circleSize)
        drawDeviceCircle(in: context, rect: circleRect)

        // Workshop name
        let workshopFont = UIFont.systemFont(ofSize: 6, weight: .bold)
        let workshopRect = CGRect(x: margin + circleSize + 3, y: yOffset + 1, width: 50, height: 10)
        drawText(workshopName, in: context, rect: workshopRect, font: workshopFont, color: .black, alignment: .left)

        // Date on right
        let dateFont = UIFont.systemFont(ofSize: 5, weight: .regular)
        let dateColor = UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1)
        let dateRect = CGRect(x: rect.width - margin - 25, y: yOffset + 1, width: 25, height: 10)
        drawText(formattedDate, in: context, rect: dateRect, font: dateFont, color: dateColor, alignment: .right)

        yOffset += circleSize + 2

        // Content area
        let qrSize = size.qrSize
        let separatorX = rect.width - qrSize - margin - 6

        // Vertical separator
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: separatorX, y: yOffset))
        context.addLine(to: CGPoint(x: separatorX, y: rect.height - margin))
        context.strokePath()

        // Left side: Customer details
        let leftWidth = separatorX - margin - 3
        var leftY = yOffset

        // Customer name
        let nameFont = UIFont.systemFont(ofSize: 6, weight: .semibold)
        let nameRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 8)
        drawText(customerName, in: context, rect: nameRect, font: nameFont, color: .black, alignment: .left)
        leftY += 8

        // Device model
        let modelFont = UIFont.systemFont(ofSize: 7, weight: .bold)
        let modelRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 9)
        drawText(deviceModel, in: context, rect: modelRect, font: modelFont, color: .black, alignment: .left)
        leftY += 9

        // Problem
        let problemFont = UIFont.systemFont(ofSize: 4, weight: .regular)
        let problemRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 16)
        drawText(problemShort, in: context, rect: problemRect, font: problemFont, color: .black, alignment: .left, lineBreakMode: .byWordWrapping)

        // Right side: QR + Order
        let rightX = separatorX + 3
        var rightY = yOffset

        // QR Code
        let qrRect = CGRect(x: rect.width - margin - qrSize, y: rightY, width: qrSize, height: qrSize)
        drawQRCode(in: context, rect: qrRect)

        // Order number below QR
        let orderFont = UIFont.systemFont(ofSize: 5, weight: .bold)
        let orderRect = CGRect(x: rect.width - margin - qrSize, y: rightY + qrSize + 1, width: qrSize, height: 7)
        drawText(order.orderNumber, in: context, rect: orderRect, font: orderFont, color: .black, alignment: .center)
    }

    // MARK: - Medium Label (50x30mm) - Horizontal

    private func drawMediumLabel(in context: CGContext, rect: CGRect) {
        let margin: CGFloat = 4
        var yOffset: CGFloat = margin

        // Header row: Circle + Workshop | Date
        let circleSize: CGFloat = 12
        let circleRect = CGRect(x: margin, y: yOffset, width: circleSize, height: circleSize)
        drawDeviceCircle(in: context, rect: circleRect)

        // Workshop name
        let workshopFont = UIFont.systemFont(ofSize: 6, weight: .bold)
        let workshopRect = CGRect(x: margin + circleSize + 3, y: yOffset + 1, width: 60, height: 10)
        drawText(workshopName, in: context, rect: workshopRect, font: workshopFont, color: .black, alignment: .left)

        // Date on right
        let dateFont = UIFont.systemFont(ofSize: 5, weight: .regular)
        let dateColor = UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1)
        let dateRect = CGRect(x: rect.width - margin - 30, y: yOffset + 1, width: 30, height: 10)
        drawText(formattedDate, in: context, rect: dateRect, font: dateFont, color: dateColor, alignment: .right)

        yOffset += circleSize + 2

        // Content area
        let qrSize = size.qrSize
        let separatorX = rect.width - qrSize - margin - 8

        // Vertical separator
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: separatorX, y: yOffset))
        context.addLine(to: CGPoint(x: separatorX, y: rect.height - margin))
        context.strokePath()

        // Left side: Customer details
        let leftWidth = separatorX - margin - 4
        var leftY = yOffset

        // Customer name
        let nameFont = UIFont.systemFont(ofSize: 7, weight: .semibold)
        let nameRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 9)
        drawText(customerName, in: context, rect: nameRect, font: nameFont, color: .black, alignment: .left)
        leftY += 9

        // Device model
        let modelFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let modelRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 10)
        drawText(deviceModel, in: context, rect: modelRect, font: modelFont, color: .black, alignment: .left)
        leftY += 10

        // Phone
        if !customerPhone.isEmpty {
            let phoneFont = UIFont.systemFont(ofSize: 5, weight: .regular)
            let phoneRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 7)
            drawText(customerPhone, in: context, rect: phoneRect, font: phoneFont, color: .black, alignment: .left)
            leftY += 7
        }

        // Password
        if let password = order.devicePassword, !password.isEmpty {
            let passFont = UIFont.systemFont(ofSize: 5, weight: .regular)
            let passColor = UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1)
            let passRect = CGRect(x: margin, y: leftY, width: leftWidth, height: 7)
            drawText(password, in: context, rect: passRect, font: passFont, color: passColor, alignment: .left)
        }

        // Right side: Problem + QR + Order
        let rightX = separatorX + 4
        let rightWidth = rect.width - rightX - margin
        var rightY = yOffset

        // Problem at top right
        let problemFont = UIFont.systemFont(ofSize: 4, weight: .regular)
        let problemRect = CGRect(x: rightX, y: rightY, width: rightWidth, height: 12)
        drawText(problemShort, in: context, rect: problemRect, font: problemFont, color: .black, alignment: .right, lineBreakMode: .byWordWrapping)
        rightY += 10

        // QR Code
        let qrRect = CGRect(x: rect.width - margin - qrSize, y: rightY, width: qrSize, height: qrSize)
        drawQRCode(in: context, rect: qrRect)

        // Order number below QR
        let orderFont = UIFont.systemFont(ofSize: 6, weight: .bold)
        let orderRect = CGRect(x: rect.width - margin - qrSize, y: rightY + qrSize + 1, width: qrSize, height: 8)
        drawText(order.orderNumber, in: context, rect: orderRect, font: orderFont, color: .black, alignment: .center)
    }

    // MARK: - Drawing Helpers

    private func drawDeviceCircle(in context: CGContext, rect: CGRect) {
        // Draw black circle
        context.setFillColor(UIColor.black.cgColor)
        context.fillEllipse(in: rect)

        // Draw letter
        let letter = order.deviceType.labelLetter
        let font = UIFont.systemFont(ofSize: rect.width * 0.6, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]

        let text = NSString(string: letter)
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }

    private func drawText(_ text: String, in context: CGContext, rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment, lineBreakMode: NSLineBreakMode = .byTruncatingTail) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = lineBreakMode

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let nsText = NSString(string: text)
        nsText.draw(in: rect, withAttributes: attributes)
    }

    private func drawQRCode(in context: CGContext, rect: CGRect) {
        guard let qrImage = generateQRCodeCG(from: trackingURL) else { return }

        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        // Draw QR code
        context.draw(qrImage, in: rect)
    }

    private func generateQRCodeCG(from string: String) -> CGImage? {
        let ciContext = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size.qrSize / outputImage.extent.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        return ciContext.createCGImage(scaledImage, from: scaledImage.extent)
    }
}
