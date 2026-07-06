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
    static let focusGreen = Color(light: Color(hex: "#2E7D6F"), dark: Color(hex: "#4FA294"))

    /// Uygulama arka plan rengi - Açık gri-beyaz
    static let appBackground = Color(light: Color(hex: "#F6F8F7"), dark: Color(hex: "#121615"))

    /// Kart arka plan rengi - Beyaz
    static let cardBackground = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1E2422"))

    /// Mola ekranı rengi - Açık mavi (zemin rengi)
    static let breakBlue = Color(light: Color(hex: "#E8F1F8"), dark: Color(hex: "#16222C"))

    /// Mola vurgu rengi - metin/rakam için okunabilir mavi
    static let breakAccent = Color(light: Color(hex: "#4A7FA5"), dark: Color(hex: "#8FBEE0"))

    /// Nazik uyarı rengi - Açık sarı
    static let gentleWarning = Color(light: Color(hex: "#FFF4E5"), dark: Color(hex: "#33291A"))

    // MARK: - Semantic Colors

    /// Başarılı/Stabil durum - Yeşil
    static let statusStable = Color.green

    /// Dalgalı durum - Sarı
    static let statusFluctuating = Color.yellow

    /// Zor gün - Mavi (kırmızı yok!)
    static let statusTough = Color.blue

    // MARK: - Text Colors

    /// Ana metin rengi
    static let textPrimary = Color(light: Color(hex: "#1C1C1E"), dark: Color(hex: "#EDEFEE"))

    /// İkincil metin rengi
    static let textSecondary = Color(light: Color(hex: "#6B6B6B"), dark: Color(hex: "#A5ABA8"))

    /// Üçüncül metin rengi
    static let textTertiary = Color(light: Color(hex: "#999999"), dark: Color(hex: "#767C79"))

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
