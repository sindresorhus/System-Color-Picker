import Cocoa
import Intents

extension Color_ {
	fileprivate convenience init(_ nsColor: NSColor) {
		let sRGBColor = nsColor.usingColorSpace(.sRGB)!
		let thumbnail = NSImage.color(nsColor, size: CGSize(width: 1, height: 1))

		self.init(
			identifier: "color",
			display: sRGBColor.hexString,
			subtitle: sRGBColor.format(.cssRGB),
			image: thumbnail.inImage
		)

		hex = sRGBColor.format(.hex())
		hexNumber = sRGBColor.hex as NSNumber
		hsl = sRGBColor.format(.cssHSL)
		rgb = sRGBColor.format(.cssRGB)
		lch = nsColor.format(.cssLCH)
		hslLegacy = sRGBColor.format(.cssHSLLegacy)
		rgbLegacy = sRGBColor.format(.cssRGBLegacy)
	}
}

@MainActor
final class SampleColorIntentHandler: NSObject, SampleColorIntentHandling {
	func handle(intent: SampleColorIntent) async -> SampleColorIntentResponse {
		guard let color = await NSColorSampler().sample() else {
			return .init(code: .failure, userActivity: nil)
		}

		let response = SampleColorIntentResponse(code: .success, userActivity: nil)
		response.color = Color_(color)
		return response
	}
}

@MainActor
final class GetRandomColorIntentHandler: NSObject, GetRandomColorIntentHandling {
	func handle(intent: GetRandomColorIntent) async -> GetRandomColorIntentResponse {
		let response = GetRandomColorIntentResponse(code: .success, userActivity: nil)
		response.color = Color_(.randomAvoidingBlackAndWhite())
		return response
	}
}

@MainActor
final class IntentHandler: INExtension {
	override func handler(for intent: INIntent) -> Any? {
		switch intent {
		case is SampleColorIntent:
			return SampleColorIntentHandler()
		case is GetRandomColorIntent:
			return GetRandomColorIntentHandler()
		default:
			assertionFailure("No handler for this intent")
			return nil
		}
	}
}
