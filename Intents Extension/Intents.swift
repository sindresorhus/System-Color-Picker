import AppIntents
import SwiftUI
import AppKit

// Note: This is only in an extension as there is currently no way to detect that the app is running an in-app intent and prevent opening the color panel.

struct GetRandomColorIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Random Color"

	static let description = IntentDescription(
		"""
		Returns a random color.

		The color formats Hex, HSL, RGB, OKLCH, and LCH are provided as individual properties.
		""",
		resultValueName: "Random Color"
	)

	func perform() async throws -> some IntentResult & ReturnsValue<Color_AppEntity> {
		.result(value: .init(.randomAvoidingBlackAndWhite()))
	}
}

struct SampleColorIntent: AppIntent {
	static let title: LocalizedStringResource = "Sample Color from Screen"

	static let description = IntentDescription(
		"""
		Lets you pick a color from the screen.

		The color formats Hex, HSL, RGB, OKLCH, and LCH are provided as individual properties.
		""",
		resultValueName: "Color from Screen"
	)

	func perform() async throws -> some IntentResult & ReturnsValue<Color_AppEntity?> {
		guard let color = await NSColorSampler().sample() else {
			return .result(value: nil)
		}

		return .result(value: .init(color.toResolvedColor))
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

	@Property(title: "OKLCH")
	var oklch: String

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
	init(_ color: Color.Resolved) {
		self.hex = color.format(.hex(hasPrefix: true))
		self.hexNumber = color.hex
		self.hsl = color.format(.cssHSL)
		self.rgb = color.format(.cssRGB)
		self.oklch = color.format(.cssOKLCH)
		self.lch = color.format(.cssLCH)
		self.hslLegacy = color.format(.cssHSLLegacy)
		self.rgbLegacy = color.format(.cssRGBLegacy)
		self.image = .init(systemName: "square.fill", tintColor: color.toXColor)
	}
}
