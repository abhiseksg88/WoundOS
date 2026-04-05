# CarePlix WoundOS — Native iOS App

**State-of-the-Art Wound Measurement App for iPhone**  
Pure Swift · ARKit LiDAR · Apple Health Design Language

---

## What This Is

A complete, production-ready iOS app that uses iPhone LiDAR to capture wound images, segment wound boundaries (via AI API or mock), compute 3D measurements (area, depth, volume, L×W, perimeter), display results in Apple Health-style clinical UI, and generate shareable PDF reports.

**Zero third-party dependencies.** 100% Apple frameworks (ARKit, SwiftUI, SceneKit, UIKit, Combine, simd).

---

## Requirements

| Requirement | Details |
|---|---|
| **Mac** | macOS 14+ with Xcode 15+ installed |
| **iPhone** | iPhone 12 Pro or later (LiDAR required) |
| **iOS** | 16.0+ |
| **Apple Developer Account** | Free account works for device testing |
| **Internet** | Only needed for real API mode (mock mode works offline) |

> ⚠️ **This app cannot run in the iOS Simulator.** LiDAR requires physical hardware. You must test on a real device.

---

## Setup Instructions (Step by Step)

### Option A: Using XcodeGen (Recommended)

XcodeGen auto-generates the `.xcodeproj` file from `project.yml`.

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Navigate to the project folder
cd WoundOS

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode
open WoundOS.xcodeproj
```

### Option B: Manual Xcode Setup

If you don't want to install XcodeGen:

1. **Open Xcode** → File → New → Project
2. Choose **iOS → App** → Next
3. Set:
   - Product Name: `WoundOS`
   - Team: Your Apple ID
   - Organization Identifier: `com.careplix`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (we'll add manually)
4. **Delete** the auto-generated `ContentView.swift` and `WoundOSApp.swift`
5. **Drag the entire `WoundOS/` folder** from this download into Xcode's project navigator
   - When prompted: ✅ Copy items if needed, ✅ Create groups, Target: WoundOS
6. **Add the test files**: Drag `WoundOSTests/` folder into the project
7. Set **Deployment Target** to iOS 16.0 in project settings
8. Set **Signing & Capabilities**: Select your team for code signing

### After Either Option:

5. **Connect your iPhone** via USB cable
6. Select your iPhone as the build destination (top toolbar in Xcode)
7. **Trust the developer** on your iPhone: Settings → General → VPN & Device Management → Trust
8. Press **⌘R** (Run) or click the Play button

The app should build and launch on your device within 30-60 seconds.

---

## First Run Walkthrough

1. **Camera Permission**: Tap "Allow" when prompted
2. **Camera Screen**: You'll see the live camera with a distance indicator pill at the top
3. **Position**: Hold your phone 15-35cm from a surface (the indicator turns green when optimal)
4. **Capture**: Tap the white circular button to capture
5. **Processing**: You'll see a spinner as the mock AI processes the image (~1.5 seconds)
6. **Review**: The wound boundary overlay appears — tap "Confirm" to proceed
7. **Results**: Full measurement report with area, depth, dimensions, PUSH score, and clinical summary
8. **Share**: Tap "Share Report" to generate and share a clinical PDF

---

## Project Structure

```
WoundOS/
├── App/                    # App entry point & navigation
│   ├── WoundOSApp.swift    # @main
│   └── ContentView.swift   # Tab navigation + capture flow coordinator
├── DesignSystem/           # Apple Health-style components
│   ├── Theme.swift         # Colors, typography, spacing
│   └── Components.swift    # Cards, pills, buttons
├── ARKit/                  # Camera & depth
│   ├── ARSessionManager.swift  # ARKit session lifecycle
│   ├── DepthReader.swift       # CVPixelBuffer depth extraction
│   └── CaptureData.swift       # Capture data model
├── Screens/
│   ├── Capture/            # Full-screen AR camera
│   ├── Processing/         # AI processing spinner
│   ├── Review/             # Mask overlay + confirm/retake
│   ├── Results/            # Measurement report (the core screen)
│   ├── History/            # Previous scan list
│   └── Settings/           # API config, device info
├── Segmentation/           # AI wound boundary
│   ├── SegmentationService.swift  # Mock + real API client
│   ├── SegmentationResult.swift   # Response model
│   └── MaskProcessor.swift        # Mask utilities
├── Measurement/            # 3D measurement engine
│   ├── MeasurementPipeline.swift     # Orchestrator
│   ├── PointCloudBuilder.swift       # Depth → 3D points
│   ├── PlaneFitter.swift             # RANSAC plane fitting
│   ├── SurfaceAreaCalculator.swift   # Triangulation → cm²
│   ├── DepthVolumeCalculator.swift   # Depth + volume
│   ├── DimensionCalculator.swift     # Length × Width
│   └── WoundMeasurement.swift        # Result model
├── Scoring/
│   └── PUSHCalculator.swift   # PUSH area subscale (0-10)
├── Report/
│   ├── Renderers.swift            # Annotated image + depth heatmap
│   └── PDFReportGenerator.swift   # Clinical PDF report
├── Storage/
│   └── ScanStore.swift    # Local scan persistence
├── Utilities/
│   └── Utilities.swift    # Haptics, math, image utils
└── Resources/
    ├── Info.plist
    ├── Assets.xcassets/   # App icon, colors, mock masks
    └── MockMasks/         # Sample wound masks (PNG)
