#if DEBUG
import Foundation
import SwiftUI

/// A preview-only color lab for inspecting the generator's output distribution.
private struct DeterministicColorGallery: View {
    private let coverageSamples = PreviewColorSample.coverage.stratified
    private let boundarySamples = PreviewColorSample.coverage.boundaries
    private let edgeCaseSamples = PreviewColorSample.edgeCases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                PreviewSection(
                    title: "Full stratified parameter coverage",
                    detail: "24 source-hue × 4 lightness × 4 chroma intervals = 384 production-pipeline results"
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 168), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(coverageSamples) { sample in
                            ColorSampleCard(sample: sample)
                        }
                    }
                }

                PreviewSection(
                    title: "Boundary targets",
                    detail: "Nearest real text inputs to low/high lightness and chroma at key hues"
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(boundarySamples) { sample in
                            ColorSampleCard(sample: sample)
                        }
                    }
                }

                PreviewSection(
                    title: "Input edge cases",
                    detail: "Useful for spotting normalization assumptions and surprising collisions"
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(edgeCaseSamples) { sample in
                            ColorSampleCard(sample: sample)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.primary.opacity(0.035))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Deterministic Color Lab")
                .font(.largeTitle.bold())

            Text("Each card uses the same input in both interface styles. Values are the final gamma-encoded sRGB output after gamut and contrast adjustment.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("White/black marker = chosen text", systemImage: "textformat")
                Label("Ordered by source hue, lightness, then chroma", systemImage: "paintpalette")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct PreviewSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

private struct ColorSampleCard: View {
    let sample: PreviewColorSample

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            swatch(sample.light, label: "LIGHT")
            swatch(sample.dark, label: "DARK")

            VStack(alignment: .leading, spacing: 3) {
                Text(sample.displayName)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(sample.parameterDescription)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(sample.reproducibleInput)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .padding(9)
        }
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private func swatch(_ output: PreviewColorOutput, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            output.fillColor

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                    Spacer(minLength: 4)
                    Text(output.prefersWhiteText ? "WHITE" : "BLACK")
                }
                .font(.caption2.bold())

                Text("\(output.hex)  ·  \(output.contrast, format: .number.precision(.fractionLength(2))):1")
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(output.textColor)
            .padding(8)
        }
        .frame(height: 64)
    }
}

private struct PreviewColorSample: Identifiable {
    let input: String
    let displayName: String
    let parameters: DeterministicColor.GenerationParameters

    init(input: String, displayName: String) {
        self.input = input
        self.displayName = displayName
        parameters = DeterministicColor.generationParameters(for: input)
    }

    var id: String { input }
    var reproducibleInput: String { input.debugDescription }
    var parameterDescription: String {
        let hueDescription = abs(parameters.sourceHue - parameters.hue) > 0.05
            ? String(format: "H %05.1f→%05.1f°", parameters.sourceHue, parameters.hue)
            : String(format: "H %05.1f°", parameters.hue)
        return String(
            format: "%@  L %.3f  C %.3f · %.0f%% gamut",
            hueDescription,
            parameters.lightness,
            parameters.chroma,
            parameters.chromaFraction * 100
        )
    }
    var light: PreviewColorOutput { .init(input: input, style: .light) }
    var dark: PreviewColorOutput { .init(input: input, style: .dark) }

    /// Search a deterministic pool of real strings, then retain the result
    /// nearest the center of every H/L/C cell. Every displayed color therefore
    /// traverses the normal String -> SHA-256 -> OKLCH -> sRGB pipeline.
    static let coverage: (stratified: [PreviewColorSample], boundaries: [PreviewColorSample]) = {
        let candidates = (0..<24_576).map { index in
            PreviewColorSample(input: "coverage-\(index)", displayName: "")
        }

        var cells: [PreviewColorCell: (distance: Double, sample: PreviewColorSample)] = [:]
        for sample in candidates {
            let coordinate = sample.normalizedCoordinate
            let cell = PreviewColorCell(
                hue: min(Int(coordinate.hue * 24), 23),
                lightness: min(Int(coordinate.lightness * 4), 3),
                chroma: min(Int(coordinate.chroma * 4), 3)
            )
            let center = (
                hue: (Double(cell.hue) + 0.5) / 24.0,
                lightness: (Double(cell.lightness) + 0.5) / 4.0,
                chroma: (Double(cell.chroma) + 0.5) / 4.0
            )
            let distance = Self.distance(coordinate, center)
            if distance < cells[cell]?.distance ?? .infinity {
                cells[cell] = (distance, sample)
            }
        }

        let stratified = (0..<24).flatMap { hue in
            (0..<4).flatMap { lightness in
                (0..<4).compactMap { chroma -> PreviewColorSample? in
                    let cell = PreviewColorCell(hue: hue, lightness: lightness, chroma: chroma)
                    guard let match = cells[cell]?.sample else { return nil }
                    return PreviewColorSample(
                        input: match.input,
                        displayName: "Source H \(hue + 1)/24 · L \(lightness + 1)/4 · C \(chroma + 1)/4"
                    )
                }
            }
        }
        precondition(
            stratified.count == 384,
            "The deterministic candidate pool did not fill every H/L/C coverage cell."
        )

        let targets = [0.0, 1.0].flatMap { lightness in
            [0.0, 1.0].flatMap { chroma in
                [0.0, 1.0 / 3.0, 2.0 / 3.0].map { hue in
                    PreviewBoundaryTarget(hue: hue, lightness: lightness, chroma: chroma)
                }
            }
        }
        let boundaries = targets.map { target in
            let match = candidates.min {
                Self.distance($0.normalizedCoordinate, target.coordinate)
                    < Self.distance($1.normalizedCoordinate, target.coordinate)
            }!
            return PreviewColorSample(
                input: match.input,
                displayName: target.displayName
            )
        }

        return (stratified, boundaries)
    }()

