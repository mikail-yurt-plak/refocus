#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity (Dynamic Island + kilit ekranı) veri modeli.
/// Hem uygulama hem widget uzantısı tarafından derlenir.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Aktif fazın duvar saatine göre bitişi
        var endDate: Date
        var isBreak: Bool
    }

    /// Seans boyunca sabit: metod adı
    var methodName: String
}
#endif
