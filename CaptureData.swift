import UIKit
import simd

/// Data captured from a single ARKit frame including RGB, depth, and camera intrinsics
struct CaptureData {
    let rgbImage: UIImage
    let rgbJPEGData: Data
    let depthMap: [Float]         // 256×192 = 49,152 values
    let confidenceMap: [UInt8]
    let depthWidth: Int           // 256
    let depthHeight: Int          // 192
    let rgbWidth: Int
    let rgbHeight: Int
    let intrinsics: CameraIntrinsics
    let captureDistance: Float     // meters
    let timestamp: Date
    let deviceModel: String
    
    /// Camera intrinsic parameters for 3D backprojection
    struct CameraIntrinsics: Codable {
        let fx: Float
        let fy: Float
        let cx: Float
        let cy: Float
        
        /// Scale intrinsics from RGB resolution to depth resolution
        func scaled(toWidth: Int, toHeight: Int, fromWidth: Int, fromHeight: Int) -> CameraIntrinsics {
            let sx = Float(toWidth) / Float(fromWidth)
            let sy = Float(toHeight) / Float(fromHeight)
            return CameraIntrinsics(
                fx: fx * sx,
                fy: fy * sy,
                cx: cx * sx,
                cy: cy * sy
            )
        }
    }
}

// MARK: - Codable representation for storage
struct CaptureDataRecord: Codable {
    let captureDistance: Float
    let timestamp: Date
    let deviceModel: String
    let depthWidth: Int
    let depthHeight: Int
    let rgbWidth: Int
    let rgbHeight: Int
    let intrinsics: CaptureData.CameraIntrinsics
}
