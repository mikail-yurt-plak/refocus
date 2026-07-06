#if os(iOS)
import UIKit

/// AppDelegate - Ekran yönelimi kontrolü için
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // OrientationManager'dan izin verilen yönelimleri al
        return OrientationManager.shared.allowedOrientations
    }
}
#elseif os(macOS)
import AppKit

/// AppDelegate - macOS için boş implementasyon
class AppDelegate: NSObject, NSApplicationDelegate {
    // macOS için ekran yönelimi kontrolü gerekmiyor
}
#endif
