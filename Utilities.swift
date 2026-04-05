import UIKit
import simd

// MARK: - Haptic Manager
class HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Math Utilities
struct MathUtils {
    /// Cross product of two 3D vectors
    static func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
        return simd_cross(a, b)
    }
    
    /// Dot product
    static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return simd_dot(a, b)
    }
    
    /// Normalize vector
    static func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let len = simd_length(v)
        guard len > 0 else { return v }
        return v / len
    }
    
    /// Distance between two 3D points
    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return simd_distance(a, b)
    }
    
    /// Clamp value to range
    static func clamp<T: Comparable>(_ value: T, min minVal: T, max maxVal: T) -> T {
        return max(minVal, min(maxVal, value))
    }
}

// MARK: - Image Utilities
struct ImageUtils {
    /// Resize UIImage to target size
    static func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Convert UIImage to JPEG Data
    static func toJPEG(_ image: UIImage, quality: CGFloat = 0.85) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
    
    /// Convert UIImage to base64 string
    static func toBase64(_ image: UIImage, quality: CGFloat = 0.85) -> String? {
        return image.jpegData(compressionQuality: quality)?.base64EncodedString()
    }
}
