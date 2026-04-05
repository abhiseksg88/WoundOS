import UIKit

// MARK: - Clinical Summary Generator
class ClinicalSummaryGenerator {
    
    static func generate(measurement: WoundMeasurement, region: RegionMeasurement) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateStr = dateFormatter.string(from: measurement.timestamp)
        
        var text = "A wound measuring \(String(format: "%.2f", region.areaCm2)) cm² was captured on \(dateStr). "
        text += "The wound extends \(String(format: "%.1f", region.maxLengthCm)) cm in length and "
        text += "\(String(format: "%.1f", region.maxWidthCm)) cm in width"
        
        if region.maxDepthMm > 0 {
            text += ", with a maximum cavity depth of \(String(format: "%.1f", region.maxDepthMm)) mm "
            text += "and an estimated volume of \(String(format: "%.1f", region.volumeMl)) mL"
        }
        text += ".\n\n"
        
        text += "Measurement was obtained via iPhone LiDAR 3D imaging at a capture distance of "
        text += "\(Int(measurement.captureDistanceCm)) cm. "
        text += "Estimated measurement accuracy: ±5%.\n\n"
        
        let pushScore = PUSHCalculator.areaSubscale(areaCm2: region.areaCm2)
        text += "PUSH area subscale: \(pushScore)/10."
        
        if measurement.numRegions > 1 {
            text += "\n\n\(measurement.numRegions) wound regions detected. "
            text += "Total wound area: \(String(format: "%.2f", measurement.totalAreaCm2)) cm²."
        }
        
        return text
    }
}

// MARK: - Annotated Image Renderer
class AnnotatedImageRenderer {
    
    static func render(
        original: UIImage,
        measurement: WoundMeasurement,
        imageWidth: Int,
        imageHeight: Int,
        depthWidth: Int,
        depthHeight: Int
    ) -> UIImage {
        let size = original.size
        let scaleX = size.width / CGFloat(depthWidth)
        let scaleY = size.height / CGFloat(depthHeight)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw original (with overlay if available)
            original.draw(at: .zero)
            
            let ctx = context.cgContext
            
            guard let primary = measurement.primary else { return }
            
            // Draw length line (blue)
            let lStart = CGPoint(x: primary.lengthLineStart.x * scaleX, y: primary.lengthLineStart.y * scaleY)
            let lEnd = CGPoint(x: primary.lengthLineEnd.x * scaleX, y: primary.lengthLineEnd.y * scaleY)
            
            if lStart != .zero && lEnd != .zero {
                drawMeasurementLine(
                    ctx: ctx,
                    from: lStart,
                    to: lEnd,
                    color: UIColor.systemBlue,
                    label: "\(String(format: "%.1f", primary.maxLengthCm)) cm",
                    fontSize: max(14, size.width * 0.025)
                )
            }
            
            // Draw width line (orange)
            let wStart = CGPoint(x: primary.widthLineStart.x * scaleX, y: primary.widthLineStart.y * scaleY)
            let wEnd = CGPoint(x: primary.widthLineEnd.x * scaleX, y: primary.widthLineEnd.y * scaleY)
            
            if wStart != .zero && wEnd != .zero {
                drawMeasurementLine(
                    ctx: ctx,
                    from: wStart,
                    to: wEnd,
                    color: UIColor.systemOrange,
                    label: "\(String(format: "%.1f", primary.maxWidthCm)) cm",
                    fontSize: max(14, size.width * 0.025)
                )
            }
            
            // Draw deepest point crosshair
            let dPoint = CGPoint(x: primary.deepestPoint.x * scaleX, y: primary.deepestPoint.y * scaleY)
            if dPoint != .zero && primary.maxDepthMm > 0 {
                drawCrosshair(
                    ctx: ctx,
                    at: dPoint,
                    label: "\(String(format: "%.1f", primary.maxDepthMm)) mm deep",
                    fontSize: max(12, size.width * 0.02)
                )
            }
        }
    }
    
    private static func drawMeasurementLine(
        ctx: CGContext,
        from: CGPoint,
        to: CGPoint,
        color: UIColor,
        label: String,
        fontSize: CGFloat
    ) {
        ctx.saveGState()
        
        // Line
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2.5)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
        
        // Endpoints
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: from.x - 4, y: from.y - 4, width: 8, height: 8))
        ctx.fillEllipse(in: CGRect(x: to.x - 4, y: to.y - 4, width: 8, height: 8))
        
        // Label at midpoint
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white,
            .backgroundColor: color.withAlphaComponent(0.7)
        ]
        
        let nsString = label as NSString
        let textSize = nsString.size(withAttributes: attrs)
        let textRect = CGRect(x: midX - textSize.width / 2, y: midY - textSize.height - 4, width: textSize.width, height: textSize.height)
        
        // Background pill
        let bgRect = textRect.insetBy(dx: -6, dy: -3)
        ctx.setFillColor(color.withAlphaComponent(0.7).cgColor)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 4)
        ctx.addPath(bgPath.cgPath)
        ctx.fillPath()
        
        nsString.draw(in: textRect, withAttributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ])
        
        ctx.restoreGState()
    }
    
    private static func drawCrosshair(ctx: CGContext, at point: CGPoint, label: String, fontSize: CGFloat) {
        let size: CGFloat = 12
        ctx.saveGState()
        
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2)
        
        ctx.move(to: CGPoint(x: point.x - size, y: point.y))
        ctx.addLine(to: CGPoint(x: point.x + size, y: point.y))
        ctx.move(to: CGPoint(x: point.x, y: point.y - size))
        ctx.addLine(to: CGPoint(x: point.x, y: point.y + size))
        ctx.strokePath()
        
        // Label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let nsString = label as NSString
        let textSize = nsString.size(withAttributes: attrs)
        let textPoint = CGPoint(x: point.x + size + 4, y: point.y - textSize.height / 2)
        
        // Background
        let bgRect = CGRect(origin: textPoint, size: textSize).insetBy(dx: -4, dy: -2)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        ctx.fill(bgRect)
        
        nsString.draw(at: textPoint, withAttributes: attrs)
        
        ctx.restoreGState()
    }
}

