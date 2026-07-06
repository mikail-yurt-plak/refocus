import Foundation
import SwiftUI

#if os(iOS)
import UIKit

/// Ekran yönelimini view bazında kontrol eden singleton
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    /// Yalnızca dikey mod
    func lockToPortrait() {
        allowedOrientations = .portrait
        rotateToPortrait()
    }

    /// Tüm yönelimler
    func unlockOrientation() {
        allowedOrientations = .allButUpsideDown
    }

    /// Cihazı dikey moda döndür
    private func rotateToPortrait() {
        if #available(iOS 16.0, *) {
            // iOS 16+ için
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            // iOS 15 ve altı için
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
}

#elseif os(macOS)
import AppKit

/// macOS için OrientationManager - ekran yönelimi kontrolü yok
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    private init() {}

    func lockToPortrait() {}
    func unlockOrientation() {}
}
#endif

/// View modifier - Portrait-only view için
struct PortraitOnlyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                OrientationManager.shared.lockToPortrait()
            }
    }
}

/// View modifier - Tüm yönelimleri destekleyen view için
struct AllOrientationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                OrientationManager.shared.unlockOrientation()
            }
            .onDisappear {
                OrientationManager.shared.lockToPortrait()
            }
    }
}

extension View {
    /// Bu view'ı yalnızca dikey modda göster
    func portraitOnly() -> some View {
        modifier(PortraitOnlyModifier())
    }

    /// Bu view tüm yönelimleri destekler
    func supportsAllOrientations() -> some View {
        modifier(AllOrientationsModifier())
    }
}
