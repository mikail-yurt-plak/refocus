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

    /// Önerilen başlangıç context'leri (onboarding'de gösterilecek, localized)
    static var suggestions: [WorkContext] {
        [
            WorkContext(name: String(localized: "workcontext.coding"), icon: "💻"),
            WorkContext(name: String(localized: "workcontext.reading"), icon: "📚"),
            WorkContext(name: String(localized: "workcontext.writing"), icon: "✍️"),
            WorkContext(name: String(localized: "workcontext.design"), icon: "🎨"),
            WorkContext(name: String(localized: "workcontext.research"), icon: "🔍"),
            WorkContext(name: String(localized: "workcontext.math"), icon: "🧮"),
            WorkContext(name: String(localized: "workcontext.language"), icon: "🌍"),
            WorkContext(name: String(localized: "workcontext.music"), icon: "🎵"),
            WorkContext(name: String(localized: "workcontext.video"), icon: "🎬"),
            WorkContext(name: String(localized: "workcontext.planning"), icon: "📋")
        ]
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
