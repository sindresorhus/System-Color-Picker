import AppKit
import AppIntents

// Note: This is only in an extension as there is currently no way to detect that the app is running an in-app intent and prevent opening the color panel.

struct GetRandomColorIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "GetRandomColorIntent"

	static let title: LocalizedStringResource = "Get Random Color"

	static let description = IntentDescription(
"""
Returns a random color.

The color formats Hex, HSL, RGB, and LCH are provided as individual properties.
"""
	)

	func perform() async throws -> some IntentResult & ReturnsValue<Color_AppEntity> {
		.result(value: .init(.randomAvoidingBlackAndWhite()))
	}
}

struct SampleColorIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "SampleColorIntent"

	static let title: LocalizedStringResource = "Sample Color from Screen"

	static let description = IntentDescription(
"""
Lets you pick a color from the screen.

The color formats Hex, HSL, RGB, and LCH are provided as individual properties.
"""
	)

	func perform() async throws -> some IntentResult & ReturnsValue<Color_AppEntity?> {
		guard let color = await NSColorSampler().sample() else {
			return .result(value: nil)
		}

		return .result(value: .init(color))
	}
}

struct Color_AppEntity: TransientAppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Color"

	@Property(title: "Hex")
	var hex: String

	@Property(title: "Hex Number")
	var hexNumber: Int

	@Property(title: "HSL")
	var hsl: String

	@Property(title: "RGB")
	var rgb: String

	@Property(title: "LCH")
	var lch: String

	@Property(title: "HSL Legacy")
	var hslLegacy: String

	@Property(title: "RGB Legacy")
	var rgbLegacy: String

	private var image: DisplayRepresentation.Image?

	var displayRepresentation: DisplayRepresentation {
		.init(
			title: "\(hex)",
			subtitle: "\(rgb)",
			image: image
		)
	}
}

extension Color_AppEntity {
	init(_ nsColor: NSColor) {
		let sRGBColor = nsColor.usingColorSpace(.sRGB)!

		self.hex = sRGBColor.format(.hex(hasPrefix: true))
		self.hexNumber = sRGBColor.hex
		self.hsl = sRGBColor.format(.cssHSL)
		self.rgb = sRGBColor.format(.cssRGB)
		self.lch = nsColor.format(.cssLCH)
		self.hslLegacy = sRGBColor.format(.cssHSLLegacy)
		self.rgbLegacy = sRGBColor.format(.cssRGBLegacy)
		self.image = .init(systemName: "square.fill", tintColor: sRGBColor)
	}
}
