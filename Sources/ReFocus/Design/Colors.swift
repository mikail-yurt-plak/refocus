import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// ReFocus renk paleti
/// Sakin, minimal ve rahatlatıcı bir deneyim için tasarlandı
extension Color {
    // MARK: - Primary Colors

    /// Ana tema rengi - Odak Yeşili
    static let focusGreen = Color(hex: "#2E7D6F")

    /// Uygulama arka plan rengi - Açık gri-beyaz
    static let appBackground = Color(hex: "#F6F8F7")

    /// Kart arka plan rengi - Beyaz
    static let cardBackground = Color(hex: "#FFFFFF")

    /// Mola ekranı rengi - Açık mavi
    static let breakBlue = Color(hex: "#E8F1F8")

    /// Nazik uyarı rengi - Açık sarı
    static let gentleWarning = Color(hex: "#FFF4E5")

    // MARK: - Semantic Colors

    /// Başarılı/Stabil durum - Yeşil
    static let statusStable = Color.green

    /// Dalgalı durum - Sarı
    static let statusFluctuating = Color.yellow

    /// Zor gün - Mavi (kırmızı yok!)
    static let statusTough = Color.blue

    // MARK: - Text Colors

    /// Ana metin rengi - koyu gri (light mode için optimize)
    static let textPrimary = Color(hex: "#1C1C1E")

    /// İkincil metin rengi
    static let textSecondary = Color(hex: "#6B6B6B")

    /// Üçüncül metin rengi
    static let textTertiary = Color(hex: "#999999")

    // MARK: - Helper

    /// Light/Dark mode için farklı renk tanımlar
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(dark)
                : NSColor(light)
        })
        #endif
    }

    /// Hex string'den Color oluşturur
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Cross-Platform Navigation Modifiers

extension View {
    /// Cross-platform navigation bar title display mode (inline)
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Cross-platform large navigation title
    @ViewBuilder
    func largeNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }
}

// MARK: - Cross-Platform Toolbar Placement

extension ToolbarItemPlacement {
    /// Cross-platform trailing placement
    static var topBarTrailingCompat: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }

    /// Cross-platform leading placement
    static var topBarLeadingCompat: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }
}
