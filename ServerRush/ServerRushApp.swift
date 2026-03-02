import SwiftUI

@main
struct ServerRushApp: App {
    init() {
        // Set Mistral API key for Chip guide character
        if UserDefaults.standard.string(forKey: "MISTRAL_API_KEY") == nil {
            UserDefaults.standard.set("mlCVTXaPPTVsbi7axFZHPo1gghc0Rc2T", forKey: "MISTRAL_API_KEY")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
