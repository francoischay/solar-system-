import SwiftUI

@main
struct SystemeSolaireApp: App {
    @StateObject private var engine = Engine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
                .persistentSystemOverlays(.hidden)
        }
    }
}
