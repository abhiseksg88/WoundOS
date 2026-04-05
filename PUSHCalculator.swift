import Foundation

/// PUSH (Pressure Ulcer Scale for Healing) area subscale calculator
/// Only computes the area component (0-10). Full PUSH requires clinical input for exudate & tissue type.
class PUSHCalculator {
    
    /// PUSH area subscale bins (cm²)
    /// Score 0: 0 cm²
    /// Score 1: 0 < area < 0.3
    /// Score 2: 0.3 - 0.6
    /// Score 3: 0.7 - 1.0
    /// Score 4: 1.0 - 2.0
    /// Score 5: 2.0 - 3.0
    /// Score 6: 3.0 - 4.0
    /// Score 7: 4.0 - 8.0
    /// Score 8: 8.0 - 12.0
    /// Score 9: 12.0 - 24.0
    /// Score 10: > 24.0
    
    private static let bins: [Float] = [0, 0.3, 0.7, 1.0, 2.0, 3.0, 4.0, 8.0, 12.0, 24.0]
    
    /// Compute area subscale from wound area in cm²
    static func areaSubscale(areaCm2: Float) -> Int {
        if areaCm2 <= 0 { return 0 }
        
        for (i, threshold) in bins.enumerated() {
            if areaCm2 < threshold {
                return i
            }
        }
        
        return 10  // > 24.0 cm²
    }
    
    /// Get the description for a PUSH area score
    static func description(for score: Int) -> String {
        switch score {
        case 0: return "No measurable wound"
        case 1...3: return "Small wound"
        case 4...6: return "Moderate wound"
        case 7...8: return "Large wound"
        case 9...10: return "Very large wound"
        default: return "Unknown"
        }
    }
}
