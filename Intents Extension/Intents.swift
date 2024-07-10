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