    static let edgeCases: [PreviewColorSample] = [
        .init(input: "", displayName: "Empty string"),
        .init(input: " ", displayName: "Single space"),
        .init(input: "  ", displayName: "Two spaces"),
        .init(input: "\t\n", displayName: "Tab + newline"),
        .init(input: "a", displayName: "One character"),
        .init(input: "A", displayName: "Case variant"),
        .init(input: "Swift", displayName: "ASCII word"),
        .init(input: "swift", displayName: "Lowercase variant"),
        .init(input: "café", displayName: "Precomposed Unicode"),
        .init(input: "cafe\u{301}", displayName: "Combining Unicode"),
        .init(input: "🎨", displayName: "Emoji"),
        .init(input: "👨‍👩‍👧‍👦", displayName: "Emoji sequence"),
        .init(input: "こんにちは世界", displayName: "Japanese"),
        .init(input: "مرحبا بالعالم", displayName: "Arabic"),
        .init(input: String(repeating: "a", count: 1_000), displayName: "1,000 characters")
    ]

    private var normalizedCoordinate: (hue: Double, lightness: Double, chroma: Double) {
        (
            hue: parameters.huePosition,
            lightness: parameters.lightnessPosition,
            chroma: parameters.chromaPosition
        )
    }

    private static func distance(
        _ lhs: (hue: Double, lightness: Double, chroma: Double),
        _ rhs: (hue: Double, lightness: Double, chroma: Double)
    ) -> Double {
        let directHueDistance = abs(lhs.hue - rhs.hue)
        let hueDistance = min(directHueDistance, 1 - directHueDistance)
        return hueDistance * hueDistance
            + pow(lhs.lightness - rhs.lightness, 2)
            + pow(lhs.chroma - rhs.chroma, 2)
    }
}

private struct PreviewColorCell: Hashable {
    let hue: Int
    let lightness: Int
    let chroma: Int
}

private struct PreviewBoundaryTarget {
    let hue: Double
    let lightness: Double
    let chroma: Double

    var coordinate: (hue: Double, lightness: Double, chroma: Double) {
        (hue, lightness, chroma)
    }

    var displayName: String {
        let hueDegrees = Int((hue * 360).rounded())
        let lightnessLabel = lightness == 0 ? "L min" : "L max"
        let chromaLabel = chroma == 0 ? "C min" : "C max"
        return "H \(hueDegrees)° · \(lightnessLabel) · \(chromaLabel)"
    }
}

private struct PreviewColorOutput {
    let rgb: (r: Double, g: Double, b: Double)
    let prefersWhiteText: Bool

    init(input: String, style: DeterministicColor.InterfaceStyle) {
        let value = DeterministicColor.rgb(for: input, style: style)
        rgb = (value.0, value.1, value.2)
        prefersWhiteText = DeterministicColor.prefersWhiteText(for: input, style: style)
    }

    var fillColor: Color { Color(red: rgb.r, green: rgb.g, blue: rgb.b) }
    var textColor: Color { prefersWhiteText ? .white : .black }

    var hex: String {
        let red = Int((rgb.r * 255).rounded())
        let green = Int((rgb.g * 255).rounded())
        let blue = Int((rgb.b * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    var contrast: Double {
        let background = 0.2126 * Self.linear(rgb.r)
            + 0.7152 * Self.linear(rgb.g)
            + 0.0722 * Self.linear(rgb.b)
        let foreground = prefersWhiteText ? 1.0 : 0.0
        return (max(background, foreground) + 0.05) / (min(background, foreground) + 0.05)
    }

    private static func linear(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

#Preview("Full Generated Color Coverage") {
    DeterministicColorGallery()
        .frame(minWidth: 900, minHeight: 700)
}
#endif
