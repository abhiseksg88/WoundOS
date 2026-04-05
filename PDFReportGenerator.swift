import UIKit

/// Generates a shareable clinical PDF report using UIGraphicsPDFRenderer
class PDFReportGenerator {
    
    static func generate(
        measurement: WoundMeasurement,
        captureImage: UIImage,
        overlayImage: UIImage,
        depthMap: [Float],
        mask: UIImage,
        depthWidth: Int,
        depthHeight: Int
    ) -> Data {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return renderer.pdfData { context in
            context.beginPage()
            
            var yOffset: CGFloat = margin
            let primary = measurement.primary
            
            // Header
            yOffset = drawText("CarePlix WoundOS", at: CGPoint(x: margin, y: yOffset),
                             font: .systemFont(ofSize: 22, weight: .bold))
            yOffset = drawText("Wound Measurement Report", at: CGPoint(x: margin, y: yOffset),
                             font: .systemFont(ofSize: 16, weight: .medium), color: .darkGray)
            yOffset += 8
            yOffset = drawLine(from: CGPoint(x: margin, y: yOffset),
                             to: CGPoint(x: pageWidth - margin, y: yOffset))
            yOffset += 12
            
            // Metadata
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            
            yOffset = drawText("Date: \(dateFormatter.string(from: measurement.timestamp))",
                             at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 11))
            yOffset = drawText("Device: iPhone · LiDAR",
                             at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 11))
            yOffset = drawText("App Version: 1.0.0",
                             at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 11))
            yOffset += 16
            
            // Wound Image + Measurements side by side
            let imageSize: CGFloat = 200
            let imageRect = CGRect(x: margin, y: yOffset, width: imageSize, height: imageSize)
            overlayImage.draw(in: imageRect)
            
            // Measurements column
            let metricsX = margin + imageSize + 20
            var metricsY = yOffset
            
            metricsY = drawText("MEASUREMENTS", at: CGPoint(x: metricsX, y: metricsY),
                              font: .systemFont(ofSize: 13, weight: .bold), color: .darkGray)
            metricsY += 4
            
            if let p = primary {
                metricsY = drawText("Area: \(String(format: "%.2f", p.areaCm2)) cm²",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 14, weight: .semibold))
                metricsY = drawText("Length: \(String(format: "%.1f", p.maxLengthCm)) cm",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 12))
                metricsY = drawText("Width: \(String(format: "%.1f", p.maxWidthCm)) cm",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 12))
                metricsY = drawText("Depth: \(String(format: "%.1f", p.maxDepthMm)) mm",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 12))
                metricsY = drawText("Volume: \(String(format: "%.1f", p.volumeMl)) mL",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 12))
                metricsY = drawText("Perimeter: \(String(format: "%.1f", p.perimeterCm)) cm",
                                  at: CGPoint(x: metricsX, y: metricsY), font: .systemFont(ofSize: 12))
            }
            
            yOffset = max(yOffset + imageSize, metricsY) + 20
            
            // Depth Heatmap
            let heatmap = DepthHeatmapRenderer.render(depth: depthMap, mask: mask, width: depthWidth, height: depthHeight)
            let heatmapRect = CGRect(x: margin, y: yOffset, width: 150, height: 112)
            heatmap.draw(in: heatmapRect)
            
            var heatmapTextY = yOffset
            let heatmapTextX = margin + 170
            heatmapTextY = drawText("DEPTH MAP", at: CGPoint(x: heatmapTextX, y: heatmapTextY),
                                   font: .systemFont(ofSize: 13, weight: .bold), color: .darkGray)
            if let p = primary {
                heatmapTextY = drawText("Deepest: \(String(format: "%.1f", p.maxDepthMm)) mm",
                                       at: CGPoint(x: heatmapTextX, y: heatmapTextY), font: .systemFont(ofSize: 12))
                heatmapTextY = drawText("Mean: \(String(format: "%.1f", p.meanDepthMm)) mm",
                                       at: CGPoint(x: heatmapTextX, y: heatmapTextY), font: .systemFont(ofSize: 12))
            }
            
            yOffset = max(yOffset + 112, heatmapTextY) + 20
            
            // PUSH Score
            if let p = primary {
                let pushScore = PUSHCalculator.areaSubscale(areaCm2: p.areaCm2)
                yOffset = drawText("PUSH Area Score: \(pushScore)/10",
                                 at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 14, weight: .semibold))
                yOffset += 12
            }
            
            // Clinical Summary
            yOffset = drawLine(from: CGPoint(x: margin, y: yOffset), to: CGPoint(x: pageWidth - margin, y: yOffset))
            yOffset += 8
            yOffset = drawText("CLINICAL SUMMARY", at: CGPoint(x: margin, y: yOffset),
                             font: .systemFont(ofSize: 13, weight: .bold), color: .darkGray)
            yOffset += 4
            
            if let p = primary {
                let summary = ClinicalSummaryGenerator.generate(measurement: measurement, region: p)
                yOffset = drawWrappedText(summary, at: CGPoint(x: margin, y: yOffset),
                                        maxWidth: contentWidth, font: .systemFont(ofSize: 11))
            }
            
            yOffset += 16
            yOffset = drawLine(from: CGPoint(x: margin, y: yOffset), to: CGPoint(x: pageWidth - margin, y: yOffset))
            yOffset += 8
            
            // Footer
            yOffset = drawText("Generated by CarePlix WoundOS v1.0.0",
                             at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 9), color: .gray)
            yOffset = drawText("This report is for clinical reference only. Not a substitute for clinical assessment.",
                             at: CGPoint(x: margin, y: yOffset), font: .systemFont(ofSize: 9), color: .gray)
        }
    }
    
    // MARK: - Drawing Helpers
    @discardableResult
    private static func drawText(_ text: String, at point: CGPoint,
                                font: UIFont, color: UIColor = .black) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let nsString = text as NSString
        let size = nsString.size(withAttributes: attrs)
        nsString.draw(at: point, withAttributes: attrs)
        return point.y + size.height + 2
    }
    
    @discardableResult
    private static func drawWrappedText(_ text: String, at point: CGPoint,
                                       maxWidth: CGFloat, font: UIFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray
        ]
        let nsString = text as NSString
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 300)
        let boundingRect = nsString.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                  options: .usesLineFragmentOrigin,
                                                  attributes: attrs, context: nil)
        nsString.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        return point.y + boundingRect.height + 4
    }
    
    @discardableResult
    private static func drawLine(from: CGPoint, to: CGPoint) -> CGFloat {
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        ctx?.setStrokeColor(UIColor.lightGray.cgColor)
        ctx?.setLineWidth(0.5)
        ctx?.move(to: from)
        ctx?.addLine(to: to)
        ctx?.strokePath()
        ctx?.restoreGState()
        return from.y
    }
}
