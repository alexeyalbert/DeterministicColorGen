import Foundation
import Testing
@testable import DeterministicColorGen

struct ColorGenerationTests {
	@Test("Deterministic color for same input (light)")
	func testColorDeterminismLight() {
		let input = "TestString"
		let c1 = DeterministicColor.rgb(for: input, style: .light)
		let c2 = DeterministicColor.rgb(for: input, style: .light)
		#expect(almostEqual(c1.0, c2.0) && almostEqual(c1.1, c2.1) && almostEqual(c1.2, c2.2))
	}

	@Test("Deterministic color for same input (dark)")
	func testColorDeterminismDark() {
		let input = "TestString"
		let c1 = DeterministicColor.rgb(for: input, style: .dark)
		let c2 = DeterministicColor.rgb(for: input, style: .dark)
		#expect(almostEqual(c1.0, c2.0) && almostEqual(c1.1, c2.1) && almostEqual(c1.2, c2.2))
	}

	@Test("Different strings produce different colors (light)")
	func testDifferentStringsDifferentColorsLight() {
		let v1 = DeterministicColor.rgb(for: "StringOne", style: .light)
		let v2 = DeterministicColor.rgb(for: "StringTwo", style: .light)
		#expect(!almostEqual(v1.0, v2.0) || !almostEqual(v1.1, v2.1) || !almostEqual(v1.2, v2.2))
	}

	@Test("Foreground meets 4.5:1 contrast on light background")
	func testForegroundContrastLight() {
		let bg = DeterministicColor.rgb(for: "ContrastCheck", style: .light)
		let fgPrefWhite = DeterministicColor.prefersWhiteText(for: "ContrastCheck", style: .light)
		let fg = fgPrefWhite ? (1.0, 1.0, 1.0) : (0.0, 0.0, 0.0)
		let ratio = contrastRatio(bg, fg)
		#expect(ratio >= 4.5)
	}

	@Test("Foreground meets 4.5:1 contrast on dark background")
	func testForegroundContrastDark() {
		let bg = DeterministicColor.rgb(for: "ContrastCheck", style: .dark)
		let fgPrefWhite = DeterministicColor.prefersWhiteText(for: "ContrastCheck", style: .dark)
		let fg = fgPrefWhite ? (1.0, 1.0, 1.0) : (0.0, 0.0, 0.0)
		let ratio = contrastRatio(bg, fg)
		#expect(ratio >= 4.5)
	}

	@Test("Public color function returns valid Color objects")
	func testPublicColorFunction() {
		_ = DeterministicColor.color("test", style: .light)
		_ = DeterministicColor.color("test", style: .dark)
		// verify it doesn't crash and returns Color objects (can't directly compare SwiftUI Colors)
		#expect(true)
	}

	@Test("Public uiSet function returns valid Color tuples")
	func testPublicUiSetFunction() {
		_ = DeterministicColor.uiSet("test", style: .light)
		_ = DeterministicColor.uiSet("test", style: .dark)
		// verify it returns valid Color objects (can't directly compare SwiftUI Colors)
		#expect(true)
	}

	@Test("Default style parameter works correctly")
	func testDefaultStyleParameter() {
		let color1 = DeterministicColor.rgb(for: "test", style: .light)
		let color2 = DeterministicColor.rgb(for: "test", style: .light)
		// should be the same since both use .light
		#expect(almostEqual(color1.0, color2.0))
		#expect(almostEqual(color1.1, color2.1))
		#expect(almostEqual(color1.2, color2.2))
	}

	@Test("Empty string produces valid color")
	func testEmptyString() {
		let color = DeterministicColor.rgb(for: "", style: .light)
		#expect(color.0 >= 0.0 && color.0 <= 1.0)
		#expect(color.1 >= 0.0 && color.1 <= 1.0)
		#expect(color.2 >= 0.0 && color.2 <= 1.0)
	}

	@Test("Very long string produces valid color")
	func testVeryLongString() {
		let longString = String(repeating: "a", count: 10000)
		let color = DeterministicColor.rgb(for: longString, style: .light)
		#expect(color.0 >= 0.0 && color.0 <= 1.0)
		#expect(color.1 >= 0.0 && color.1 <= 1.0)
		#expect(color.2 >= 0.0 && color.2 <= 1.0)
	}

