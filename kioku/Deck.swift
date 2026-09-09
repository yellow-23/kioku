#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Type

/// Yomogi es la letra de la casa: se usa en los tabs, en las tarjetas y en el editor.
enum Ink {
    static let face = "Yomogi-Regular"

    static let tabSize: CGFloat = 10.5
    static let tabTracking: CGFloat = 0.3

    static var tabNSFont: NSFont {
        NSFont(name: face, size: tabSize) ?? .systemFont(ofSize: tabSize - 0.5, weight: .semibold)
    }
    static var tabFont: Font {
        NSFont(name: face, size: tabSize) != nil
            ? .custom(face, size: tabSize)
            : .system(size: tabSize - 0.5, weight: .semibold)
    }
    static func body(_ size: CGFloat) -> Font {
        NSFont(name: face, size: size) != nil ? .custom(face, size: size) : .system(size: size)
    }
}

// MARK: - Geometría del deck

struct DeckLayout {
    var itemHeight: CGFloat     // alto completo de un tab
    var pitch: CGFloat          // separación entre topes; menor que itemHeight = solapan
    var count: Int
    var panelHeight: CGFloat

    /// Negativo: es el spacing del VStack que produce el solape.
    var spacing: CGFloat { pitch - itemHeight }

    var stackHeight: CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count - 1) * pitch + itemHeight + DeckGeom.plusGap + DeckGeom.plusSize
    }

    var cap: CGFloat { max(140, panelHeight - 76) }
    var overflows: Bool { stackHeight > cap }
}

enum DeckGeom {
    // Reposo: la píldora de rayitas de color
    static let pillWidth: CGFloat = 12
    static let dashHeight: CGFloat = 14
    static let dashWidth: CGFloat = 7
    static let dashGap: CGFloat = 5
    static let pillPad: CGFloat = 7
    static let maxDashes = 14

    // Abanico
    static let tabWidth: CGFloat = 30
    /// Cuánto tapa cada tab al anterior.
    static let tabLap: CGFloat = 40
    static let pitchMin: CGFloat = 56
    static let pitchMax: CGFloat = 106
    static let pitchFloor: CGFloat = 36
    /// La franja visible es la etiqueta más esto; la etiqueta se dibuja con labelInset
    /// adentro. Igualarlos trunca la última letra por redondeo.
    static let labelPad: CGFloat = 20
    static let labelInset: CGFloat = 12
    /// Tabs y notas sangran un poco fuera de pantalla para que la inclinación no
    /// abra una cuña de fondo contra el borde.
    static let bleed: CGFloat = 14

    static let leanDegrees: Double = -3.0
    static let plusSize: CGFloat = 28
    static let plusGap: CGFloat = 12
    static let fanWidth: CGFloat = 50
    // Expandido: la nota se despega del deck llevándose su tab como canaleta
    static let gutterWidth: CGFloat = tabWidth
    static let editorWidth: CGFloat = 280
    static let editorHeight: CGFloat = 300
    /// Ancho del panel abierto: la nota entera más aire para la sombra.
    static let panelWidth: CGFloat = editorWidth + gutterWidth + 30
    /// Ancho de la franja detectora en reposo.
    static let edgeWidth: CGFloat = 16

    static let heightBudget: CGFloat = 0.68

    private static var labelCache: [String: CGFloat] = [:]

    /// Ancho renderizado de la etiqueta, con la misma fuente que dibuja el tab.
    static func labelWidth(_ title: String) -> CGFloat {
        let text = title.uppercased() as NSString
        guard text.length > 0 else { return 0 }
        let font = tabNSFontCached
        let key = "\(font.pointSize)|\(text)"
        if let hit = labelCache[key] { return hit }
        let w = text.size(withAttributes: [.font: font]).width + tabTrackingTotal(text.length)
        if labelCache.count > 400 { labelCache.removeAll(keepingCapacity: true) }
        labelCache[key] = w
        return w
    }

    private static let tabNSFontCached = Ink.tabNSFont
    private static func tabTrackingTotal(_ n: Int) -> CGFloat { Ink.tabTracking * CGFloat(n) }

    static func pillHeight(noteCount: Int) -> CGFloat {
        let shown = min(noteCount, maxDashes)
        let n = max(1, shown + (noteCount > maxDashes ? 1 : 0))
        return pillPad * 2 + CGFloat(n) * dashHeight + CGFloat(n - 1) * dashGap
    }

    static func layout(panelHeight: CGFloat, count: Int, longestLabel: CGFloat) -> DeckLayout {
        let n = max(1, count)
        var pitch = min(pitchMax, max(pitchMin, longestLabel + labelPad))
        let budget = panelHeight * heightBudget
        if CGFloat(n) * pitch + tabLap > budget {
            pitch = max(pitchFloor, (budget - tabLap) / CGFloat(n))
        }
        return DeckLayout(itemHeight: pitch + tabLap, pitch: pitch, count: n, panelHeight: panelHeight)
    }
}

/// Redondeado sólo del lado que mira hacia adentro, así el tab se lee pegado al borde.
func edgeTabShape(radius r: CGFloat = 11) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r,
                           bottomTrailingRadius: 0, topTrailingRadius: 0,
                           style: .continuous)
}
#endif
