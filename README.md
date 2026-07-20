# DeterministicColorGen

  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift Version">
  </a>
  <a href="https://www.apple.com/ios/">
    <img src="https://img.shields.io/badge/iOS-15.0%2B-blue.svg" alt="iOS 14.0+">
  </a>  
  <a href="https://www.apple.com/macos/">
    <img src="https://img.shields.io/badge/macOS-15%2B-blue.svg" alt="macOS 14.0+">
  </a>
  <a href="https://www.apple.com/tvos/">
    <img src="https://img.shields.io/badge/tvOS-15.0%2B-blue.svg" alt="tvOS 14.0+">
  </a>
  <a href="https://www.apple.com/watchos/">
    <img src="https://img.shields.io/badge/watchOS-6.0%2B-blue.svg" alt="watchOS 7.0+">
  </a>
  <a href="https://www.apple.com/visionos/">
    <img src="https://img.shields.io/badge/visionOS-1.0%2B-blue.svg" alt="visionOS 1.0+">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT">
  </a>


A Swift package that generates deterministic, visually appealing colors from strings. Perfect for creating consistent color schemes for tags, badges, categories, and other UI elements.

## Features

- **Deterministic**: Same input always produces the same color
- **Cross-platform**: Works on iOS, macOS, tvOS, watchOS, and visionOS
- **Accessible**: Ensures WCAG 4.5:1 contrast ratio compliance
- **SwiftUI Compatible**: Returns `Color` values for easy integration
- **Dynamic**: Supports automatic light/dark mode adaptation

## Installation

### Xcode Projects

Select `File` -> `Swift Packages` -> `Add Package Dependency` and enter `https://github.com/alexeyalbert/DeterministicColorGen.git`.

### Swift Package Manager Projects

You can add `DeterministicColorGen` as a package dependency in your `Package.swift` file:

```swift
let package = Package(
    //...
    dependencies: [
        .package(
            url: "https://github.com/alexeyalbert/DeterministicColorGen.git",
            from: "1.0.0"
        ),
    ],
    //...
)
```



## Quick Start

```swift
import DeterministicColorGen

// Dynamic colors that adapt to light/dark mode
let (fillColor, textColor) = DeterministicColor.uiSet("Hello World!")

// Use in SwiftUI views
Text("Hello World!")
    .foregroundColor(textColor)
    .background(fillColor)
```

## Usage

### Dynamic Colors (Recommended)

Use `uiSet(_:)` to get fill and text colors that automatically adapt to the current light/dark mode:

```swift
let (fill, text) = DeterministicColor.uiSet("Programming")

// The colors will automatically update when the system appearance changes
Text("Programming")
    .foregroundColor(text)
    .background(fill)
    .padding()
    .cornerRadius(8)
```

### Fixed Colors

Use `color(_:style:)` when you need a consistent color regardless of the interface style:

```swift
let lightColor = DeterministicColor.color("Swift", style: .light)
let darkColor = DeterministicColor.color("Swift", style: .dark)

// Use the same color regardless of system appearance
Rectangle()
    .fill(lightColor)
    .frame(width: 100, height: 100)
```

### Background + Text Colors

Use `uiSet(_:style:)` to get a fill and text color optimized for a specific interface style:

```swift
let (fill, text) = DeterministicColor.uiSet("Swift", style: .light)

Text("Swift")
    .foregroundColor(text)
    .background(fill)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .cornerRadius(16)
```

### SwiftUI Modifiers

Since the package returns SwiftUI `Color` values, you can use all standard SwiftUI modifiers:

```swift
let (fill, text) = DeterministicColor.uiSet("Swift")

// Use opacity
Text("Swift")
    .foregroundColor(text.opacity(0.8))
    .background(fill.opacity(0.9))

// Use with buttons
Button("Swift") { }
    .tint(fill)
    .foregroundColor(text)

// Use with gradients
LinearGradient(
    colors: [fill, fill.opacity(0.7)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

## Color Generation Algorithm

The package uses an algorithm to ensure high-quality, accessible colors:

1. **Hash Input**: Uses SHA-256 to create a deterministic hash from the input string
2. **Curated OKLCH Palette**: Remaps rusty, muddy, and olive source-hue intervals into clean red-orange, gold, and emerald bands with hue-specific lightness ranges
3. **Relative Chroma**: Samples chroma as a percentage of the exact sRGB gamut limit for each hue/lightness pair
4. **Gamut Mapping**: Ensures colors are within the sRGB displayable range without collapsing multiple inputs onto the same boundary color
5. **Contrast Optimization**: Selects text colors that meet the WCAG 4.5:1 requirement
6. **Mode Adaptation**: Uses a deeper hue-aware dark-mode envelope while preserving vivid relative chroma

### Color Properties

- **Hue**: Distributed across the full 360° spectrum
- **Chroma**: 96-99% of the maximum displayable sRGB chroma at the generated hue and lightness
- **Lightness**: Smoothly varies by curated hue family (approximately 0.53-0.83), with narrow ranges that avoid brown, olive, and pastel outcomes
- **Contrast**: Minimum 4.5:1 ratio against white/black text

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
