import Foundation
import CoreGraphics

/// Complete wound measurement result
struct WoundMeasurement: Codable {
    let regions: [RegionMeasurement]
    let totalAreaCm2: Float
    let totalVolumeMl: Float
    let numRegions: Int
    let measurementMode: String  // "3d_lidar"
    let validDepthCoverage: Float  // 0-1
    let captureDistanceCm: Float
    let confidence: MeasurementConfidence
    let timestamp: Date
    
    /// Convenience: primary (largest) region
    var primary: RegionMeasurement? { regions.first }
}

/// Measurement for a single wound region
struct RegionMeasurement: Codable {
    let id: Int
    let areaCm2: Float
    let maxLengthCm: Float
    let maxWidthCm: Float
    let maxDepthMm: Float
    let meanDepthMm: Float
    let volumeMl: Float
    let perimeterCm: Float
    let centroid: CodableCGPoint
    let lengthLineStart: CodableCGPoint
    let lengthLineEnd: CodableCGPoint
    let widthLineStart: CodableCGPoint
    let widthLineEnd: CodableCGPoint
    let deepestPoint: CodableCGPoint
}

/// Codable wrapper for CGPoint
struct CodableCGPoint: Codable {
    let x: CGFloat
    let y: CGFloat
    
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// Measurement confidence level
enum MeasurementConfidence: String, Codable {
    case high, medium, low
    
    static func assess(depthCoverage: Float, captureDistanceCm: Float, pointCount: Int) -> MeasurementConfidence {
        var score = 0
        
        if depthCoverage > 0.8 { score += 2 }
        else if depthCoverage > 0.5 { score += 1 }
        
        if captureDistanceCm >= 15 && captureDistanceCm <= 35 { score += 2 }
        else if captureDistanceCm >= 10 && captureDistanceCm <= 50 { score += 1 }
        
        if pointCount > 500 { score += 1 }
        
        if score >= 4 { return .high }
        if score >= 2 { return .medium }
        return .low
    }
}
