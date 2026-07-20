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

    /// The hue-aware OKLCH coordinates derived from an input before any
    /// interface-style adjustment. The normalized positions preserve the raw
    /// hash axes for stratified tests and previews.
    internal struct GenerationParameters {
        let sourceHue: Double
        let hue: Double
        let chroma: Double
        let lightness: Double
        let chromaFraction: Double
        let chromaPosition: Double
        let huePosition: Double
        let lightnessPosition: Double
    }

    internal static func generationParameters(for string: String) -> GenerationParameters {
        let digest = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(digest)
        func unit(_ index: Int) -> Double { Double(bytes[index]) / 255.0 }

        let sourceHue = fmod((unit(0) + unit(3) * 0.25) * 360.0, 360.0)
        let hue = paletteHue(for: sourceHue)
        let chromaPosition = unit(1)
        let lightnessPosition = unit(2)
        let lightnessRange = lightnessRange(forHue: hue)
        let lightness = lightnessRange.lowerBound
            + lightnessPosition * (lightnessRange.upperBound - lightnessRange.lowerBound)
        let chromaFraction = 0.96 + chromaPosition * 0.03
        let chroma = maximumInGamutChroma(lightness: lightness, hue: hue) * chromaFraction

        return GenerationParameters(
            sourceHue: sourceHue,
            hue: hue,
            chroma: chroma,
            lightness: lightness,
            chromaFraction: chromaFraction,
            chromaPosition: chromaPosition,
            huePosition: sourceHue / 360.0,
            lightnessPosition: lightnessPosition
        )
    }

    /// Removes hue intervals that produce rusty orange and muddy olive colors
    /// in sRGB. Source hues still remain deterministic, but are redistributed
    /// into curated red-orange and clean gold/yellow arcs.
    internal static func paletteHue(for sourceHue: Double) -> Double {
        switch sourceHue {
        case 40..<75:
            return 34 + smoothProgress(sourceHue, from: 40, to: 75) * 5
        case 75..<98:
            return 88 + smoothProgress(sourceHue, from: 75, to: 98) * 12
        case 98..<140:
            return 135 + smoothProgress(sourceHue, from: 98, to: 140) * 20
        default:
            return sourceHue
        }
    }

    /// A smooth palette envelope. Warm hues need substantially more lightness
    /// than blues and reds to read as vivid rather than brown, mustard, or olive.
    internal static func lightnessRange(forHue hue: Double) -> ClosedRange<Double> {
        let controlPoints: [(hue: Double, lower: Double, upper: Double)] = [
            (0, 0.54, 0.67),
            (30, 0.56, 0.66),
            (40, 0.58, 0.67),
            (75, 0.66, 0.74),
            (88, 0.79, 0.82),
            (100, 0.80, 0.84),
            (135, 0.58, 0.67),
            (155, 0.57, 0.65),
            (160, 0.58, 0.67),
            (190, 0.58, 0.71),
            (220, 0.55, 0.69),
            (260, 0.53, 0.67),
            (300, 0.54, 0.68),
            (330, 0.55, 0.69),
            (360, 0.54, 0.68)
        ]
        let wrappedHue = hue.truncatingRemainder(dividingBy: 360) + (hue < 0 ? 360 : 0)

        for (start, end) in zip(controlPoints, controlPoints.dropFirst())
            where wrappedHue >= start.hue && wrappedHue <= end.hue
        {
            let progress = smoothProgress(wrappedHue, from: start.hue, to: end.hue)
            let lower = start.lower + progress * (end.lower - start.lower)
            let upper = start.upper + progress * (end.upper - start.upper)
            return lower...upper
        }

        return 0.54...0.68
    }

    /// A richer dark-mode envelope. It keeps warm and green hues high enough to
    /// avoid brown, mustard, and olive while letting cooler hues sit deeper.
    internal static func darkLightnessRange(forHue hue: Double) -> ClosedRange<Double> {
        let controlPoints: [(hue: Double, lower: Double, upper: Double)] = [
            (0, 0.48, 0.60),
            (30, 0.50, 0.60),
            (40, 0.51, 0.61),
            (75, 0.58, 0.66),
            (88, 0.64, 0.70),
            (100, 0.65, 0.71),
            (135, 0.52, 0.63),
            (155, 0.51, 0.62),
            (160, 0.50, 0.62),
            (190, 0.50, 0.63),
            (220, 0.49, 0.62),
            (260, 0.48, 0.61),
            (300, 0.49, 0.62),
            (330, 0.49, 0.62),
            (360, 0.48, 0.60)
        ]
        let wrappedHue = hue.truncatingRemainder(dividingBy: 360) + (hue < 0 ? 360 : 0)

        for (start, end) in zip(controlPoints, controlPoints.dropFirst())
            where wrappedHue >= start.hue && wrappedHue <= end.hue
        {
            let progress = smoothProgress(wrappedHue, from: start.hue, to: end.hue)
            let lower = start.lower + progress * (end.lower - start.lower)
            let upper = start.upper + progress * (end.upper - start.upper)
            return lower...upper
        }

        return 0.48...0.62
    }

    private static func smoothProgress(_ value: Double, from lower: Double, to upper: Double) -> Double {
        let linearProgress = (value - lower) / (upper - lower)
        return linearProgress * linearProgress * (3 - 2 * linearProgress)
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

    /// Finds the actual sRGB chroma boundary for this lightness and hue. Using
    /// a fraction of this value yields consistent vividness without repeatedly
    /// crushing out-of-gamut colors into the same muddy boundary color.
    private static func maximumInGamutChroma(lightness: Double, hue: Double) -> Double {
        var lower = 0.0
        var upper = 0.4

        for _ in 0..<20 {
            let candidate = (lower + upper) / 2
            let rgb = oklchToLinearSRGB(l: lightness, c: candidate, hDeg: hue)
            let isStrictlyInGamut = rgb.r >= 0 && rgb.r <= 1
                && rgb.g >= 0 && rgb.g <= 1
                && rgb.b >= 0 && rgb.b <= 1
            if isStrictlyInGamut {
                lower = candidate
            } else {
                upper = candidate
            }
        }

        return lower
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

    /// Prefer white throughout the entire range where it independently meets
    /// WCAG AA. This moves the visual crossover slightly lighter than simply
    /// choosing whichever of black or white has the larger ratio.
    internal static func shouldUseWhiteText(relativeLuminance: Double) -> Bool {
        contrast(relativeLuminance, 1.0) >= 4.5
    }

    /// core generator; returns gamma-encoded sRGB and recommended white/black text
    private static func generate(for string: String, isDark: Bool) -> (
        rgb: SRGB, preferWhiteText: Bool
    ) {
        let parameters = generationParameters(for: string)
        let h = parameters.hue
        var C = parameters.chroma
        var L = parameters.lightness

        // Dark mode uses its own deeper palette envelope instead of tinting the
        // light color upward. Refind the gamut boundary at that lightness so
        // the result stays vivid without clipping into muddy sRGB edges.
        if isDark {
            let range = darkLightnessRange(forHue: h)
            L = range.lowerBound
                + parameters.lightnessPosition * (range.upperBound - range.lowerBound)
            C = maximumInGamutChroma(lightness: L, hue: h) * parameters.chromaFraction
        }

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
            let L2 = newL
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

        let preferWhite = shouldUseWhiteText(relativeLuminance: relLumLinear(lin))
        return (toSRGB(lin), preferWhite)
    }
}
