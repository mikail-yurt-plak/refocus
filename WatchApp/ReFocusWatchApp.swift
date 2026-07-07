import SwiftUI

/// ReFocus Apple Watch uygulaması.
/// iPhone'daki seansın uzaktan kumandası ve canlı sayacıdır:
/// durum WatchConnectivity ile gelir, geri sayım duvar saatinden hesaplanır.
@main
struct ReFocusWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchSessionView()
        }
    }
}
