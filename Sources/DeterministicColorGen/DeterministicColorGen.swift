import CryptoKit
import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif



public enum DeterministicColor {
    public enum InterfaceStyle {
        case light
        case dark
    }

    /// Generates dynamic fill and text colors that automatically adapt to the current light/dark mode.
    ///
    /// - Parameter string: The input string to generate colors from
    /// - Returns: A tuple containing the fill and text colors
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (fillColor, textColor) = DeterministicColor.uiSet(for: "Hello World!")
    ///
    /// Text("Hello World!")
    ///     .foregroundColor(textColor)
    ///     .background(fillColor)
    ///     .padding()
    /// ```
    public static func uiSet(_ string: String) -> (fillColor: Color, textColor: Color) {
        #if canImport(UIKit)
            let fillColor = Color(
                uiColor: UIColor { trait in
                    let isDark = (trait.userInterfaceStyle == .dark)
                    let out = generate(for: string, isDark: isDark)
                    return UIColor(
                        red: CGFloat(out.rgb.r), green: CGFloat(out.rgb.g),
                        blue: CGFloat(out.rgb.b), alpha: 1.0)
                })
            let textColor = Color(
                uiColor: UIColor { trait in
                    let isDark = (trait.userInterfaceStyle == .dark)
                    let out = generate(for: string, isDark: isDark)
                    return out.preferWhiteText ? UIColor.white : UIColor.black
                })
            return (fillColor, textColor)
        #elseif canImport(AppKit)
            let fillColor = Color(
                nsColor: NSColor(
                    name: NSColor.Name("DeterministicColor.Topic.bg.\(hashToken(string))"),
                    dynamicProvider: { appearance in
                        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        let out = generate(for: string, isDark: isDark)
                        return NSColor(
                            calibratedRed: CGFloat(out.rgb.r), green: CGFloat(out.rgb.g),
                            blue: CGFloat(out.rgb.b), alpha: 1.0)
                    }
                ))
            let textColor = Color(
                nsColor: NSColor(
                    name: NSColor.Name("DeterministicColor.Topic.fg.\(hashToken(string))"),
                    dynamicProvider: { appearance in
                        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        let out = generate(for: string, isDark: isDark)
                        return out.preferWhiteText ? NSColor.white : NSColor.black
                    }
                ))
            return (fillColor, textColor)
        #endif
    }

    /// Generates fill and text colors for a specific interface style.
    ///
    /// - Parameters:
    ///   - string: The input string to generate colors from
    ///   - style: The interface style to generate colors for
    /// - Returns: A tuple containing the fill and text colors
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (fillColor, textColor) = DeterministicColor.uiSet(for: "Hello World!", style: .light)
    ///
    /// Text("Hello World!")
    ///     .foregroundColor(textColor)
    ///     .background(fillColor)
    ///     .padding()
    /// ```
    public static func uiSet(_ string: String, style: InterfaceStyle) -> (fillColor: Color, textColor: Color) {
        let out = generate(for: string, isDark: style == .dark)
        let fillColor = Color(red: out.rgb.r, green: out.rgb.g, blue: out.rgb.b)
        let textColor = out.preferWhiteText ? Color.white : Color.black
        return (fillColor, textColor)
    }

    /// Generates a fill color.
    ///
    /// This method returns a fixed color that doesn't change based on the current
    /// system appearance.
    ///
    /// - Parameters:
    ///   - string: The input string to generate a color from
    ///   - style: The interface style to generate the color for (default: .light)
    /// - Returns: A SwiftUI `Color`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let lightBg = DeterministicColor.color(for: "Hello World!")
    /// let darkBg = DeterministicColor.color(for: "Hello World!", style: .dark)
    /// ```
    public static func color(_ string: String, style: InterfaceStyle = .light) -> Color {
        let out = generate(for: string, isDark: style == .dark)
        return Color(red: out.rgb.r, green: out.rgb.g, blue: out.rgb.b)
    }

    /// internal helper for testing; returns RGB values for a given string and style
    internal static func rgb(for string: String, style: InterfaceStyle) -> (Double, Double, Double) {
        let out = generate(for: string, isDark: style == .dark)
        return (out.rgb.r, out.rgb.g, out.rgb.b)
    }

    /// internal helper for testing; returns whether white text is preferred for a given string and style
    internal static func prefersWhiteText(for string: String, style: InterfaceStyle) -> Bool {
        generate(for: string, isDark: style == .dark).preferWhiteText
    }

