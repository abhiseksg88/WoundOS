import SwiftUI

// MARK: - Section Card (Apple Health style white rounded card)
struct SectionCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            content
        }
        .padding(Theme.Spacing.lg)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(Theme.CornerRadius.card)
        .cardShadow()
    }
}

// MARK: - Measurement Card (reusable metric display)
struct MeasurementCard: View {
    let title: String
    let value: String
    let unit: String
    var delta: String? = nil
    var deltaPositive: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.secondaryLabel)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Typography.subMetric)
                    .foregroundColor(Theme.Colors.primaryLabel)
                
                Text(unit)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.secondaryLabel)
            }
            
            if let delta = delta {
                Text(delta)
                    .font(Theme.Typography.caption)
                    .foregroundColor(deltaPositive ? Theme.Colors.healthy : Theme.Colors.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.groupedBackground)
        .cornerRadius(Theme.CornerRadius.card)
    }
}

// MARK: - Status Dot
struct StatusDot: View {
    let color: Color
    let size: CGFloat
    
    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Distance Pill (capsule distance indicator)
struct DistancePill: View {
    let distance: Float  // in cm
    let quality: DistanceQuality
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ruler")
                .font(.system(size: 12))
            
            Text("\(Int(distance)) cm")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            
            Text("·")
            
            StatusDot(color: quality.color)
            
            Text(quality.label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

enum DistanceQuality {
    case optimal, good, tooClose, tooFar, noDepth
    
    var color: Color {
        switch self {
        case .optimal: return Theme.Colors.optimal
        case .good: return Theme.Colors.good
        case .tooClose, .tooFar: return Theme.Colors.tooClose
        case .noDepth: return Theme.Colors.noDepth
        }
    }
    
    var label: String {
        switch self {
        case .optimal: return "Optimal"
        case .good: return "Good"
        case .tooClose: return "Move back"
        case .tooFar: return "Move closer"
        case .noDepth: return "Depth unavailable"
        }
    }
    
    static func from(distance: Float) -> DistanceQuality {
        if distance <= 0 { return .noDepth }
        if distance < 15 { return .tooClose }
        if distance <= 35 { return .optimal }
        if distance <= 50 { return .good }
        return .tooFar
    }
}

// MARK: - Capture Button
struct CaptureButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            if isEnabled { action() }
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 4)
                    .frame(width: 76, height: 76)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)
                
                // Inner fill
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
            }
        }
        .opacity(isEnabled ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
        .onChange(of: isEnabled) { newValue in
            isPulsing = newValue
        }
        .onAppear {
            isPulsing = isEnabled
        }
    }
}