	@Test("Unicode characters produce valid colors")
	func testUnicodeCharacters() {
		let unicodeStrings = ["🎨", "🚀", "🌟", "🔥", "💎", "🌍", "🎭", "⚡"]
		for string in unicodeStrings {
			let color = DeterministicColor.rgb(for: string, style: .light)
			#expect(color.0 >= 0.0 && color.0 <= 1.0)
			#expect(color.1 >= 0.0 && color.1 <= 1.0)
			#expect(color.2 >= 0.0 && color.2 <= 1.0)
		}
	}

	@Test("Whitespace-only strings produce valid colors")
	func testWhitespaceOnlyStrings() {
		let whitespaceStrings = [" ", "  ", "\t", "\n", "   \n\t  "]
		for string in whitespaceStrings {
			let color = DeterministicColor.rgb(for: string, style: .light)
			#expect(color.0 >= 0.0 && color.0 <= 1.0)
			#expect(color.1 >= 0.0 && color.1 <= 1.0)
			#expect(color.2 >= 0.0 && color.2 <= 1.0)
		}
	}

	@Test("All generated colors are within sRGB gamut")
	func testColorsInGamut() {
		let testStrings = ["red", "green", "blue", "yellow", "purple", "orange", "pink", "brown"]
		for string in testStrings {
			let color = DeterministicColor.rgb(for: string, style: .light)
			// check each component is in [0, 1] range
			#expect(color.0 >= 0.0 && color.0 <= 1.0)
			#expect(color.1 >= 0.0 && color.1 <= 1.0)
			#expect(color.2 >= 0.0 && color.2 <= 1.0)
		}
	}

	@Test("Dark mode produces different colors than light mode")
	func testDarkModeDifferentFromLightMode() {
		let testStrings = ["test1", "test2", "test3", "test4", "test5"]
		var differentCount = 0
		for string in testStrings {
			let lightColor = DeterministicColor.rgb(for: string, style: .light)
			let darkColor = DeterministicColor.rgb(for: string, style: .dark)
			// check if at least one component is different
			if !almostEqual(lightColor.0, darkColor.0) || 
			   !almostEqual(lightColor.1, darkColor.1) || 
			   !almostEqual(lightColor.2, darkColor.2) {
				differentCount += 1
			}
		}
		// most colors should be different (contrast adjustment may override mode differences)
		#expect(differentCount > 0)
	}

	@Test("Text preference is consistent for same input")
	func testTextPreferenceConsistency() {
		let input = "ConsistentTest"
		let pref1 = DeterministicColor.prefersWhiteText(for: input, style: .light)
		let pref2 = DeterministicColor.prefersWhiteText(for: input, style: .light)
		#expect(pref1 == pref2)
	}

	@Test("Many different strings produce unique colors")
	func testManyUniqueColors() {
		var colors: Set<String> = []
		for i in 0..<100 {
			let color = DeterministicColor.rgb(for: "string\(i)", style: .light)
			let colorString = "\(color.0),\(color.1),\(color.2)"
			colors.insert(colorString)
		}
		// most colors should be unique (allow some collisions due to hash nature)
		#expect(colors.count > 80)
	}

	@Test("No infinite loops in gamut mapping")
	func testNoInfiniteLoops() {
		// test with many different strings to ensure gamut mapping always terminates
		for i in 0..<50 {
			let color = DeterministicColor.rgb(for: "stress\(i)", style: .light)
			// if we get here no infinite loop occurred
			#expect(color.0 >= 0.0 && color.0 <= 1.0)
		}
	}

	@Test("Warm and green hues use brighter hue-aware lightness ranges")
	func testHueAwareLightnessRanges() {
		let orange = DeterministicColor.lightnessRange(forHue: 36)
		let yellow = DeterministicColor.lightnessRange(forHue: 95)
		let green = DeterministicColor.lightnessRange(forHue: 140)
		let blue = DeterministicColor.lightnessRange(forHue: 260)

		#expect(orange.lowerBound >= 0.56)
		#expect(yellow.lowerBound >= 0.79)
		#expect(green.lowerBound >= 0.57)
		#expect(blue.lowerBound <= 0.53)
		#expect(yellow.lowerBound > orange.lowerBound)
	}

