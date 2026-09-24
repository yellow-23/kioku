import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Un color de nota son tres tonos: el papel, la rayita saturada del borde y la tinta.
struct NoteColor {
    let hex: String     // papel, y el valor que se guarda en Note.colorHex
    let dashHex: String
    let inkHex: String

    var paper: Color { Color(hex: hex) }
    var dash: Color { Color(hex: dashHex) }
    var ink: Color { Color(hex: inkHex) }
}

enum NoteColors {
    static let all: [NoteColor] = [
        NoteColor(hex: "#FCE795", dashHex: "#E0AD08", inkHex: "#3A3008"),
        NoteColor(hex: "#FBCFA6", dashHex: "#E2762A", inkHex: "#422413"),
        NoteColor(hex: "#FAC4D1", dashHex: "#DC4570", inkHex: "#40161F"),
        NoteColor(hex: "#D9C7FA", dashHex: "#7C4DEE", inkHex: "#2A1B44"),
        NoteColor(hex: "#BEDDFA", dashHex: "#2280D6", inkHex: "#13293A"),
        NoteColor(hex: "#B4E8D0", dashHex: "#0E9B6E", inkHex: "#0F2E23"),
        NoteColor(hex: "#E3D3B4", dashHex: "#A37B3C", inkHex: "#372C18"),
        NoteColor(hex: "#CBD6E2", dashHex: "#4E6579", inkHex: "#1A242E"),
    ]

    static let palette: [String] = all.map(\.hex)

    static func at(_ hex: String) -> NoteColor {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame } ?? all[0]
    }
}

extension Note {
    var palette: NoteColor { NoteColors.at(colorHex) }

    /// Título para los tabs y listas: el propio, o la primera línea del cuerpo.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let line = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let clean = line.trimmingCharacters(in: .whitespaces)
        if clean.isEmpty { return "Sin título" }
        return clean.count > 60 ? String(clean.prefix(60)) + "…" : clean
    }
}

#if os(macOS)
import AppKit

/// El escritorio donde viven las notas: washi cálido en modo claro, sumi en oscuro.
/// El único color fuerte es el bermellón del hanko.
enum Washi {
    static let desk = adaptive(light: "#EFE8DC", dark: "#1D1A17")
    static let deskRaised = adaptive(light: "#E6DDCE", dark: "#26221E")
    static let ink = adaptive(light: "#2A2420", dark: "#E9E1D3")
    static let inkSoft = adaptive(light: "#7A6E62", dark: "#948A7C")
    static let rule = adaptive(light: "#D5CAB8", dark: "#35302A")
    static let shu = Color(hex: "#C8402A")      // bermellón, sólo para el sello
    static let shuInk = Color(hex: "#FBEFE6")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(Color(hex: dark)) : NSColor(Color(hex: light))
        })
    }
}
#endif
