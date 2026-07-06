import Foundation

/// Çalışma bağlamı - kullanıcının NE üzerinde çalıştığını temsil eder
/// Bu bir görev listesi değil, sadece anlam ve hafıza için bir etiket
struct WorkContext: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String  // Emoji veya SF Symbol adı
    var isDefault: Bool  // Varsayılan "Genel" context'i
    let createdAt: Date

    init(id: UUID = UUID(), name: String, icon: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDefault = isDefault
        self.createdAt = Date()
    }

    /// Varsayılan "Genel" context (localized)
    static var general: WorkContext {
        WorkContext(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: String(localized: "workcontext.general"),
            icon: "🎯",
            isDefault: true
        )
    }

    /// Önerilen başlangıç context'leri (onboarding'de gösterilecek, localized).
    /// ID'ler sabittir: her erişimde aynı kalmalı ki seçim durumu (ve
    /// kaydetme) doğru eşleşsin.
    static var suggestions: [WorkContext] {
        [
            suggestion(1, key: "workcontext.coding", icon: "💻"),
            suggestion(2, key: "workcontext.reading", icon: "📚"),
            suggestion(3, key: "workcontext.writing", icon: "✍️"),
            suggestion(4, key: "workcontext.design", icon: "🎨"),
            suggestion(5, key: "workcontext.research", icon: "🔍"),
            suggestion(6, key: "workcontext.math", icon: "🧮"),
            suggestion(7, key: "workcontext.language", icon: "🌍"),
            suggestion(8, key: "workcontext.music", icon: "🎵"),
            suggestion(9, key: "workcontext.video", icon: "🎬"),
            suggestion(10, key: "workcontext.planning", icon: "📋")
        ]
    }

    private static func suggestion(_ index: Int, key: String.LocalizationValue, icon: String) -> WorkContext {
        WorkContext(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 100 + index))!,
            name: String(localized: key),
            icon: icon
        )
    }

    /// Icon önerileri (kullanıcı yeni context eklerken)
    static let iconSuggestions: [String] = [
        "📚", "💻", "✍️", "🎨", "🔍", "🧮", "🌍", "🎵", "🎬", "📋",
        "📖", "🎯", "💡", "🧠", "📝", "🎮", "🏋️", "🧘", "📊", "🔬",
        "🎸", "📷", "🎤", "🎧", "🖌️", "✂️", "🔧", "⚙️", "🌱", "☕",
        "🖥️", "📱", "🎹", "🎻", "🎺", "🥁", "🎭", "🎪", "🎲", "🃏",
        "⚽", "🏀", "🎾", "🏊", "🚴", "🧗", "🏃", "🤸", "🧩", "🎳"
    ]
}

/// Popüler emoji kategorileri için gruplandırma
struct IconCategory: Identifiable {
    let id = UUID()
    let name: String
    let icons: [String]

    static var categories: [IconCategory] {
        [
            IconCategory(name: String(localized: "workcontext.category.work"), icons: [
                "💻", "🖥️", "📱", "⌨️", "🖱️",
                "📚", "📖", "📝", "✍️", "📋",
                "📊", "📈", "📉", "🗂️", "📁",
                "🔍", "💡", "📌", "📎", "✏️"
            ]),
            IconCategory(name: String(localized: "workcontext.category.creativity"), icons: [
                "🎨", "🖌️", "🖍️", "✂️", "🎭",
                "🎬", "📷", "📸", "🎥", "📹",
                "🎵", "🎶", "🎤", "🎧", "🎹",
                "🎸", "🎻", "🎺", "🥁", "🎼"
            ]),
            IconCategory(name: String(localized: "workcontext.category.learning"), icons: [
                "🧠", "🎓", "📐", "📏", "🧮",
                "🔬", "🔭", "🧪", "🧬", "⚗️",
                "🌍", "🌎", "🌏", "🗺️", "📜",
                "📰", "🗞️", "💬", "🗣️", "👁️"
            ]),
            IconCategory(name: String(localized: "workcontext.category.sports"), icons: [
                "🏋️", "🧘", "🏃", "🚴", "🏊",
                "⚽", "🏀", "🎾", "🏓", "🏸",
                "🧗", "🤸", "🤾", "🏇", "⛹️",
                "🥋", "🥊", "🤼", "🏌️", "🎿"
            ]),
            IconCategory(name: String(localized: "workcontext.category.life"), icons: [
                "🎯", "🏠", "🏡", "🛋️", "🛏️",
                "☕", "🍵", "🥤", "🍽️", "🍳",
                "🌱", "🌿", "🌻", "🌸", "🌺",
                "🧹", "🧺", "🧼", "🛁", "🚿"
            ]),
            IconCategory(name: String(localized: "workcontext.category.entertainment"), icons: [
                "🎮", "🕹️", "🎲", "🎯", "🃏",
                "🧩", "🎪", "🎡", "🎢", "🎠",
                "📺", "📻", "🎙️", "🎚️", "🎛️",
                "🎳", "🎰", "🎴", "🀄", "♟️"
            ]),
            IconCategory(name: String(localized: "workcontext.category.technology"), icons: [
                "⚙️", "🔧", "🔨", "🛠️", "⛏️",
                "🔩", "🔗", "⛓️", "🧲", "🔌",
                "💾", "💿", "📀", "🖨️", "🖲️",
                "📡", "🛰️", "🔋", "🔦", "💎"
            ]),
            IconCategory(name: String(localized: "workcontext.category.finance"), icons: [
                "💰", "💵", "💴", "💶", "💷",
                "💳", "💸", "🏦", "🏧", "💹",
                "📈", "📉", "🧾", "🧮", "🏷️",
                "💼", "🗄️", "📊", "📋", "🔢"
            ]),
            IconCategory(name: String(localized: "workcontext.category.communication"), icons: [
                "📧", "📨", "📩", "📤", "📥",
                "📫", "📬", "📭", "📮", "📯",
                "📞", "📱", "☎️", "📲", "📟",
                "💬", "💭", "🗨️", "🗯️", "✉️"
            ]),
            IconCategory(name: String(localized: "workcontext.category.nature"), icons: [
                "🌲", "🌳", "🌴", "🌵", "🌾",
                "🏔️", "⛰️", "🌋", "🏕️", "🏖️",
                "✈️", "🚀", "🚁", "🚂", "🚗",
                "🗻", "🏝️", "🌅", "🌄", "🌠"
            ])
        ]
    }
}
