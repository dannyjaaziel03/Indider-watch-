import SwiftUI

@main
struct SolanaInsiderWatchApp: App {
    @StateObject private var monitor = TokenMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
    }
}