// MARK: - Depth Heatmap Renderer
class DepthHeatmapRenderer {
    
    static func render(
        depth: [Float],
        mask: UIImage,
        width: Int,
        height: Int
    ) -> UIImage {
        // Resize mask to depth resolution
        guard let resized = MaskProcessor.resizeMask(mask, toWidth: width, toHeight: height),
              let (binary, _, _) = MaskProcessor.toBinaryArray(resized) else {
            return UIImage()
        }
        
        // Find depth range within wound
        var maxD: Float = 0
        var sumD: Float = 0
        var count = 0
        
        for i in 0..<min(depth.count, binary.count) {
            if binary[i] == 1 && depth[i] > 0 && depth[i] < 1.5 {
                count += 1
                sumD += depth[i]
                if depth[i] > maxD { maxD = depth[i] }
            }
        }
        
        let meanD = count > 0 ? sumD / Float(count) : 0
        
        // Create RGBA pixel buffer
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        
        for i in 0..<min(depth.count, binary.count) {
            let pixelIdx = i * 4
            
            if binary[i] == 1 && depth[i] > 0 {
                // Relative depth (0 = at plane, higher = deeper)
                let relDepth = abs(depth[i] - meanD)
                let depthMm = relDepth * 1000
                
                // Color mapping: green → yellow → red
                let r: UInt8, g: UInt8, b: UInt8
                
                if depthMm < 2.0 {
                    // Green (shallow)
                    let t = depthMm / 2.0
                    r = UInt8(min(255, t * 255))
                    g = 200
                    b = 50
                } else if depthMm < 5.0 {
                    // Yellow-orange (moderate)
                    let t = (depthMm - 2.0) / 3.0
                    r = 255
                    g = UInt8(max(0, 200 - t * 150))
                    b = 50
                } else {
                    // Red (deep)
                    r = 220
                    g = 50
                    b = 50
                }
                
                pixels[pixelIdx] = r
                pixels[pixelIdx + 1] = g
                pixels[pixelIdx + 2] = b
                pixels[pixelIdx + 3] = 255  // Opaque
            } else {
                // Background: dark gray
                pixels[pixelIdx] = 30
                pixels[pixelIdx + 1] = 30
                pixels[pixelIdx + 2] = 30
                pixels[pixelIdx + 3] = 255
            }
        }
        
        // Create UIImage from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage() else {
            return UIImage()
        }
        
        return UIImage(cgImage: cgImage)
    }
}
