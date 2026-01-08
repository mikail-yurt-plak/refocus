import SwiftUI

/// ReFocus tipografi sistemi
/// SF Pro (iOS native) kullanır
extension Font {
    // MARK: - Display (Timer, büyük sayılar)

    static let timerLarge = Font.system(size: 72, weight: .semibold, design: .rounded)
    static let timerMedium = Font.system(size: 48, weight: .medium, design: .rounded)

    // MARK: - Headings

    static let heading1 = Font.system(size: 32, weight: .semibold)
    static let heading2 = Font.system(size: 24, weight: .semibold)
    static let heading3 = Font.system(size: 20, weight: .semibold)

    // MARK: - Body

    static let bodyLarge = Font.system(size: 18, weight: .regular)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)

    // MARK: - Caption

    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)

    // MARK: - Button

    static let buttonLarge = Font.system(size: 18, weight: .semibold)
    static let button = Font.system(size: 16, weight: .semibold)
}

/// Text stilleri için yardımcı modifier'lar
extension Text {
    func heading1Style() -> some View {
        self
            .font(.heading1)
            .foregroundColor(.textPrimary)
    }

    func heading2Style() -> some View {
        self
            .font(.heading2)
            .foregroundColor(.textPrimary)
    }

    func bodyStyle() -> some View {
        self
            .font(.body)
            .foregroundColor(.textPrimary)
            .lineSpacing(4)
    }

    func captionStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(.textSecondary)
    }

    func gentleMessageStyle() -> some View {
        self
            .font(.bodyLarge)
            .foregroundColor(.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
    }
}
