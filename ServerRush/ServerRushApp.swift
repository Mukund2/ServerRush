import SwiftUI

@main
struct ServerRushApp: App {
    init() {
        // Set API keys for Chip guide character
        if UserDefaults.standard.string(forKey: "MISTRAL_API_KEY") == nil {
            UserDefaults.standard.set("mlCVTXaPPTVsbi7axFZHPo1gghc0Rc2T", forKey: "MISTRAL_API_KEY")
        }
        if UserDefaults.standard.string(forKey: "ELEVENLABS_API_KEY") == nil {
            UserDefaults.standard.set("d41358ecd43d46476f4c3448e234c525395bcb956bdc92d24ee1dc7c2d9b81d3", forKey: "ELEVENLABS_API_KEY")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
