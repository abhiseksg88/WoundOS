import UIKit

/// Result from wound segmentation (either mock or real API)
struct SegmentationResult {
    let segmentationId: String
    let mask: UIImage              // Binary black/white mask
    let overlay: UIImage?          // Original image with green contours
    let contours: [WoundContour]
    let woundPixels: Int
    let confidence: Float
    let model: String
    let inferenceMs: Int
}

/// Represents a wound contour polygon
struct WoundContour {
    let points: [CGPoint]
    let area: Int  // pixel area
    let boundingBox: CGRect
}

/// Errors for segmentation
enum SegmentationError: Error, LocalizedError {
    case mockDataMissing
    case apiTimeout
    case networkError(String)
    case invalidResponse
    case noWoundDetected
    
    var errorDescription: String? {
        switch self {
        case .mockDataMissing: return "Mock segmentation data not found in bundle."
        case .apiTimeout: return "Segmentation timed out after 10 seconds."
        case .networkError(let msg): return "Network error: \(msg)"
        case .invalidResponse: return "Invalid response from segmentation API."
        case .noWoundDetected: return "No wound boundary detected in the image."
        }
    }
}
