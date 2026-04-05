import UIKit
import CoreGraphics
import Accelerate

/// Mask processing utilities: resize, contour extraction, overlay generation, connected components
class MaskProcessor {
    
    /// Resize mask to target dimensions using nearest-neighbor interpolation
    static func resizeMask(_ mask: UIImage, toWidth: Int, toHeight: Int) -> UIImage? {
        let size = CGSize(width: toWidth, height: toHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            // Nearest-neighbor: disable interpolation
            let context = UIGraphicsGetCurrentContext()
            context?.interpolationQuality = .none
            mask.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Convert mask UIImage to binary pixel array [UInt8] (0 or 1)
    static func toBinaryArray(_ mask: UIImage) -> (array: [UInt8], width: Int, height: Int)? {
        guard let cgImage = mask.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerRow = width
        let totalBytes = width * height
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Threshold: > 128 = wound (1), else background (0)
        let binaryArray = pixelData.map { UInt8($0 > 128 ? 1 : 0) }
        return (binaryArray, width, height)
    }
    
    /// Count white (wound) pixels in a mask
    static func countWhitePixels(_ mask: UIImage) -> Int {
        guard let (array, _, _) = toBinaryArray(mask) else { return 0 }
        return array.reduce(0) { $0 + Int($1) }
    }
    
    /// Extract contour points from a binary mask using simple edge detection
    static func extractContours(from mask: UIImage) -> [WoundContour] {
        guard let (binary, width, height) = toBinaryArray(mask) else { return [] }
        
        // Find connected components first
        let labels = connectedComponents(binary: binary, width: width, height: height)
        let maxLabel = labels.max() ?? 0
        
        if maxLabel == 0 { return [] }
        
        var contours: [WoundContour] = []
        
        for label in 1...maxLabel {
            var edgePoints: [CGPoint] = []
            var minX = width, maxX = 0, minY = height, maxY = 0
            var area = 0
            
            for y in 0..<height {
                for x in 0..<width {
                    let idx = y * width + x
                    if labels[idx] == label {
                        area += 1
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                        
                        // Edge detection: check 4-neighbors
                        let isEdge = x == 0 || x == width-1 || y == 0 || y == height-1 ||
                            labels[(y-1)*width+x] != label ||
                            labels[(y+1)*width+x] != label ||
                            labels[y*width+(x-1)] != label ||
                            labels[y*width+(x+1)] != label
                        
                        if isEdge {
                            edgePoints.append(CGPoint(x: x, y: y))
                        }
                    }
                }
            }
            
            // Filter very small regions (noise)
            guard area > 50 else { continue }
            
            // Sort edge points by angle from centroid for ordered contour
            let cx = Float(edgePoints.reduce(0) { $0 + $1.x }) / Float(edgePoints.count)
            let cy = Float(edgePoints.reduce(0) { $0 + $1.y }) / Float(edgePoints.count)
            edgePoints.sort { p1, p2 in
                let a1 = atan2(Float(p1.y) - cy, Float(p1.x) - cx)
                let a2 = atan2(Float(p2.y) - cy, Float(p2.x) - cx)
                return a1 < a2
            }
            
            let contour = WoundContour(
                points: edgePoints,
                area: area,
                boundingBox: CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
            )
            contours.append(contour)
        }
        
        // Sort by area (largest first)
        return contours.sorted { $0.area > $1.area }
    }
    
    /// Connected component labeling (4-connectivity) using union-find
    static func connectedComponents(binary: [UInt8], width: Int, height: Int) -> [Int] {
        var labels = [Int](repeating: 0, count: width * height)
        var nextLabel = 1
        var parent = [Int: Int]()
        
        func find(_ x: Int) -> Int {
            var root = x
            while parent[root] != nil && parent[root] != root {
                root = parent[root]!
            }
            // Path compression
            var node = x
            while node != root {
                let next = parent[node]!
                parent[node] = root
                node = next
            }
            return root
        }
        
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }
        
        // First pass
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                guard binary[idx] == 1 else { continue }
                
                let left = x > 0 ? labels[y * width + (x-1)] : 0
                let above = y > 0 ? labels[(y-1) * width + x] : 0
                
                if left == 0 && above == 0 {
                    labels[idx] = nextLabel
                    parent[nextLabel] = nextLabel
                    nextLabel += 1
                } else if left != 0 && above == 0 {
                    labels[idx] = left
                } else if left == 0 && above != 0 {
                    labels[idx] = above
                } else {
                    labels[idx] = min(left, above)
                    if left != above { union(left, above) }
                }
            }
        }
        
        // Second pass: resolve labels
        var labelMap = [Int: Int]()
        var finalLabel = 0
        for i in 0..<labels.count {
            if labels[i] > 0 {
                let root = find(labels[i])
                if labelMap[root] == nil {
                    finalLabel += 1
                    labelMap[root] = finalLabel
                }
                labels[i] = labelMap[root]!
            }
        }
        
        return labels
    }
    
    /// Dilate binary mask by a given radius (for periwound ring)
    static func dilate(binary: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        var dilated = [UInt8](repeating: 0, count: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                guard binary[y * width + x] == 1 else { continue }
                
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        if dx*dx + dy*dy <= radius*radius {
                            dilated[ny * width + nx] = 1
                        }
                    }
                }
            }
        }
        
        return dilated
    }
    
    /// Draw green contour overlay on the original image
    static func drawContourOverlay(on original: UIImage, mask: UIImage) -> UIImage {
        let size = original.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw original image
            original.draw(at: .zero)
            
            // Extract contours
            let contours = extractContours(from: mask)
            
            // Scale contour points to image size
            guard let maskCG = mask.cgImage else { return }
            let scaleX = size.width / CGFloat(maskCG.width)
            let scaleY = size.height / CGFloat(maskCG.height)
            
            let ctx = context.cgContext
            ctx.setStrokeColor(UIColor.green.cgColor)
            ctx.setLineWidth(2.5)
            
            for contour in contours {
                guard contour.points.count > 2 else { continue }
                
                let scaledPoints = contour.points.map {
                    CGPoint(x: $0.x * scaleX, y: $0.y * scaleY)
                }
                
                ctx.beginPath()
                ctx.move(to: scaledPoints[0])
                for point in scaledPoints.dropFirst() {
                    ctx.addLine(to: point)
                }
                ctx.closePath()
                ctx.strokePath()
            }
        }
    }
}