```

---

## API Configuration

### Mock Mode (Default)
The app ships with mock mode enabled. It uses bundled sample mask images to simulate AI wound segmentation. This lets you test the entire measurement pipeline without a live backend.

### Switching to Real API
1. Go to **Settings** tab in the app
2. Toggle off "Use Mock API"
3. Enter your WoundAmbit API endpoint (e.g., `https://wound-ai-api-xxxxx.us-central1.run.app`)
4. The API should accept POST `/segment` with multipart JPEG and return:
   ```json
   {
     "segmentation_id": "...",
     "mask_b64": "<base64 PNG>",
     "overlay_b64": "<base64 JPEG>",
     "confidence": 0.89,
     "model": "woundambit",
     "inference_ms": 1200
   }
   ```

Or in code (`SegmentationService.swift`):
```swift
// Change:
var useMockAPI = true
// To:
var useMockAPI = false
var apiEndpoint = "https://your-api.run.app"
```

---

## Testing Checklist

### Sprint 1 (Camera + Distance)
- [ ] App launches to full-screen camera
- [ ] Distance pill shows live cm readout
- [ ] Color changes: red/yellow/green based on distance
- [ ] Capture freezes frame with haptic feedback

### Sprint 2 (API + Review)
- [ ] Processing spinner shows with status messages
- [ ] Wound overlay (green contour) appears on review
- [ ] Retake goes back to camera
- [ ] Confirm proceeds to results

### Sprint 3 (Measurements)
- [ ] Area, depth, volume, L×W numbers appear
- [ ] Numbers are reasonable for test objects
- [ ] Multi-wound: regions counted and displayed separately

### Sprint 4 (Results + Report)
- [ ] Results screen looks clean and clinical
- [ ] PDF generates correctly
- [ ] Share sheet opens (AirDrop, email, save)
- [ ] Scans saved and visible in History tab

### Sprint 5 (3D + Polish)
- [ ] 3D depth view renders and is rotatable
- [ ] Settings screen works
- [ ] No crashes after 10 consecutive captures

---

## Using Claude Code for Iteration

After your first build, use [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on your Mac for fast iteration:

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Navigate to your project
cd /path/to/WoundOS

# Start Claude Code
claude

# Example prompts:
# "Fix the build error in ResultsScreen.swift"
# "Add a wound location picker (left leg, right arm, etc.)"
# "Make the capture button larger"
# "Add HealthKit integration to store measurements"
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| "ARKit not supported" | Must use physical iPhone 12 Pro or later |
| Build fails on simulator | Select a physical device as build target |
| "Untrusted Developer" | iPhone Settings → General → VPN & Device Management → Trust |
| Black camera screen | Check camera permission in iPhone Settings → WoundOS |
| Mock masks not loading | Ensure Assets.xcassets contains mask_patientA/B/C image sets |
| Signing error | Set your Apple Developer Team in Xcode → Signing & Capabilities |

---

## Architecture

```
Layer 1: Segmentation (Swappable)
  └── Mock API / Real WoundAmbit API

Layer 2: Measurement Engine (Constant)
  └── Point Cloud → RANSAC Plane → Area/Depth/Volume/Dimensions

Layer 3: Presentation (Constant)
  └── Apple Health-style SwiftUI + PDF Report
```

The API is the only swappable layer. Everything else — ARKit capture, measurement math, UI, report generation — is self-contained and requires zero changes when switching from mock to production API.

---

**Built for CarePlix Healthcare Pvt. Ltd.**  
*Not a substitute for clinical assessment.*