    private struct LinRGB {
        var r: Double
        var g: Double
        var b: Double
    }
    
    private struct SRGB {
        var r: Double
        var g: Double
        var b: Double
    }

    private static func hashToken(_ s: String) -> String {
        let d = SHA256.hash(data: Data(s.utf8))
        return d.compactMap { String(format: "%02x", $0) }.prefix(12).joined()
    }

    private static func oklchToLinearSRGB(l: Double, c: Double, hDeg: Double) -> LinRGB {
        let h = hDeg * .pi / 180.0
        let a = cos(h) * c
        let b = sin(h) * c

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b

        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_

        let r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let b2 = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        return .init(r: r, g: g, b: b2)
    }

    private static func inGamut(_ c: LinRGB) -> Bool {
        let e = 1e-3
        return c.r >= -e && c.r <= 1 + e && c.g >= -e && c.g <= 1 + e && c.b >= -e && c.b <= 1 + e
    }

    private static func toSRGB(_ x: Double) -> Double {
        let x = max(0.0, min(1.0, x))
        return (x <= 0.0031308) ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
    }

    private static func toSRGB(_ c: LinRGB) -> SRGB {
        .init(r: toSRGB(c.r), g: toSRGB(c.g), b: toSRGB(c.b))
    }

    private static func relLumLinear(_ c: LinRGB) -> Double {
        let r = max(0.0, min(1.0, c.r))
        let g = max(0.0, min(1.0, c.g))
        let b = max(0.0, min(1.0, c.b))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func contrast(_ L1: Double, _ L2: Double) -> Double {
        let (a, b) = L1 >= L2 ? (L1, L2) : (L2, L1)
        return (a + 0.05) / (b + 0.05)
    }

    /// core generator; returns gamma-encoded sRGB and recommended white/black text
    private static func generate(for string: String, isDark: Bool) -> (
        rgb: SRGB, preferWhiteText: Bool
    ) {
        let digest = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(digest)
        func unit(_ i: Int) -> Double { Double(bytes[i]) / 255.0 }

        // hue with small jitter, wrapped to [0,360)
        let rawH = (unit(0) + unit(3) * 0.25) * 360.0
        let h = fmod(rawH, 360.0)

        // tasteful OKLCH ranges (vivid but not neon; avoid near-black/near-white)
        var C = 0.16 + unit(1) * 0.14  // 0.16…0.30
        var L = 0.50 + unit(2) * 0.18  // 0.50…0.68

        // subtle mode-aware nudge so tags don't vanish on bg
        if isDark { L = max(L, 0.56) } else { L = min(L, 0.70) }

        // gamut map: reduce C until inside linear sRGB
        var lin = oklchToLinearSRGB(l: L, c: C, hDeg: h)
        if !inGamut(lin) {
            var t = 0
            while t < 12 && !inGamut(lin) {
                C *= 0.92
                lin = oklchToLinearSRGB(l: L, c: C, hDeg: h)
                t += 1
            }
        }

        // enforce WCAG 4.5:1 against white/black by nudging L (regamut if needed)
        func remap(_ newL: Double, _ curC: Double) -> (Double, Double, LinRGB) {
            var L2 = newL
            var C2 = curC
            var lin2 = oklchToLinearSRGB(l: L2, c: C2, hDeg: h)
            if !inGamut(lin2) {
                var t = 0
                while t < 8 && !inGamut(lin2) {
                    C2 *= 0.95
                    lin2 = oklchToLinearSRGB(l: L2, c: C2, hDeg: h)
                    t += 1
                }
            }
            return (L2, C2, lin2)
        }

        let target: Double = 4.5
        var step = 0.02
        var i = 0
        while i < 16 {
            let Lbg = relLumLinear(lin)
            let cW = contrast(Lbg, 1.0)
            let cB = contrast(Lbg, 0.0)
            if max(cW, cB) >= target { break }
            if cW >= cB { L = max(0.42, L - step) } else { L = min(0.78, L + step) }
            (L, C, lin) = remap(L, C)
            i += 1
            step *= 0.9
        }

        let preferWhite = contrast(relLumLinear(lin), 1.0) >= contrast(relLumLinear(lin), 0.0)
        return (toSRGB(lin), preferWhite)
    }
}