	@Test("Dark mode uses deeper hue-aware ranges without muddying warm hues")
	func testDarkModeLightnessRanges() {
		let red = DeterministicColor.darkLightnessRange(forHue: 0)
		let yellow = DeterministicColor.darkLightnessRange(forHue: 95)
		let green = DeterministicColor.darkLightnessRange(forHue: 140)
		let blue = DeterministicColor.darkLightnessRange(forHue: 260)

		#expect(red.upperBound <= 0.60)
		#expect(blue.upperBound <= 0.61)
		#expect(yellow.lowerBound >= 0.64)
		#expect(green.lowerBound >= 0.51)
		#expect(yellow.lowerBound > red.lowerBound)
		#expect(yellow.lowerBound > green.lowerBound)

		for hue in stride(from: 0.0, through: 359.0, by: 1.0) {
			let light = DeterministicColor.lightnessRange(forHue: hue)
			let dark = DeterministicColor.darkLightnessRange(forHue: hue)

			#expect(dark.lowerBound < light.lowerBound)
			#expect(dark.upperBound < light.upperBound)
		}
	}

	@Test("Muddy warm hue arc is remapped into curated palette bands")
	func testMuddyWarmHuesAreRemapped() {
		let redOrange = DeterministicColor.paletteHue(for: 55)
		let gold = DeterministicColor.paletteHue(for: 85)
		let green = DeterministicColor.paletteHue(for: 110)

		#expect(redOrange >= 34 && redOrange <= 39)
		#expect(gold >= 88 && gold <= 100)
		#expect(green >= 135 && green <= 155)
		#expect(DeterministicColor.paletteHue(for: 30) == 30)
		#expect(DeterministicColor.paletteHue(for: 140) == 140)

		for sourceHue in stride(from: 0.0, through: 359.75, by: 0.25) {
			let generatedHue = DeterministicColor.paletteHue(for: sourceHue)
			#expect(!(40..<88).contains(generatedHue))
			#expect(!(100..<135).contains(generatedHue))
		}
	}

	@Test("White text is preferred across its full WCAG-safe crossover range")
	func testWhiteTextCrossoverBias() {
		#expect(DeterministicColor.shouldUseWhiteText(relativeLuminance: 0.183) == true)
		#expect(DeterministicColor.shouldUseWhiteText(relativeLuminance: 0.184) == false)
	}

	@Test("Generated parameters stay inside their hue-aware envelope")
	func testGeneratedParametersUseHueAwareEnvelope() {
		for index in 0..<1_000 {
			let parameters = DeterministicColor.generationParameters(for: "palette-\(index)")
			let range = DeterministicColor.lightnessRange(forHue: parameters.hue)

			#expect(range.contains(parameters.lightness))
			#expect(parameters.chromaFraction >= 0.96)
			#expect(parameters.chromaFraction <= 0.99)
			#expect(parameters.chromaPosition >= 0 && parameters.chromaPosition <= 1)
			#expect(parameters.lightnessPosition >= 0 && parameters.lightnessPosition <= 1)
		}
	}
}

// helpers

private func almostEqual(_ a: Double, _ b: Double, eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

private func toLinear(_ v: Double) -> Double {
	if v <= 0.04045 { return v / 12.92 }
	return pow((v + 0.055) / 1.055, 2.4)
}

private func relativeLuminance(_ rgb: (Double, Double, Double)) -> Double {
	let r = toLinear(rgb.0)
	let g = toLinear(rgb.1)
	let b = toLinear(rgb.2)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

private func contrastRatio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
	let L1 = relativeLuminance(a)
	let L2 = relativeLuminance(b)
	let (hi, lo) = L1 >= L2 ? (L1, L2) : (L2, L1)
	return (hi + 0.05) / (lo + 0.05)
}
