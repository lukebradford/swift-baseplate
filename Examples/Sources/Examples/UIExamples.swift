#if canImport(UIKit)
import BaseplateLifecycle
import BaseplateUI
import SwiftUI

/// Referenced from `main.swift` so these iOS-only examples are type-checked in CI.
let uiExamplesAreCompiled = true

/// A tour of `BaseplateUI` — SwiftUI ergonomics & design-system primitives.
struct UIExamplesView: View {
    @State private var error: Error?

    var body: some View {
        VStack {
            // Fixed point size that still honors Dynamic Type.
            Text("Score")
                .scaledFont(size: 28, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color(hex: "#1E90FF") ?? .blue)  // hex init
                .background(Color.adaptive(light: .white, dark: .black))  // light/dark in one call

            // One shared portfolio list drives every app's cross-promo shelf.
            CrossPromoShelf(apps: LukePortfolio.all) { app in
                // open App Store for `app`
                _ = app.appStoreID
            }
        }
        .errorAlert($error)  // present any thrown Error as an alert
    }
}

@MainActor
func uiValueExamples() {
    // Persist a user color losslessly.
    let components = ColorComponents(red: 0.2, green: 0.5, blue: 1, alpha: 1)
    _ = components.hexString
    _ = components.color

    // Haptics with a user-facing on/off toggle.
    let haptics = Haptics(
        preference: HapticsPreference(defaults: UserDefaults(suiteName: "ex.ui")!))
    haptics.impact(.light)

    // Render any SwiftUI view to a shareable image.
    _ = UIExamplesView().exportedAsImage(scale: 3)
}
#endif
