import AppKit
import PDFKit

enum PDFExporter {

    struct Config {
        var projectName: String = "Storyboard"
        var templateName: String = ""
        var pageSize: CGSize = CGSize(width: 595.28, height: 841.89) // A4 in points
        var margin: CGFloat = 40
        var framesPerPage: Int = 2
    }

    static func generate(frames: [StoryboardFrame], config: Config = Config()) -> Data {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: config.pageSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return Data()
        }

        drawTitlePage(context: context, config: config, frameCount: frames.count)
        drawFramePages(context: context, config: config, frames: frames)

        context.closePDF()
        return pdfData as Data
    }

    @MainActor
    static func export(frames: [StoryboardFrame], config: Config = Config()) {
        let data = generate(frames: frames, config: config)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(config.projectName).pdf"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Title page

    private static func drawTitlePage(context: CGContext, config: Config, frameCount: Int) {
        let size = config.pageSize
        var mediaBox = CGRect(origin: .zero, size: size)
        context.beginPDFPage(nil)

        let titleFont = NSFont.systemFont(ofSize: 32, weight: .bold)
        let subtitleFont = NSFont.systemFont(ofSize: 14, weight: .regular)

        let centerY = size.height / 2

        drawText(config.projectName, font: titleFont, color: .black,
                 in: CGRect(x: config.margin, y: centerY - 20, width: size.width - config.margin * 2, height: 40),
                 alignment: .center, context: context, pageHeight: size.height)

        drawText(config.templateName, font: subtitleFont, color: .gray,
                 in: CGRect(x: config.margin, y: centerY - 50, width: size.width - config.margin * 2, height: 20),
                 alignment: .center, context: context, pageHeight: size.height)

        let frameInfo = "\(frameCount) frames \u{2022} Created with Keyframe"
        drawText(frameInfo, font: subtitleFont, color: .gray,
                 in: CGRect(x: config.margin, y: centerY - 75, width: size.width - config.margin * 2, height: 20),
                 alignment: .center, context: context, pageHeight: size.height)

        context.endPDFPage()
    }

    // MARK: - Frame pages

    private static func drawFramePages(context: CGContext, config: Config, frames: [StoryboardFrame]) {
        let size = config.pageSize
        let contentWidth = size.width - config.margin * 2
        let frameHeight: CGFloat = 180
        let spacing: CGFloat = 30
        let captionHeight: CGFloat = 50

        let pairs = stride(from: 0, to: frames.count, by: config.framesPerPage).map { start in
            Array(frames[start..<min(start + config.framesPerPage, frames.count)])
        }

        for (pageIndex, pair) in pairs.enumerated() {
            context.beginPDFPage(nil)

            for (slotIndex, frame) in pair.enumerated() {
                let globalIndex = pageIndex * config.framesPerPage + slotIndex
                let yOffset = config.margin + CGFloat(slotIndex) * (frameHeight + captionHeight + spacing)

                let imageRect = CGRect(x: config.margin, y: yOffset, width: contentWidth, height: frameHeight)

                if let imageData = frame.imageData, let nsImage = NSImage(data: imageData),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let flippedY = size.height - imageRect.origin.y - imageRect.height
                    context.draw(cgImage, in: CGRect(x: imageRect.origin.x, y: flippedY, width: imageRect.width, height: imageRect.height))
                } else {
                    let flippedY = size.height - imageRect.origin.y - imageRect.height
                    context.setFillColor(NSColor(white: 0.96, alpha: 1).cgColor)
                    context.fill(CGRect(x: imageRect.origin.x, y: flippedY, width: imageRect.width, height: imageRect.height))

                    let numStr = "\(globalIndex + 1)"
                    let numFont = NSFont.systemFont(ofSize: 24, weight: .medium)
                    drawText(numStr, font: numFont, color: NSColor(white: 0.63, alpha: 1),
                             in: CGRect(x: imageRect.origin.x, y: imageRect.origin.y + frameHeight / 2 - 12, width: contentWidth, height: 30),
                             alignment: .center, context: context, pageHeight: size.height)
                }

                let labelY = yOffset + frameHeight + 8
                let labelFont = NSFont.systemFont(ofSize: 10, weight: .regular)
                let captionFont = NSFont.systemFont(ofSize: 12, weight: .regular)
                let beatFont = NSFont.systemFont(ofSize: 10, weight: .regular)

                drawText("Frame \(globalIndex + 1)", font: labelFont, color: .gray,
                         in: CGRect(x: config.margin, y: labelY, width: contentWidth, height: 14),
                         alignment: .left, context: context, pageHeight: size.height)

                drawText(frame.caption, font: captionFont, color: .black,
                         in: CGRect(x: config.margin, y: labelY + 16, width: contentWidth, height: 16),
                         alignment: .left, context: context, pageHeight: size.height)

                drawText(frame.beatTitle, font: beatFont, color: .gray,
                         in: CGRect(x: config.margin, y: labelY + 34, width: contentWidth, height: 14),
                         alignment: .left, context: context, pageHeight: size.height)
            }

            context.endPDFPage()
        }
    }

    // MARK: - Text drawing

    private static func drawText(_ text: String, font: NSFont, color: NSColor,
                                  in rect: CGRect, alignment: NSTextAlignment,
                                  context: CGContext, pageHeight: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        let attrString = NSAttributedString(string: text, attributes: attributes)
        let flippedRect = CGRect(x: rect.origin.x, y: pageHeight - rect.origin.y - rect.height,
                                  width: rect.width, height: rect.height)

        context.saveGState()
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)

        let drawRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
        attrString.draw(with: drawRect, options: [.usesLineFragmentOrigin], context: nil)

        context.restoreGState()
    }
}
