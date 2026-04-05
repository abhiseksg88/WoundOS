import SwiftUI

// MARK: - Theme
enum Theme {
    // MARK: Colors (Apple Health-style, functional only)
    enum Colors {
        static let background = Color(UIColor.systemBackground)
        static let groupedBackground = Color(UIColor.systemGroupedBackground)
        static let secondaryGrouped = Color(UIColor.secondarySystemGroupedBackground)
        static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
        
        static let primaryLabel = Color(UIColor.label)
        static let secondaryLabel = Color(UIColor.secondaryLabel)
        static let tertiaryLabel = Color(UIColor.tertiaryLabel)
        
        // Functional colors
        static let healthy = Color.green
        static let warning = Color.red
        static let interactive = Color.blue
        static let caution = Color.orange
        
        // Distance indicator
        static let optimal = Color.green
        static let good = Color.yellow
        static let tooClose = Color.red
        static let tooFar = Color.red
        static let noDepth = Color.gray
        
        // Depth heatmap
        static let depthShallow = Color.green
        static let depthModerate = Color.yellow
        static let depthDeep = Color.red
    }
    
    // MARK: Typography
    enum Typography {
        // Hero measurement number
        static let heroMeasurement = Font.system(size: 34, weight: .bold, design: .default)
        // Sub-metric values
        static let subMetric = Font.system(size: 22, weight: .semibold, design: .default)
        // Section headers
        static let sectionHeader = Font.system(size: 20, weight: .semibold, design: .rounded)
        // Body text
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        // Labels
        static let label = Font.system(size: 13, weight: .regular, design: .default)
        // Small footer text
        static let footer = Font.system(size: 11, weight: .regular, design: .default)
        // Caption
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        // Delta (change indicator)
        static let delta = Font.system(size: 15, weight: .medium, design: .default)
    }
    
    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: Corner Radius
    enum CornerRadius {
        static let card: CGFloat = 12
        static let pill: CGFloat = 20
        static let button: CGFloat = 30
    }
}

// MARK: - Card Shadow
extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
