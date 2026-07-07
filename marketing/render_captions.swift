// App Store ekran görüntüsü başlıklarını render eder.
// Sistem fontu (SF Pro + betik bazlı otomatik yedekler) kullandığı için
// Arapça, Hintçe, Tayca, CJK dahil 20 dilin tamamını doğru şekillendirir.
//
// Kullanım: swift render_captions.swift <jobs.json>
// jobs.json: [{"text": "...", "out": "path.png", "width": 1100,
//              "size": 72, "color": "#1C1C1E", "weight": "bold",
//              "align": "center"}]

import AppKit
import Foundation

struct Job: Decodable {
    let text: String
    let out: String
    let width: CGFloat
    let size: CGFloat
    let color: String
    let weight: String
    let align: String?
}

func nsColor(hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
    return NSColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

func fontWeight(_ name: String) -> NSFont.Weight {
    switch name {
    case "bold": return .bold
    case "semibold": return .semibold
    case "medium": return .medium
    default: return .regular
    }
}

let jobsURL = URL(fileURLWithPath: CommandLine.arguments[1])
let jobs = try! JSONDecoder().decode([Job].self, from: Data(contentsOf: jobsURL))

for job in jobs {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = job.align == "left" ? .left : .center
    paragraph.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: job.size, weight: fontWeight(job.weight)),
        .foregroundColor: nsColor(hex: job.color),
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: job.text, attributes: attributes)

    let bounds = attributed.boundingRect(
        with: NSSize(width: job.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let height = ceil(bounds.height) + 8

    let image = NSImage(size: NSSize(width: job.width, height: height))
    image.lockFocus()
    attributed.draw(
        with: NSRect(x: 0, y: 4, width: job.width, height: height - 8),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("render failed: \(job.text)")
    }
    try! png.write(to: URL(fileURLWithPath: job.out))
    print("ok: \(job.out)")
}
