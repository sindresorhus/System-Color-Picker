import SwiftUI
import Combine
import Carbon
import StoreKit
import Defaults
import UniformTypeIdentifiers

#if !APP_EXTENSION
import Sentry
#endif

typealias Defaults = _Defaults
typealias Default = _Default
typealias AnyCancellable = Combine.AnyCancellable

/*
Non-reusable utilities
*/

#if !APP_EXTENSION
extension Color.Resolved {
	func colorString(for colorFormat: ColorFormat) -> String {
		switch colorFormat {
		case .hex:
			format(
				.hex(
					isUppercased: Defaults[.uppercaseHexColor],
					hasPrefix: NSEvent.modifiers == .option ? !Defaults[.hashPrefixInHexColor] : Defaults[.hashPrefixInHexColor]
				)
			)
		case .hsl:
			format(Defaults[.legacyColorSyntax] ? .cssHSLLegacy : .cssHSL)
		case .rgb:
			format(Defaults[.legacyColorSyntax] ? .cssRGBLegacy : .cssRGB)
		case .oklch:
			format(.cssOKLCH)
		case .lch:
			format(.cssLCH)
		}
	}

	var ss_hsbColorString: String {
		format(.hsb)
	}

	var ss_stringRepresentation: String {
		colorString(for: Defaults[.preferredColorFormat])
	}
}
#endif

// TODO: Should this be extension on Color or Color.Resolved?
extension Color {
	func swatchImage(size: Double) -> NSImage {
		.color(
			self,
			size: CGSize(width: size, height: size),
			borderWidth: (NSScreen.main?.backingScaleFactor ?? 2) > 1 ? 0.5 : 1,
			borderColor: (SSApp.isDarkMode ? Color.white : .black).opacity(0.2),
			cornerRadius: 5
		)
	}
}


/*
---
*/


#if os(macOS)
typealias XColor = NSColor
#else
typealias XColor = UIColor
#endif


//func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
//	Task.detached {
//		try? await Task.sleep(seconds: seconds)
//		closure()
//	}
//}

// TODO: Don't make this use `Task` for at least another two years (2025). There are a lot of things that don't work with `Task`.
func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}


extension Float {
	var toDouble: Double { .init(self) }
}

extension Double {
	var toFloat: Float { .init(self) }
}


protocol SSDictionaryProtocol<Key, Value>: ExpressibleByDictionaryLiteral {
	subscript(key: Key) -> Value? { get set }
}

extension Dictionary: SSDictionaryProtocol {}


struct EnumCaseMap<Key: CaseIterable & Hashable, Value>: SSDictionaryProtocol {
	private var storage: [Key: Value]

	/**
	Use this initializer if you want the same default value for all the cases. If not, specify a dictionary literal.
	*/
	init(defaultValue: Value) {
		storage = Key.allCases.reduce(into: [:]) { result, enumCase in
			result[enumCase] = defaultValue
		}
	}

	// Protocol requirement.
	@_disfavoredOverload
	subscript(key: Key) -> Value? {
		get { storage[key] }
		set {
			storage[key] = newValue
		}
	}

	subscript(key: Key) -> Value {
		get { storage[key]! }
		set {
			storage[key] = newValue
		}
	}

	init(dictionaryLiteral elements: (Key, Value)...) {
		precondition(elements.count == Key.allCases.count, "Missing enum one or more enum cases.")

		self.storage = [:]

		for (key, value) in elements {
			self[key] = value
		}
	}
}


extension Sequence where Element: Hashable {
	/**
	Filters the elements of the sequence based on a set of allowed values.

	- Parameters:
	 - allowedValues: A set containing the values to be retained in the sequence.

	- Returns: An array containing only elements that are also in the set.
	*/
	func filter(allowedValues: Set<Element>) -> [Element] {
		filter { allowedValues.contains($0) }
	}
}


extension Color.Resolved {
	/**
	Generate a random color, avoiding black and white.
	*/
	static func randomAvoidingBlackAndWhite() -> Self {
		// TODO: Use `Color.Resolved` init.
		XColor(
			hue: .random(in: 0...1),
			saturation: .random(in: 0.5...1), // 0.5 is to get away from white
			brightness: .random(in: 0.5...1), // 0.5 is to get away from black
			alpha: 1
		)
		.toResolvedColor
	}
}


extension Color.Resolved {
	func withOpacity(_ opacity: Double) -> Self {
		var copy = self
		copy.opacity = opacity.toFloat
		return copy
	}
}


extension NSAppearance {
	var isDarkMode: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}


enum SSApp {
	static let idString = Bundle.main.bundleIdentifier!
	static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
	static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
	static let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
	static let versionWithBuild = "\(version) (\(build))"
	static let icon = NSApp.applicationIconImage!
	static let url = Bundle.main.bundleURL

	static var isDarkMode: Bool { NSApp?.effectiveAppearance.isDarkMode ?? false }

	@MainActor
	static func quit() {
		NSApp.terminate(nil)
	}

	static let isFirstLaunch: Bool = {
		let key = "SS_hasLaunched"

		if UserDefaults.standard.bool(forKey: key) {
			return false
		}

		UserDefaults.standard.set(true, forKey: key)
		return true
	}()

	static func openSendFeedbackPage() {
		let metadata =
			"""
			\(name) \(versionWithBuild) - \(idString)
			macOS \(Device.osVersion)
			\(Device.hardwareModel)
			"""

		let query: [String: String] = [
			"product": name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback").addingDictionaryAsQuery(query).open()
	}

	static var isDockIconVisible: Bool {
		get { NSApp.activationPolicy() == .regular }
		set {
			NSApp.setActivationPolicy(newValue ? .regular : .accessory)
		}
	}
}


extension SSApp {
	//	@MainActor
	static func forceActivate() {
		NSApp.yieldActivation(toApplicationWithBundleIdentifier: idString)
		NSApp.activate()
	}

	@MainActor
	static func activateIfAccessory() {
		guard NSApp.activationPolicy() == .accessory else {
			return
		}

		forceActivate()
	}
}


extension SSApp {
	@MainActor
	static var swiftUIMainWindow: NSWindow? {
		NSApp.windows.first { $0.simpleClassName == "AppKitWindow" }
	}
}


extension SSApp {
	/**
	Manually show the SwiftUI settings window.
	*/
	@MainActor
	static func showSettingsWindow() {
		// Run in the next runloop so it doesn't conflict with SwiftUI if run at startup.
		DispatchQueue.main.async {
			SSApp.activateIfAccessory()

			let menuItem = NSApp.mainMenu?.items.first?.submenu?.item(withTitle: "Settings…")
			menuItem?.performAction()
		}
	}

	/**
	The SwiftUI settings window.
	*/
	@MainActor
	static var settingsWindow: NSWindow? {
		NSApp.windows.first { $0.frameAutosaveName == "com_apple_SwiftUI_Settings_window" }
	}
}


extension SSApp {
	/**
	Initialize Sentry.
	*/
	static func initSentry(_ dsn: String) {
		#if !DEBUG && !APP_EXTENSION && canImport(Sentry)
		SentrySDK.start {
			$0.dsn = dsn
			$0.enableSwizzling = false
			$0.enableAppHangTracking = false // https://github.com/getsentry/sentry-cocoa/issues/2643
		}
		#endif
	}
}


extension UTType {
	static var adobeSwatchExchange: Self { .init(filenameExtension: "ase", conformingTo: .data)! }
}


enum Device {
	static let osVersion: String = {
		let os = ProcessInfo.processInfo.operatingSystemVersion
		return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
	}()

	static let hardwareModel: String = {
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		return String(cString: model)
	}()

	static var uptimeIncludingSleep: Duration {
		.nanoseconds(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW_APPROX))
	}
}


private func escapeQuery(_ query: String) -> String {
	// From RFC 3986
	let generalDelimiters = ":#[]@"
	let subDelimiters = "!$&'()*+,;="

	var allowedCharacters = CharacterSet.urlQueryAllowed
	allowedCharacters.remove(charactersIn: generalDelimiters + subDelimiters)
	return query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? query
}


extension Dictionary where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
	var asQueryItems: [URLQueryItem] {
		map {
			URLQueryItem(
				name: escapeQuery($0 as! String),
				value: escapeQuery($1 as! String)
			)
		}
	}

	var asQueryString: String {
		var components = URLComponents()
		components.queryItems = asQueryItems
		return components.query!
	}
}


extension Duration {
	enum ConversionUnit: Double {
		case days = 86_400_000_000_000
		case hours = 3_600_000_000_000
		case minutes = 60_000_000_000
		case seconds = 1_000_000_000
		case milliseconds = 1_000_000
		case microseconds = 1000
	}

	/**
	Nanoseconds representation.
	*/
	var nanoseconds: Int64 {
		let (seconds, attoseconds) = components
		let secondsNanos = seconds * 1_000_000_000
		let attosecondsNanons = attoseconds / 1_000_000_000
		let (totalNanos, isOverflow) = secondsNanos.addingReportingOverflow(attosecondsNanons)
		return isOverflow ? .max : totalNanos
	}

	func `in`(_ unit: ConversionUnit) -> Double {
		Double(nanoseconds) / unit.rawValue
	}
}


extension Duration {
	var toTimeInterval: TimeInterval { self.in(.seconds) }
}


extension URLComponents {
	mutating func addDictionaryAsQuery(_ dict: [String: String]) {
		percentEncodedQuery = dict.asQueryString
	}
}


extension URL {
	func addingDictionaryAsQuery(_ dict: [String: String]) -> Self {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
		components.addDictionaryAsQuery(dict)
		return components.url ?? self
	}
}


@discardableResult
func with<T>(_ value: T, update: (inout T) throws -> Void) rethrows -> T {
	var copy = value
	try update(&copy)
	return copy
}


extension AnyCancellable {
	private static var foreverStore = Set<AnyCancellable>()

	/**
	Stores this AnyCancellable forever.

	- Important: Only use this in singletons, for example, `AppDelegate`. Otherwise, it will create memory leaks.
	*/
	func storeForever() {
		store(in: &Self.foreverStore)
	}
}


extension String {
	var toNSAttributedString: NSAttributedString { NSAttributedString(string: self) }
}


extension NSAttributedString {
	/**
	Returns a `NSMutableAttributedString` version.
	*/
	func mutable() -> NSMutableAttributedString {
		// Force-casting here is safe as it can only be nil if there's no `mutableCopy` implementation, but we know there is for `NSMutableAttributedString`.
		// swiftlint:disable:next force_cast
		mutableCopy() as! NSMutableAttributedString
	}

	var nsRange: NSRange { NSRange(0..<length) }

	/**
	Get an attribute if it applies to the whole string.
	*/
	func attributeForWholeString(_ key: Key) -> Any? {
		guard length > 0 else {
			return nil
		}

		var foundRange = NSRange()
		let result = attribute(key, at: 0, longestEffectiveRange: &foundRange, in: nsRange)

		guard foundRange.length == length else {
			return nil
		}

		return result
	}

	var smallFontSized: NSAttributedString {
		withFontSizeFast(NSFont.smallSystemFontSize)
	}

	/**
	The `.font` attribute for the whole string, falling back to the system font if none.

	- Note: It even handles if half the string has one attribute and the other half has another, as long as those attributes are identical.
	*/
	var font: NSFont {
		attributeForWholeString(.font) as? NSFont ?? .systemFont(ofSize: NSFont.systemFontSize)
	}

	/**
	- Important: This does not preserve font-related styles like bold and italic.
	*/
	func withFontSizeFast(_ fontSize: Double) -> NSAttributedString {
		addingAttributes([.font: font.withSize(fontSize)])
	}

	func addingAttributes(_ attributes: [Key: Any]) -> NSAttributedString {
		let new = mutable()
		new.addAttributes(attributes, range: nsRange)
		return new
	}

	/**
	- Important: This does not preserve font-related styles like bold and italic.
	*/
	func withFont(_ font: NSFont) -> NSAttributedString {
		addingAttributes([.font: font])
	}
}


extension NSView {
	func focus() {
		window?.makeFirstResponder(self)
	}

	func blur() {
		window?.makeFirstResponder(nil)
	}
}


final class LocalEventMonitor: ObservableObject {
	private let events: NSEvent.EventTypeMask
	private let callback: ((NSEvent) -> NSEvent?)?
	private weak var monitor: AnyObject?

	// swiftlint:disable:next private_subject
	let objectWillChange = PassthroughSubject<NSEvent, Never>()

	init(
		events: NSEvent.EventTypeMask,
		callback: ((NSEvent) -> NSEvent?)? = nil
	) {
		self.events = events
		self.callback = callback
	}

	deinit {
		stop()
	}

	@discardableResult
	func start() -> Self {
		monitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
			guard let self else {
				return event
			}

			objectWillChange.send(event)

			if let callback {
				return callback(event)
			}

			return event
		} as AnyObject

		return self
	}

	func stop() {
		guard let monitor else {
			return
		}

		NSEvent.removeMonitor(monitor)
	}
}

final class GlobalEventMonitor {
	private let events: NSEvent.EventTypeMask
	private let callback: (NSEvent) -> Void
	private weak var monitor: AnyObject?

	init(events: NSEvent.EventTypeMask, callback: @escaping (NSEvent) -> Void) {
		self.events = events
		self.callback = callback
	}

	deinit {
		stop()
	}

	@discardableResult
	func start() -> Self {
		monitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: callback) as AnyObject
		return self
	}

	func stop() {
		guard let monitor else {
			return
		}

		NSEvent.removeMonitor(monitor)
	}
}


extension NSView {
	func constrainEdges(to view: NSView) {
		translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
			topAnchor.constraint(equalTo: view.topAnchor),
			bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}

	func constrainEdgesToSuperview() {
		guard let superview else {
			assertionFailure("There is no superview for this view")
			return
		}

		constrainEdges(to: superview)
	}
}


extension Color.Resolved {
	/**
	The default debug description is useless.
	*/
	var debugString: String {
		"Color.Resolved(red: \(red), blue: \(blue), green: \(green), opacity: \(opacity))"
	}
}


enum CSSTools {
	/**
	Converts a CSS angle value to degrees.

	- Parameter angleString: A string representing the angle in CSS format (e.g., "45deg", "0.5turn").
	- Returns: The angle in degrees if conversion is possible, otherwise nil.

	```
	let degrees = CSSTools.convertAngleToDegrees("45rad")
	//=> 2291.83
	```
	*/
	static func parseAngleColorComponentToDegrees(_ angleString: String) -> Double? {
		let value = angleString
			.replacing(/deg|rad|grad|turn/, with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)

		guard let hue = Double(value) else {
			return nil
		}

		if angleString.hasSuffix("rad") {
			return (hue * 180) / .pi
		}

		if angleString.hasSuffix("grad") {
			return hue * 0.9
		}

		if angleString.hasSuffix("turn") {
			return hue * 360
		}

		return hue // Already in degrees or a plain number
	}

	/**
	Converts a CSS opacity value to a normalized Double in the range `0...1`.

	- Parameter opacityString: A string representing the opacity in CSS format (e.g., `"0.5"`, `"50%"`).
	- Returns: The opacity as a Double between 0 and 1 if conversion is possible, otherwise nil.

	```
	let opacity = CSSTools.parseOpacityColorComponent("75%")
	//=> 0.75
	```
	*/
	static func parseOpacityColorComponent(_ opacityString: String) -> Double? {
		guard let rawOpacity = Double(opacityString.replacing("%", with: "")) else {
			return nil
		}

		let opacity = opacityString.hasSuffix("%") ? (rawOpacity / 100) : rawOpacity
		return opacity.clamped(to: 0...1)
	}
}


// https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/hsl
extension Color.Resolved {
	private static let cssHSLRegex = /^\s*hsla?\((?<hue>\d+)(?:deg)?[\s,]*(?<saturation>[\d.]+)%[\s,]*(?<lightness>[\d.]+)%(?:\s*[,\/]\s*(?<opacity>[\d.]+%?))?\);?\s*$/

	fileprivate static func parseMatchOpacity(_ opacityString: String?) -> Double {
		opacityString.flatMap { CSSTools.parseOpacityColorComponent($0) } ?? 1
	}

	init?(
		cssHSLString: String,
		colorSpace: Color.RGBColorSpace = .sRGB
	) {
		guard
			let match = cssHSLString.trimmingCharacters(in: .whitespaces).wholeMatch(of: Self.cssHSLRegex)?.output,
			let hue = Double(match.hue),
			let saturation = Double(match.saturation),
			let lightness = Double(match.lightness),
			(0...360).contains(hue),
			(0...100).contains(saturation),
			(0...100).contains(lightness)
		else {
			return nil
		}

		self = Self.fromHSL(
			hue: hue / 360,
			saturation: saturation / 100,
			lightness: lightness / 100,
			opacity: Self.parseMatchOpacity(match.opacity?.toString)
		)
	}
}


// https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/rgb
extension Color.Resolved {
	// Fixture: rgb(27.59% 41.23% 100%)
	private static let cssRGBRegex = /^\s*rgba?\((?<red>[\d.]+)[\s,]*(?<green>[\d.]+)[\s,]*(?<blue>[\d.]+)(?:\s*[,\/]\s*(?<opacity>[\d.]+%?))?\);?\s*$/

	// For `rgb(10%, 10%, 10%)` type syntax.
	// Same as the above regex but with added `%`.
	private static let cssRGBPercentRegex = /^\s*rgba?\((?<red>[\d.]+)%[\s,]*(?<green>[\d.]+)%[\s,]*(?<blue>[\d.]+)%(?:\s*[,\/]\s*(?<opacity>[\d.]+%?))?\);?\s*$/

	init?(
		cssRGBString: String,
		colorSpace: Color.RGBColorSpace = .sRGB
	) {
		let string = cssRGBString.trimmingCharacters(in: .whitespaces)

		guard
			let match = string.wholeMatch(of: Self.cssRGBRegex)?.output,
			let red = Float(match.red),
			let green = Float(match.green),
			let blue = Float(match.blue),
			(0...255).contains(red),
			(0...255).contains(green),
			(0...255).contains(blue)
		else {
			self.init(cssRGBPercentString: string, colorSpace: colorSpace)
			return
		}

		self.init(
			colorSpace: colorSpace,
			red: red / 255,
			green: green / 255,
			blue: blue / 255,
			opacity: Self.parseMatchOpacity(match.opacity?.toString).toFloat
		)
	}

	private init?(
		cssRGBPercentString: String,
		colorSpace: Color.RGBColorSpace = .sRGB
	) {
		guard
			let match = cssRGBPercentString.wholeMatch(of: Self.cssRGBPercentRegex)?.output,
			let red = Float(match.red),
			let green = Float(match.green),
			let blue = Float(match.blue),
			(0...100).contains(red),
			(0...100).contains(green),
			(0...100).contains(blue)
		else {
			return nil
		}

		self.init(
			colorSpace: colorSpace,
			red: red / 100,
			green: green / 100,
			blue: blue / 100,
			opacity: Self.parseMatchOpacity(match.opacity?.toString).toFloat
		)
	}
}


// https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/oklch()
extension Color.Resolved {
	private static let cssOKLCHRegex = /^\s*oklch\((?<lightness>[\d.]+%?)\s+(?<chroma>[\d.]+%?)\s+(?<hue>[\d.]+(?:deg|rad|grad|turn)?)\s*(?:\/\s*(?<opacity>[\d.]+%?))?\)?;?$/

	init?(cssOKLCHString: String) {
		guard
			let match = cssOKLCHString.trimmingCharacters(in: .whitespaces).wholeMatch(of: Self.cssOKLCHRegex)?.output,
			let lightnessValue = Double(match.lightness.replacing("%", with: "")),
			let chromaValue = Double(match.chroma.replacing("%", with: "")),
			let hue = CSSTools.parseAngleColorComponentToDegrees(match.hue.toString)
		else {
			return nil
		}

		let lightness = match.lightness.hasSuffix("%") ? (lightnessValue / 100) : lightnessValue
		let chroma = match.chroma.hasSuffix("%") ? ((chromaValue / 100) * 0.4) : chromaValue // 100% means 0.4.

		guard
			(0...1).contains(lightness),
			chroma >= 0, // Usually max 0.5, but theoretically unbounded.
			(0...360).contains(hue)
		else {
			return nil
		}

		self = Colors.OKLCH(
			lightness: lightness,
			chroma: chroma,
			hue: hue,
			opacity: Self.parseMatchOpacity(match.opacity?.toString)
		)
		.toResolved
	}
}


// https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/lch()
extension Color.Resolved {
	// This is the exact same regex as OKLCH, just with `lch(` instead.
	private static let cssLCHRegex = /^\s*lch\((?<lightness>[\d.]+%?)\s+(?<chroma>[\d.]+%?)\s+(?<hue>[\d.]+(?:deg|rad|grad|turn)?)\s*(?:\/\s*(?<opacity>[\d.]+%?))?\)?;?$/

	init?(cssLCHString: String) {
		guard
			let match = cssLCHString.trimmingCharacters(in: .whitespaces).wholeMatch(of: Self.cssLCHRegex)?.output,
			let lightnessValue = Double(match.lightness.replacing("%", with: "")),
			let chromaValue = Double(match.chroma.replacing("%", with: "")),
			let hue = CSSTools.parseAngleColorComponentToDegrees(match.hue.toString)
		else {
			return nil
		}

		let lightness = match.lightness.hasSuffix("%") ? lightnessValue : (lightnessValue * 100)
		let chroma = match.chroma.hasSuffix("%") ? (chromaValue * (150 / 100)) : chromaValue // 100% means 150.

		guard
			(0...100).contains(lightness),
			chroma >= 0, // Usually max 230, but theoretically unbounded.
			(0...360).contains(hue)
		else {
			return nil
		}

		self = Colors.LCH(
			lightness: lightness,
			chroma: chroma,
			hue: hue,
			opacity: Self.parseMatchOpacity(match.opacity?.toString)
		)
		.toResolved
	}
}


extension Color.Resolved {
	// TODO: Should this accept a color space?
	/**
	Create a color from a CSS color string in the format Hex, HSL, or RGB.

	- Note: Assumes `sRGB` color space.
	*/
	init?(cssString: String) {
		let result: Color.Resolved? = {
			if let color = Color.Resolved(cssHexString: cssString) {
				return color
			}

			if let color = Color.Resolved(cssHSLString: cssString) {
				return color
			}

			if let color = Color.Resolved(cssRGBString: cssString) {
				return color
			}

			if let color = Color.Resolved(cssOKLCHString: cssString) {
				return color
			}

			if let color = Color.Resolved(cssLCHString: cssString) {
				return color
			}

			return nil
		}()

		guard let result else {
			return nil
		}

		self = result
	}
}


extension Color.Resolved {
	/**
	Loosely gets a color from the pasteboard.

	It first tries to get an actual color object and then tries to parse a CSS string (ignoring leading/trailing whitespace) for Hex, HSL, and RGB.
	*/
	static func fromPasteboardGraceful(_ pasteboard: NSPasteboard) -> Self? {
		if let color = XColor(from: pasteboard)?.toResolvedColor {
			return color
		}

		guard
			let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespaces),
			let color = self.init(cssString: string)
		else {
			return nil
		}

		return color
	}
}


extension Color.Resolved {
	init?(
		cssHexString: String,
		colorSpace: Color.RGBColorSpace = .sRGB
	) {
		var string = cssHexString.trimmingCharacters(in: .whitespaces)

		if cssHexString.hasPrefix("#") {
			string = String(cssHexString.dropFirst())
		}

		if string.count == 3 || string.count == 4 { // 4 is with opacity.
			string = string.map { "\($0)\($0)" }.joined()
		}

		guard
			string.count == 6 || string.count == 8,
			let hexValue = Int(string, radix: 16)
		else {
			return nil
		}

		let red, green, blue, opacity: Float
		if string.count == 6 {
			red = Float((hexValue >> 16) & 0xFF) / 255
			green = Float((hexValue >> 8) & 0xFF) / 255
			blue = Float(hexValue & 0xFF) / 255
			opacity = 1
		} else {
			red = Float((hexValue >> 24) & 0xFF) / 255
			green = Float((hexValue >> 16) & 0xFF) / 255
			blue = Float((hexValue >> 8) & 0xFF) / 255
			opacity = Float(hexValue & 0xFF) / 255
		}

		self.init(
			colorSpace: colorSpace,
			red: red,
			green: green,
			blue: blue,
			opacity: opacity
		)
	}

	/**
	- Note: Unlike in CSS, the opacity is placed first.
	- Note: It respects the opacity of the color.

	```
	Color.Resolved(cssHexString: "#fefefe")!.hex
	//=> 0xFEFEFE
	```
	*/
	var hex: Int {
		let red = Int((red.clamped(to: 0...1) * 0xFF).rounded())
		let green = Int((green.clamped(to: 0...1) * 0xFF).rounded())
		let blue = Int((blue.clamped(to: 0...1) * 0xFF).rounded())
		let opacity = Int((opacity.clamped(to: 0...1) * 0xFF).rounded())
		return red << 16 | green << 8 | blue << 0 | opacity << 24
	}

	/**
	- Note: It includes the opacity of the color if not `1`.
	- Note: The opacity is last.

	```
	Color.Resolved(cssHexString: "#fefefe")!.hexString
	//=> "#fefefe"
	```
	*/
	var hexString: String {
		let red = Int((red.clamped(to: 0...1) * 255).rounded())
		let green = Int((green.clamped(to: 0...1) * 255).rounded())
		let blue = Int((blue.clamped(to: 0...1) * 255).rounded())

		var hex = String(format: "#%02x%02x%02x", red, green, blue)

		if opacity < 1 {
			assert(opacity <= 1)
			hex = hex.appendingFormat("%02x", Int((opacity.clamped(to: 0...1) * 255).rounded()))
		}

		return hex
	}
}


extension Color.Resolved {
	enum ColorStringFormat {
		case hex(isUppercased: Bool = false, hasPrefix: Bool = false)
		case cssHSL
		case cssRGB
		case cssOKLCH
		case cssLCH
		case cssHSLLegacy
		case cssRGBLegacy
		case hsb
	}

	/**
	Format the color to a string using the given format.
	*/
	func format(_ format: ColorStringFormat) -> String {
		switch format {
		case .hex(let isUppercased, let hasPrefix):
			var string = hexString

			if isUppercased {
				string = string.uppercased()
			}

			if !hasPrefix {
				string = string.dropFirst().toString
			}

			return string
		case .cssHSL:
			let hsl = toHSL
			let hue = Int((hsl.hue.clamped(to: 0...1) * 360).rounded())
			let saturation = Int((hsl.saturation.clamped(to: 0...1) * 100).rounded())
			let lightness = Int((hsl.lightness.clamped(to: 0...1) * 100).rounded())
			let opacity = Int((hsl.opacity.clamped(to: 0...1) * 100).rounded())

			return opacity < 100
				? String(format: "hsl(%ddeg %d%% %d%% / %d%%)", hue, saturation, lightness, opacity)
				: String(format: "hsl(%ddeg %d%% %d%%)", hue, saturation, lightness)
		case .cssRGB:
			let red = Int((red.clamped(to: 0...1) * 0xFF).rounded())
			let green = Int((green.clamped(to: 0...1) * 0xFF).rounded())
			let blue = Int((blue.clamped(to: 0...1) * 0xFF).rounded())
			let opacity = Int((opacity.clamped(to: 0...1) * 100).rounded())

			return opacity < 100
				? String(format: "rgb(%d %d %d / %d%%)", red, green, blue, opacity)
				: String(format: "rgb(%d %d %d)", red, green, blue)
		case .cssOKLCH:
			let oklch = toOKLCH
			let lightness = Int((oklch.lightness.clamped(to: 0...1) * 100).rounded())
			let chroma = (oklch.chroma / 0.4) * 100 // Showing percent is more user-friendly.
			let hue = oklch.hue
			let opacity = Int((oklch.opacity.clamped(to: 0...1) * 100).rounded())

			return opacity < 100
				// TODO: Add setting for how many decimals to show.
				? String(format: "oklch(%d%% %.0f%% %.0fdeg / %d%%)", lightness, chroma, hue, opacity)
				: String(format: "oklch(%d%% %.0f%% %.0fdeg)", lightness, chroma, hue)
		case .cssLCH:
			let lch = toLCH
			let lightness = Int(lch.lightness.rounded())
			let chroma = (lch.chroma / 150) * 100 // Showing percent is more user-friendly.
			let hue = lch.hue
			let opacity = Int((lch.opacity.clamped(to: 0...1) * 100).rounded())

			return opacity < 100
				? String(format: "lch(%d%% %.0f%% %.0fdeg / %d%%)", lightness, chroma, hue, opacity)
				: String(format: "lch(%d%% %.0f%% %.0fdeg)", lightness, chroma, hue)
		case .cssHSLLegacy:
			let hsl = toHSL
			let hue = Int((hsl.hue.clamped(to: 0...1) * 360).rounded())
			let saturation = Int((hsl.saturation.clamped(to: 0...1) * 100).rounded())
			let lightness = Int((hsl.lightness.clamped(to: 0...1) * 100).rounded())
			let opacity = opacity.clamped(to: 0...1)

			return opacity < 1
				? String(format: "hsl(%d, %d%%, %d%%, %.2f)", hue, saturation, lightness, opacity)
				: String(format: "hsl(%d, %d%%, %d%%)", hue, saturation, lightness)
		case .cssRGBLegacy:
			let red = Int((red.clamped(to: 0...1) * 0xFF).rounded())
			let green = Int((green.clamped(to: 0...1) * 0xFF).rounded())
			let blue = Int((blue.clamped(to: 0...1) * 0xFF).rounded())
			let opacity = opacity.clamped(to: 0...1)

			return opacity < 1
				? String(format: "rgb(%d, %d, %d, %.2f)", red, green, blue, opacity)
				: String(format: "rgb(%d, %d, %d)", red, green, blue)
		case .hsb:
			let hsb = toHSB
			let hue = Int((hsb.hue * 360).rounded())
			let saturation = Int((hsb.saturation * 100).rounded())
			let brightness = Int((hsb.brightness * 100).rounded())
			let opacity = Int((toHSL.opacity.clamped(to: 0...1) * 100).rounded())

			return opacity < 100
				? String(format: "%d %d%% %d%% / %d%%", hue, saturation, brightness, opacity)
				: String(format: "%d %d%% %d%%", hue, saturation, brightness)
		}
	}
}


extension StringProtocol {
	/**
	Makes it easier to deal with optional sub-strings.
	*/
	var toString: String { String(self) }
}


extension NSPasteboard {
	func with(_ callback: (NSPasteboard) -> Void) {
		prepareForNewContents()
		callback(self)
	}
}


extension String {
	func copyToPasteboard() {
		NSPasteboard.general.with {
			$0.setString(self, forType: .string)
		}
	}
}

// swiftlint:disable:next no_cgfloat
extension CGFloat {
	/**
	Get a Double from a CGFloat. This makes it easier to work with optionals.
	*/
	var toDouble: Double { Double(self) }
}

extension Int {
	/**
	Get a Double from an Int. This makes it easier to work with optionals.
	*/
	var toDouble: Double { Double(self) }
}


extension NSTextField {
	/**
	Whether the text field currently has keyboard focus.
	*/
	var isCurrentFirstResponder: Bool {
		currentEditor() == window?.firstResponder
	}
}


struct NativeTextField: NSViewRepresentable {
	typealias NSViewType = InternalTextField

	@Binding var text: String
	var placeholder: String?
	var font: NSFont?
	var isFirstResponder = false
	@Binding var isFocused: Bool // Note: This is only readable.
	var isSingleLine = true

	final class InternalTextField: NSTextField {
		private var globalEventMonitor: GlobalEventMonitor?
		private var localEventMonitor: LocalEventMonitor?

		var parent: NativeTextField

		init(_ parent: NativeTextField) {
			self.parent = parent
			super.init(frame: .zero)
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		override func becomeFirstResponder() -> Bool {
			parent.isFocused = true

			// This is required so that it correctly loses focus when the user clicks in the menu bar or uses the dropper from a keyboard shortcut.
			globalEventMonitor = GlobalEventMonitor(events: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
				guard let self else {
					return
				}

				unfocus()
			}.start()

			// Cannot be `.leftMouseUp` as the color wheel swallows it.
			localEventMonitor = LocalEventMonitor(events: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
				guard let self else {
					return event
				}

				if event.type == .keyDown {
					if event.keyCode == kVK_Escape {
						return nil
					}

					return event
				}

				let clickPoint = convert(event.locationInWindow, from: nil)
				let clickMargin = 3.0

				if !frame.insetBy(dx: -clickMargin, dy: -clickMargin).contains(clickPoint) {
					unfocus()
				} else {
					parent.isFocused = true
				}

				return event
			}.start()

			return super.becomeFirstResponder()
		}

		private func unfocus() {
			parent.isFocused = false
			blur()
		}
	}

	final class Coordinator: NSObject, NSTextFieldDelegate {
		var parent: NativeTextField
		var didBecomeFirstResponder = false

		init(_ autoFocusTextField: NativeTextField) {
			self.parent = autoFocusTextField
		}

		func controlTextDidChange(_ notification: Notification) {
			parent.text = (notification.object as? NSTextField)?.stringValue ?? ""
		}

		func controlTextDidEndEditing(_ notification: Notification) {
			guard let textField = notification.object as? NSTextField else {
				return
			}

			// The text field needs some time to transition into a new state.
			DispatchQueue.main.async { [self] in
				parent.isFocused = textField.isCurrentFirstResponder
			}
		}

		// This ensures the app doesn't close when pressing `Esc` (closing is the default behavior for `NSPanel`.
		func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
			if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
				parent.text = ""
				return true
			}

			return false
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let nsView = NSViewType(self)
		nsView.delegate = context.coordinator

		// This makes it scroll horizontally when text overflows instead of moving to a new line.
		if isSingleLine {
			nsView.cell?.usesSingleLineMode = true
			nsView.cell?.wraps = false
			nsView.cell?.isScrollable = true
			nsView.maximumNumberOfLines = 1
		}

		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.bezelStyle = .roundedBezel
		nsView.stringValue = text
		nsView.placeholderString = placeholder

		if let font {
			nsView.font = font
		}

		// Note: Does not work without the dispatch call.
		DispatchQueue.main.async {
			if
				isFirstResponder,
				!context.coordinator.didBecomeFirstResponder,
				let window = nsView.window,
				window.firstResponder != nsView
			{
				window.makeFirstResponder(nsView)
				context.coordinator.didBecomeFirstResponder = true
			}
		}
	}
}


extension NSColorPanel {
	// TODO: Make this an AsyncSequence.
	/**
	Publishes when the color in the color panel changes.
	*/
	var colorDidChange: some Publisher<Void, Never> {
		NotificationCenter.default
			.publisher(for: Self.colorDidChangeNotification, object: self)
			.map { _ in }
	}
}


extension NSAlert {
	/**
	Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	static func showModal(
		for window: NSWindow? = nil,
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) -> NSApplication.ModalResponse {
		NSAlert(
			title: title,
			message: message,
			style: style,
			buttonTitles: buttonTitles,
			defaultButtonIndex: defaultButtonIndex
		)
			.runModal(for: window)
	}

	/**
	The index in the `buttonTitles` array for the button to use as default.

	Set `-1` to not have any default. Useful for really destructive actions.
	*/
	var defaultButtonIndex: Int {
		get {
			buttons.firstIndex { $0.keyEquivalent == "\r" } ?? -1
		}
		set {
			// Clear the default button indicator from other buttons.
			for button in buttons where button.keyEquivalent == "\r" {
				button.keyEquivalent = ""
			}

			if newValue != -1 {
				buttons[newValue].keyEquivalent = "\r"
			}
		}
	}

	convenience init(
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) {
		self.init()
		self.messageText = title
		self.alertStyle = style

		if let message {
			self.informativeText = message
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/**
	Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window else {
			return runModal()
		}

		beginSheetModal(for: window) { returnCode in
			NSApp.stopModal(withCode: returnCode)
		}

		return NSApp.runModal(for: window)
	}

	/**
	Adds buttons with the given titles to the alert.
	*/
	func addButtons(withTitles buttonTitles: [String]) {
		for buttonTitle in buttonTitles {
			addButton(withTitle: buttonTitle)
		}
	}
}


extension View {
	/**
	Make the view subscribe to the given notification.
	*/
	func onNotification(
		_ name: Notification.Name,
		object: AnyObject? = nil,
		perform action: @escaping (Notification) -> Void
	) -> some View {
		onReceive(NotificationCenter.default.publisher(for: name, object: object), perform: action)
	}
}


extension NSEvent {
	/**
	Creates a noop mouse event that can be used as a fallback when you cannot get a real mouse event.
	*/
	static func noopMouseEvent(_ type: EventType) -> NSEvent {
		mouseEvent(
			with: type,
			location: .zero,
			modifierFlags: modifierFlags,
			timestamp: Device.uptimeIncludingSleep.toTimeInterval,
			windowNumber: 0,
			context: nil,
			eventNumber: 0,
			clickCount: 1,
			pressure: 1
		)!
	}
}


private var controlActionClosureProtocolAssociatedObjectKey: UInt8 = 0

protocol ControlActionClosureProtocol: NSObjectProtocol {
	var target: AnyObject? { get set }
	var action: Selector? { get set }
}

private final class ActionTrampoline: NSObject {
	fileprivate let action: (NSEvent) -> Void

	init(action: @escaping (NSEvent) -> Void) {
		self.action = action
	}

	@objc
	fileprivate func handleAction(_ sender: AnyObject) {
		action(NSApp?.currentEvent ?? .noopMouseEvent(.leftMouseDown))
	}
}

extension ControlActionClosureProtocol {
	var onAction: ((NSEvent) -> Void)? {
		get {
			guard
				let trampoline = objc_getAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey) as? ActionTrampoline
			else {
				return nil
			}

			return trampoline.action
		}
		set {
			guard let newValue else {
				objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, nil, .OBJC_ASSOCIATION_RETAIN)
				return
			}

			let trampoline = ActionTrampoline(action: newValue)
			target = trampoline
			action = #selector(ActionTrampoline.handleAction)
			objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
		}
	}
}

extension NSControl: ControlActionClosureProtocol {}
extension NSMenuItem: ControlActionClosureProtocol {}


extension NSMenuItem {
	/**
	Perform the default action for the menu item (click it).
	*/
	func performAction() {
		guard let menu else {
			return
		}

		menu.performActionForItem(at: menu.index(of: self))
	}
}


extension NSMenuItem {
	/**
	The menu is only created when it's enabled.

	```
	menu.addItem("Foo")
		.withSubmenu(createCalendarEventMenu(with: event))
	```
	*/
	@discardableResult
	func withSubmenu(_ menu: @autoclosure () -> NSMenu) -> Self {
		submenu = isEnabled ? menu() : NSMenu()
		return self
	}

	/**
	The menu is only created when it's enabled.

	```
	menu
		.addItem("Foo")
		.withSubmenu { menu in

		}
	```
	*/
	@discardableResult
	func withSubmenu(_ menuBuilder: (NSMenu) -> NSMenu) -> Self {
		withSubmenu(menuBuilder(NSMenu()))
	}

	/**
	The menu is only created when it's enabled and it's created only when it's being shown.

	```
	menu.addItem("Foo")
		.withSubmenuLazy { [self] in
			createCalendarEventMenu(with: event)
		}
	```

	- Note: You cannot use any events like `.onOpenClose` on the given menu as the menu is created lazily.
	*/
	@discardableResult
	func withSubmenuLazy(
		_ menu: @escaping () -> NSMenu,
		onOpenClose: ((Bool) -> Void)? = nil
	) -> Self {
		let emptyMenu = SSMenu()
		submenu = emptyMenu

		if isEnabled {
			emptyMenu.isOpenPublisher.sink { isOpen in
				onOpenClose?(isOpen)

				guard
					isOpen,
					emptyMenu.items.isEmpty
				else {
					return
				}

				let menu = menu()
				let items = menu.items
				menu.items.removeAll()
				emptyMenu.items = items
			}
				.store(forTheLifetimeOf: self)
		}

		return self
	}
}


final class SSMenu: NSMenu, NSMenuDelegate {
	private let isOpenSubject = CurrentValueSubject<Bool, Never>(false)

	private(set) var isOpen = false

	let isOpenPublisher: AnyPublisher<Bool, Never>

	override init(title: String) {
		self.isOpenPublisher = isOpenSubject.eraseToAnyPublisher()
		super.init(title: title)
		self.delegate = self
		self.autoenablesItems = false
	}

	@available(*, unavailable)
	required init(coder decoder: NSCoder) {
		fatalError() // swiftlint:disable:this fatal_error_message
	}

	func menuWillOpen(_ menu: NSMenu) {
		isOpen = true
		isOpenSubject.send(true)
	}

	func menuDidClose(_ menu: NSMenu) {
		isOpen = false
		isOpenSubject.send(false)
	}
}


enum AssociationPolicy {
	case assign
	case retainNonatomic
	case copyNonatomic
	case retain
	case copy

	var rawValue: objc_AssociationPolicy {
		switch self {
		case .assign:
			.OBJC_ASSOCIATION_ASSIGN
		case .retainNonatomic:
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		case .copyNonatomic:
			.OBJC_ASSOCIATION_COPY_NONATOMIC
		case .retain:
			.OBJC_ASSOCIATION_RETAIN
		case .copy:
			.OBJC_ASSOCIATION_COPY
		}
	}
}


final class ObjectAssociation<Value> {
	private let defaultValue: Value
	private let policy: AssociationPolicy

	init(defaultValue: Value, policy: AssociationPolicy = .retainNonatomic) {
		self.defaultValue = defaultValue
		self.policy = policy
	}

	subscript(index: AnyObject) -> Value {
		get {
			objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as? Value ?? defaultValue
		}
		set {
			objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, policy.rawValue)
		}
	}
}


extension AnyCancellable {
	private enum AssociatedKeys {
		static let cancellables = ObjectAssociation<Set<AnyCancellable>>(defaultValue: [])
	}

	/**
	Stores this AnyCancellable for the lifetime of the given `object`.
	*/
	func store(forTheLifetimeOf object: AnyObject) {
		store(in: &AssociatedKeys.cancellables[object])
	}
}


extension NSWindow {
	func toggle() {
		if
			isVisible,
			isKeyWindow
		{
			performClose(nil)
		} else {
			SSApp.activateIfAccessory()
			makeKeyAndOrderFront(nil)
		}
	}
}


final class CallbackMenuItem: NSMenuItem {
	private static var validateCallback: ((NSMenuItem) -> Bool)?

	static func validate(_ callback: @escaping (NSMenuItem) -> Bool) {
		validateCallback = callback
	}

	private let callback: () -> Void

	init(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isHidden: Bool = false,
		action: @escaping () -> Void
	) {
		self.callback = action
		super.init(title: title, action: #selector(action(_:)), keyEquivalent: key)
		self.target = self
		self.isEnabled = isEnabled
		self.isHidden = isHidden

		if let keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	@available(*, unavailable)
	required init(coder decoder: NSCoder) {
		fatalError() // swiftlint:disable:this fatal_error_message
	}

	@objc
	private func action(_ sender: NSMenuItem) {
		callback()
	}
}

extension CallbackMenuItem: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		Self.validateCallback?(menuItem) ?? true
	}
}


extension NSMenuItem {
	convenience init(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(title: title, action: nil, keyEquivalent: key)
		self.isEnabled = isEnabled
		self.isChecked = isChecked
		self.isHidden = isHidden

		if let keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	convenience init(
		_ attributedTitle: NSAttributedString,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(
			"",
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		self.attributedTitle = attributedTitle
	}

	var isChecked: Bool {
		get { state == .on }
		set {
			state = newValue ? .on : .off
		}
	}
}


extension NSMenu {
	@discardableResult
	func add(_ menuItem: NSMenuItem) -> NSMenuItem {
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addDisabled(_ title: String) -> NSMenuItem {
		let menuItem = NSMenuItem(title)
		menuItem.isEnabled = false
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addDisabled(_ attributedTitle: NSAttributedString) -> NSMenuItem {
		let menuItem = NSMenuItem(attributedTitle)
		menuItem.isEnabled = false
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addItem(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addItem(
		_ attributedTitle: NSAttributedString,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			attributedTitle,
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addCallbackItem(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		action: @escaping () -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isHidden: isHidden,
			action: action
		)
		addItem(menuItem)
		return menuItem
	}

	/**
	- Note: It preserves the existing `.font` and other attributes, but makes the font smaller.
	*/
	@discardableResult
	func addHeader(_ title: NSAttributedString, hasSeparatorAbove: Bool = true) -> NSMenuItem {
		if hasSeparatorAbove {
			addSeparator()
		}

		let menuItem = NSMenuItem()
		menuItem.isEnabled = false
		menuItem.attributedTitle = title.smallFontSized
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addHeader(_ title: String, hasSeparatorAbove: Bool = true) -> NSMenuItem {
		// Doesn't work yet.
//		if #available(macOS 14, *) {
//			.sectionHeader(title: title)
//		} else {
			addHeader(title.toNSAttributedString, hasSeparatorAbove: hasSeparatorAbove)
//		}
	}

	@discardableResult
	func addSettingsItem() -> NSMenuItem {
		addCallbackItem("Settings…", key: ",") {
			Task {
				await SSApp.showSettingsWindow()
			}
		}
	}

	@discardableResult
	func addQuitItem() -> NSMenuItem {
		addSeparator()

		return addCallbackItem("Quit \(SSApp.name)", key: "q") {
			Task {
				await SSApp.quit()
			}
		}
	}

	func addSeparator() {
		addItem(.separator())
	}
}


extension Text {
	/**
	Make some text respect the current view environment being disabled.

	Useful for `Text` label to a control.
	*/
	func respectDisabled() -> some View {
		modifier(RespectDisabledViewModifier())
	}
}

private struct RespectDisabledViewModifier: ViewModifier {
	@Environment(\.isEnabled) private var isEnabled

	func body(content: Content) -> some View {
		content.opacity(isEnabled ? 1 : 0.5)
	}
}


extension URL {
	/**
	Convenience for opening URLs.
	*/
	func open() {
		NSWorkspace.shared.open(self)
	}
}


extension String {
	/*
	```
	"https://sindresorhus.com".openURL()
	```
	*/
	func openURL() {
		URL(string: self)?.open()
	}
}


extension URL: ExpressibleByStringLiteral {
	/**
	Example:

	```
	let url: URL = "https://sindresorhus.com"
	```
	*/
	public init(stringLiteral value: StaticString) {
		self.init(string: "\(value)")!
	}
}


extension URL {
	/**
	Example:

	```
	URL("https://sindresorhus.com")
	```
	*/
	init(_ staticString: StaticString) {
		self.init(string: "\(staticString)")!
	}
}


private struct WindowAccessor: NSViewRepresentable {
	private final class WindowAccessorView: NSView {
		@Binding var windowBinding: NSWindow?

		init(binding: Binding<NSWindow?>) {
			self._windowBinding = binding
			super.init(frame: .zero)
		}

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			windowBinding = window
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError() // swiftlint:disable:this fatal_error_message
		}
	}

	@Binding var window: NSWindow?

	init(_ window: Binding<NSWindow?>) {
		self._window = window
	}

	func makeNSView(context: Context) -> NSView {
		WindowAccessorView(binding: $window)
	}

	func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
	/**
	Bind the native backing-window of a SwiftUI window to a property.
	*/
	func bindHostingWindow(_ window: Binding<NSWindow?>) -> some View {
		background(WindowAccessor(window))
	}
}

private struct WindowViewModifier: ViewModifier {
	@State private var window: NSWindow?

	let onWindow: (NSWindow?) -> Void

	func body(content: Content) -> some View {
		onWindow(window)

		return content
			.bindHostingWindow($window)
	}
}

extension View {
	/**
	Access the native backing-window of a SwiftUI window.
	*/
	func accessHostingWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
		modifier(WindowViewModifier(onWindow: onWindow))
	}

	/**
	Set the window level of a SwiftUI window.
	*/
	func windowLevel(_ level: NSWindow.Level) -> some View {
		accessHostingWindow {
			$0?.level = level
		}
	}
}


extension NSWindow.Level {
	private static func level(for cgLevelKey: CGWindowLevelKey) -> Self {
		.init(Int(CGWindowLevelForKey(cgLevelKey)))
	}

	public static let utility = level(for: .utilityWindow)
}


extension NSView {
	/**
	Get a subview matching a condition.
	*/
	func firstSubview(deep: Bool = false, where matches: (NSView) -> Bool) -> NSView? {
		for subview in subviews {
			if matches(subview) {
				return subview
			}

			if deep, let match = subview.firstSubview(deep: deep, where: matches) {
				return match
			}
		}

		return nil
	}
}


extension NSObject {
	// Note: It's intentionally a getter to get the dynamic self.
	/**
	Returns the class name without module name.
	*/
	static var simpleClassName: String { String(describing: self) }

	/**
	Returns the class name of the instance without module name.
	*/
	var simpleClassName: String { Self.simpleClassName }
}


enum SSEvents {
	/**
	Publishes when the app becomes active/inactive.
	*/
	static var appIsActive: some Publisher<Bool, Never> {
		Publishers.Merge(
			NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
				.map { _ in true },
			NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
				.map { _ in false }
		)
	}
}


private struct AppearOnScreenView: NSViewControllerRepresentable {
	final class ViewController: NSViewController {
		var onViewDidAppear: (() -> Void)?
		var onViewDidDisappear: (() -> Void)?

		init() {
			super.init(nibName: nil, bundle: nil)
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("Not implemented")
		}

		override func loadView() {
			view = NSView()
		}

		override func viewDidAppear() {
			onViewDidAppear?()
		}

		override func viewDidDisappear() {
			onViewDidDisappear?()
		}
	}

	var onViewDidAppear: (() -> Void)?
	var onViewDidDisappear: (() -> Void)?

	func makeNSViewController(context: Context) -> ViewController {
		let viewController = ViewController()
		viewController.onViewDidAppear = onViewDidAppear
		viewController.onViewDidDisappear = onViewDidDisappear
		return viewController
	}

	func updateNSViewController(_ controller: ViewController, context: Context) {}
}

extension View {
	/**
	Called each time the view appears on screen.

	This is different from `.onAppear` which is only called when the view appears in the SwiftUI view hierarchy.
	*/
	func onAppearOnScreen(_ perform: @escaping () -> Void) -> some View {
		background(AppearOnScreenView(onViewDidAppear: perform))
	}

	/**
	Called each time the view disappears from screen.

	This is different from `.onDisappear` which is only called when the view disappears from the SwiftUI view hierarchy.
	*/
	func onDisappearFromScreen(_ perform: @escaping () -> Void) -> some View {
		background(AppearOnScreenView(onViewDidDisappear: perform))
	}
}


extension NSPasteboard {
	/**
	Returns a publisher that emits when the pasteboard changes.
	*/
	var simplePublisher: some Publisher<Void, Never> {
		Timer.publish(every: 0.2, tolerance: 0.1, on: .main, in: .common)
			.autoconnect()
			.prepend([]) // We want the publisher to also emit immediately when someone subscribes.
			.compactMap { [weak self] _ in
				self?.changeCount
			}
			.removeDuplicates()
			.map { _ in }
	}
}

extension NSPasteboard {
	/**
	An observable object that publishes updates when the given pasteboard changes.
	*/
	final class SimpleObservable: ObservableObject {
		private var cancellables = Set<AnyCancellable>()
		private var pasteboardPublisherCancellable: AnyCancellable?
		private let onlyWhenAppIsActive: Bool

		@Published var pasteboard: NSPasteboard {
			didSet {
				if
					onlyWhenAppIsActive,
					!NSApp.isActive
				{
					stop()
					return
				}

				start()
			}
		}

		/**
		It starts listening to changes automatically, as long as `onlyWhenAppIsActive` is not `true`.

		- Parameters:
			- pasteboard: The pasteboard to listen to changes.
			- onlyWhenAppIsActive: Only listen to changes while the app is active.
		*/
		init(_ pasteboard: NSPasteboard, onlyWhileAppIsActive: Bool = false) {
			self.pasteboard = pasteboard
			self.onlyWhenAppIsActive = onlyWhileAppIsActive

			if onlyWhileAppIsActive {
				SSEvents.appIsActive
					.sink { [weak self] isActive in
						guard let self else {
							return
						}

						if isActive {
							start()
						} else {
							stop()
						}
					}
					.store(in: &cancellables)

				if NSApp?.isActive == true {
					start()
				}
			} else {
				start()
			}
		}

		@discardableResult
		func start() -> Self {
			pasteboardPublisherCancellable = pasteboard.simplePublisher.sink { [weak self] in
				self?.objectWillChange.send()
			}

			return self
		}

		@discardableResult
		func stop() -> Self {
			pasteboardPublisherCancellable = nil
			return self
		}
	}
}


extension Binding where Value: CaseIterable & Equatable {
	/**
	```
	enum Priority: String, CaseIterable {
		case no
		case low
		case medium
		case high
	}

	// …

	Picker("Priority", selection: $priority.caseIndex) {
		ForEach(Priority.allCases.indices) { priorityIndex in
			Text(
				Priority.allCases[priorityIndex].rawValue.capitalized
			)
				.tag(priorityIndex)
		}
	}
	```
	*/
	var caseIndex: Binding<Value.AllCases.Index> {
		.init(
			get: { Value.allCases.firstIndex(of: wrappedValue)! },
			set: {
				wrappedValue = Value.allCases[$0]
			}
		)
	}
}


/**
Useful in SwiftUI:

```
ForEach(persons.indexed(), id: \.1.id) { index, person in
	// …
}
```
*/
struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
	typealias Index = Base.Index
	typealias Element = (index: Index, element: Base.Element)

	let base: Base
	var startIndex: Index { base.startIndex }
	var endIndex: Index { base.endIndex }

	func index(after index: Index) -> Index {
		base.index(after: index)
	}

	func index(before index: Index) -> Index {
		base.index(before: index)
	}

	func index(_ index: Index, offsetBy distance: Int) -> Index {
		base.index(index, offsetBy: distance)
	}

	subscript(position: Index) -> Element {
		(index: position, element: base[position])
	}
}

extension RandomAccessCollection {
	/**
	Returns a sequence with a tuple of both the index and the element.

	- Important: Use this instead of `.enumerated()`. See: https://khanlou.com/2017/03/you-probably-don%27t-want-enumerated/
	*/
	func indexed() -> IndexedCollection<Self> {
		IndexedCollection(base: self)
	}
}


struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index: Hashable, Label: View, Content: View {
	let selection: Binding<Enum>
	@ViewBuilder let content: (Enum) -> Content
	@ViewBuilder let label: () -> Label

	var body: some View {
		Picker(selection: selection.caseIndex) {
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				content(element)
					.tag(index)
			}
		} label: {
			label()
		}
	}
}

extension EnumPicker where Label == Text {
	init(
		_ title: some StringProtocol,
		selection: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum) -> Content
	) {
		self.selection = selection
		self.content = content
		self.label = { Text(title) }
	}
}


enum Colors {}

extension Colors {
	/**
	HSB color.

	The components are in the range `0...1`.
	*/
	struct HSB {
		let hue: Double
		let saturation: Double
		let brightness: Double
		let opacity: Double
	}
}

extension Colors {
	/**
	HSL color.

	The components are in the range `0...1`.
	*/
	struct HSL: Hashable {
		let hue: Double
		let saturation: Double
		let lightness: Double
		let opacity: Double
	}
}

extension Colors {
	struct OKLCH: Hashable {
		/**
		Range: `0...1`
		*/
		let lightness: Double

		/**
		Range: `0...0.5` *(Could be higher)*
		*/
		let chroma: Double

		/**
		Range: `0...360`
		*/
		let hue: Double

		/**
		Range: `0...1`
		*/
		let opacity: Double
	}
}

extension Colors {
	struct LCH: Hashable {
		/**
		Range: `0...100`
		*/
		let lightness: Double

		/**
		Range: `0...132` *(Could be higher)*
		*/
		let chroma: Double

		/**
		Range: `0...360`
		*/
		let hue: Double

		/**
		Range: `0...1`
		*/
		let opacity: Double
	}
}

extension Colors.LCH {
	var toLab: Colors.Lab {
		let hueRadians = hue * .pi / 180
		return .init(
			lightness: lightness,
			aDimension: chroma * cos(hueRadians),
			bDimension: chroma * sin(hueRadians),
			opacity: opacity
		)
	}
}


extension Colors {
	struct XYZ: Hashable {
		let x: Double
		let y: Double
		let z: Double
		let opacity: Double
	}
}

extension Colors.XYZ {
	/**
	Bradford chromatic adaptation from D65 to D50 for XYZ.

	http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
	*/
	var d65ToD50: Self {
		.init(
			x: (x * 1.0478112) + (y * 0.0228866) + (z * -0.0501270),
			y: (x * 0.0295424) + (y * 0.9904844) + (z * -0.0170491),
			z: (x * -0.0092345) + (y * 0.0150436) + (z * 0.7521316),
			opacity: opacity
		)
	}

	/**
	Bradford chromatic adaptation from D50 to D65 for XYZ.

	http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
	*/
	var d50ToD65: Self {
		.init(
			x: (x * 0.9555766) + (y * -0.0230393) + (z * 0.0631636),
			y: (x * -0.0282895) + (y * 1.0099416) + (z * 0.0210077),
			z: (x * 0.0122982) + (y * -0.0204830) + (z * 1.3299098),
			opacity: opacity
		)
	}

	/**
	Convert XYZ to Lab.

	- Note: Make sure to use `d65ToD50` first if converting from sRGB.
	*/
	var toLab: Colors.Lab {
		// Assuming XYZ is relative to D50, convert to CIE Lab
		// from CIE standard, which now defines these as a rational fraction.
		// swiftlint:disable identifier_name
		let ε = 216.0 / 24_389.0 // 6^3 / 29^3
		let κ = 24_389.0 / 27.0 // 29^3 / 3^3
		// swiftlint:enable identifier_name

		// Compute XYZ scaled relative to reference white.
		let scaledX = x / 0.96422
		let scaledY = y / 1.0
		let scaledZ = z / 0.82521

		func computeF(_ value: Double) -> Double {
			value > ε ? cbrt(value) : (κ * value + 16) / 116
		}

		let fX = computeF(scaledX)
		let fY = computeF(scaledY)
		let fZ = computeF(scaledZ)

		return .init(
			lightness: (116 * fY) - 16,
			aDimension: 500 * (fX - fY),
			bDimension: 200 * (fY - fZ),
			opacity: opacity
		)
	}

	/**
	Convert D65-adapted XYZ to linear-light sRGB.

	- Note: Make sure to use `d50ToD65` first if converting to sRGB.
	*/
	var toResolved: Color.Resolved {
		let red = (x * 3.2404542) + (y * -1.5371385) + (z * -0.4985314)
		let green = (x * -0.9692660) + (y * 1.8760108) + (z * 0.0415560)
		let blue = (x * 0.0556434) + (y * -0.2040259) + (z * 1.0572252)

		return .init(
			colorSpace: .sRGBLinear,
			red: red.toFloat,
			green: green.toFloat,
			blue: blue.toFloat,
			opacity: opacity.toFloat
		)
	}
}


extension Colors {
	struct Oklab: Hashable {
		let lightness: Double
		let aDimension: Double
		let bDimension: Double
		let opacity: Double
	}
}

extension Colors.Oklab {
	var toOKLCH: Colors.OKLCH {
		let hueRadians = atan2(bDimension, aDimension)
		let hueDegrees = hueRadians * 180 / .pi
		let normalizedHue = hueDegrees >= 0 ? hueDegrees : hueDegrees + 360

		return .init(
			lightness: lightness,
			chroma: sqrt((aDimension * aDimension) + (bDimension * bDimension)),
			hue: normalizedHue,
			opacity: opacity
		)
	}

	var toResolved: Color.Resolved {
		// From https://bottosson.github.io/posts/oklab/

		let lStar = lightness + (0.3963377774 * aDimension) + (0.2158037573 * bDimension)
		let mStar = lightness - (0.1055613458 * aDimension) - (0.0638541728 * bDimension)
		let sStar = lightness - (0.0894841775 * aDimension) - (1.2914855480 * bDimension)

		let linearL = lStar * lStar * lStar
		let linearM = mStar * mStar * mStar
		let linearS = sStar * sStar * sStar

		let red = (4.0767416621 * linearL) - (3.3077115913 * linearM) + (0.2309699292 * linearS)
		let green = (-1.2684380046 * linearL) + (2.6097574011 * linearM) - (0.3413193965 * linearS)
		let blue = (-0.0041960863 * linearL) - (0.7034186147 * linearM) + (1.7076147010 * linearS)

		return .init(
			colorSpace: .sRGBLinear,
			red: red.toFloat,
			green: green.toFloat,
			blue: blue.toFloat,
			opacity: opacity.toFloat
		)
	}
}


extension Colors {
	struct Lab: Hashable {
		let lightness: Double
		let aDimension: Double
		let bDimension: Double
		let opacity: Double
	}
}

extension Colors.Lab {
	var toXYZ: Colors.XYZ {
		// Convert Lab to D50-adapted XYZ.
		// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html

		// swiftlint:disable identifier_name
		let κ = 24_389.0 / 27.0 // 29^3 / 3^3
		let ε = 216.0 / 24_389.0 // 6^3 / 29^3
		// swiftlint:enable identifier_name

		// Compute f, starting with the luminance-related term.
		let fY = (lightness + 16) / 116
		let fX = aDimension / 500 + fY
		let fZ = fY - bDimension / 200

		let x = pow(fX, 3) > ε ? pow(fX, 3) : (116 * fX - 16) / κ
		let y = lightness > (κ * ε) ? pow((lightness + 16) / 116, 3) : lightness / κ
		let z = pow(fZ, 3) > ε ? pow(fZ, 3) : (116 * fZ - 16) / κ

		// Scaled by reference white.
		return .init(
			x: x * 0.96422,
			y: y * 1.0,
			z: z * 0.82521,
			opacity: opacity
		)
	}

	var toLCH: Colors.LCH {
		let hue = atan2(bDimension, aDimension) * 180 / .pi

		return .init(
			lightness: lightness,
			chroma: sqrt(pow(aDimension, 2) + pow(bDimension, 2)),
			hue: hue >= 0 ? hue : hue + 360,
			opacity: opacity
		)
	}
}


extension Color.Resolved {
	/**
	Convert to XYZ, using sRGB's own white, D65 (no chromatic adaptation).
	*/
	private var toXYZ: Colors.XYZ {
		let red = linearRed.toDouble
		let green = linearGreen.toDouble
		let blue = linearBlue.toDouble

		/*
		- http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
		- https://www.image-engineering.de/library/technotes/958-how-to-convert-between-srgb-and-ciexyz
		*/
		return .init(
			x: (red * 0.4124564) + (green * 0.3575761) + (blue * 0.1804375),
			y: (red * 0.2126729) + (green * 0.7151522) + (blue * 0.0721750),
			z: (red * 0.0193339) + (green * 0.1191920) + (blue * 0.9503041),
			opacity: opacity.toDouble
		)
	}

	private var toOklab: Colors.Oklab {
		let red = linearRed.toDouble
		let green = linearGreen.toDouble
		let blue = linearBlue.toDouble

		// From: https://bottosson.github.io/posts/oklab/

		// Linear LMS
		let linearL = (0.4122214708 * red) + (0.5363325363 * green) + (0.0514459929 * blue)
		let linearM = (0.2119034982 * red) + (0.6806995451 * green) + (0.1073969566 * blue)
		let linearS = (0.0883024619 * red) + (0.2817188376 * green) + (0.6299787005 * blue)

		let cubicRootL = cbrt(linearL)
		let cubicRootM = cbrt(linearM)
		let cubicRootS = cbrt(linearS)

		return .init(
			lightness: (0.2104542553 * cubicRootL) + (0.7936177850 * cubicRootM) - (0.0040720468 * cubicRootS),
			aDimension: (1.9779984951 * cubicRootL) - (2.4285922050 * cubicRootM) + (0.4505937099 * cubicRootS),
			bDimension: (0.0259040371 * cubicRootL) + (0.7827717662 * cubicRootM) - (0.8086757660 * cubicRootS),
			opacity: opacity.toDouble
		)
	}

	/**
	Convert to OKLCH.
	*/
	var toOKLCH: Colors.OKLCH { toOklab.toOKLCH } // We can skip converting to XYZ first here.

	/**
	Convert to LCH.
	*/
	var toLCH: Colors.LCH { toXYZ.d65ToD50.toLab.toLCH }
}


extension Colors.OKLCH {
	/**
	Convert OKLCH to OkLab.
	*/
	var toOklab: Colors.Oklab {
		let hueRadians = hue * .pi / 180
		return .init(
			lightness: lightness,
			aDimension: chroma * cos(hueRadians),
			bDimension: chroma * sin(hueRadians),
			opacity: opacity
		)
	}

	/**
	Convert OKLCH to sRGB.
	*/
	var toResolved: Color.Resolved { toOklab.toResolved }
}


extension Colors.LCH {
	/**
	Convert LCH to sRGB.
	*/
	var toResolved: Color.Resolved { toLab.toXYZ.d50ToD65.toResolved }
}


extension Color.Resolved {
	/**
	Create from HSB components.
	*/
	static func fromHSB(
		hue: Double,
		saturation: Double,
		brightness: Double,
		opacity: Double = 1
	) -> Self {
		// TODO: Rewrite this to a pure Swift algorithm.
		Color(
			hue: hue,
			saturation: saturation,
			brightness: brightness,
			opacity: opacity
		)
		.resolve(in: .init())
	}

	var toHSB: Colors.HSB {
		// swiftlint:disable no_cgfloat
		var hue: CGFloat = 0
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		var opacity: CGFloat = 0
		// swiftlint:enable no_cgfloat

		// TODO: Rewrite this to a pure Swift algorithm.
		toXColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &opacity)

		return .init(
			hue: hue.toDouble,
			saturation: saturation.toDouble,
			brightness: brightness.toDouble,
			opacity: opacity.toDouble
		)
	}
}


extension Color.Resolved {
	/**
	Create from HSL components.
	*/
	static func fromHSL(
		hue: Double,
		saturation: Double,
		lightness: Double,
		opacity: Double
	) -> Self {
		let brightness = lightness + saturation * min(lightness, 1 - lightness)
		let newSaturation = brightness == 0 ? 0 : (2 * (1 - lightness / brightness))

		return fromHSB(
			hue: hue,
			saturation: newSaturation,
			brightness: brightness,
			opacity: opacity
		)
	}

	var toHSL: Colors.HSL {
		let hsb = toHSB

		var saturation = hsb.saturation * hsb.brightness
		var lightness = (2.0 - hsb.saturation) * hsb.brightness

		let saturationDivider = (lightness <= 1.0 ? lightness : 2.0 - lightness)
		if saturationDivider != 0 {
			saturation /= saturationDivider
		}

		lightness /= 2.0

		return .init(
			hue: hsb.hue,
			saturation: saturation,
			lightness: lightness,
			opacity: hsb.opacity
		)
	}
}


enum SettingsTabType {
	case general
	case advanced
	case shortcuts

	fileprivate var label: some View {
		switch self {
		case .general:
			Label("General", systemImage: "gearshape")
		case .advanced:
			Label("Advanced", systemImage: "gearshape.2")
		case .shortcuts:
			Label("Shortcuts", systemImage: "command")
		}
	}
}

extension View {
	/**
	Make the view a settings tab of the given type.
	*/
	func settingsTabItem(_ type: SettingsTabType) -> some View {
		tabItem { type.label }
	}

	func settingsTabItem(_ title: String, systemImage: String) -> some View {
		tabItem {
			Label(title, systemImage: systemImage)
		}
	}
}


extension Numeric {
	mutating func increment(by value: Self = 1) -> Self {
		self += value
		return self
	}

	mutating func decrement(by value: Self = 1) -> Self {
		self -= value
		return self
	}

	func incremented(by value: Self = 1) -> Self {
		self + value
	}

	func decremented(by value: Self = 1) -> Self {
		self - value
	}
}


#if !APP_EXTENSION
extension SSApp {
	private static let key = Defaults.Key("SSApp_requestReview", default: 0)

	/**
	Requests a review only after this method has been called the given amount of times.
	*/
	static func requestReviewAfterBeingCalledThisManyTimes(_ counts: [Int]) {
		guard
			!SSApp.isFirstLaunch,
			counts.contains(Defaults[key].increment())
		else {
			return
		}

		SKStoreReviewController.requestReview()
	}
}
#endif


/**
Store a value persistently in a `View` like with `@State`, but without updating the view on mutations.

You can use it for storing both value and reference types.
*/
@MainActor
@propertyWrapper
struct ViewStorage<Value>: DynamicProperty {
	private final class ValueBox: ObservableObject {
		let objectWillChange = Empty<Never, Never>(completeImmediately: false)
		var value: Value

		init(_ value: Value) {
			self.value = value
		}
	}

	@StateObject private var valueBox: ValueBox

	var wrappedValue: Value {
		get { valueBox.value }
		nonmutating set {
			valueBox.value = newValue
		}
	}

	init(wrappedValue value: @autoclosure @escaping () -> Value) {
		self._valueBox = StateObject(wrappedValue: .init(value()))
	}
}


extension Binding where Value: SetAlgebra, Value.Element: Hashable {
	/**
	Creates a `Bool` derived binding that reflects whether the original binding value contains the given element.

	For example, you can use this to create a list of checkboxes, and when a checkbox is unchecked, the element is removed from the `Set` and if checked, it's added back.

	```
	struct ContentView: View {
		@State private var foo = Set<String>(["unicorn", "rainbow"])

		var body: some View {
			Toggle(
				"Contains `unicorn`",
				isOn: $foo.contains("unicorn")
			)
		}
	}
	```
	*/
	func contains(_ element: Value.Element) -> Binding<Bool> {
		.init(
			get: { wrappedValue.contains(element) },
			set: {
				if $0 {
					wrappedValue.insert(element)
				} else {
					wrappedValue.remove(element)
				}
			}
		)
	}
}


/**
Creates a binding that sets a specified enum value when a condition is true and clears it (sets to nil if it equals the current value) when false.

- Parameters:
	- value: The enum value to be set when the condition is true.
	- boundValue: The binding to the optional enum variable that needs to be conditionally set or cleared.

- Returns: A Boolean binding that, when true, sets `boundValue` to `value`, and when false, sets `boundValue` to nil if it currently equals `value`.
*/
extension Binding where Value: Equatable {
	static func conditionalSetOrClearBinding<T: Equatable>(
		to value: T,
		with boundValue: Binding<T?>
	) -> Binding<Bool> {
		Binding<Bool>(
			get: { boundValue.wrappedValue == value },
			set: { isActive in
				if isActive {
					boundValue.wrappedValue = value
				} else if boundValue.wrappedValue == value {
					boundValue.wrappedValue = nil
				}
			}
		)
	}
}


extension Binding {
	/**
	Creates a binding to a value in a dictionary for a given key.

	- Parameters:
	 - key: The key for the value in the dictionary.

	- Returns: A binding to the value in the dictionary for the given key.
	*/
	subscript<T, V>(
		key: T
	) -> Binding<V?> where Value: SSDictionaryProtocol<T, V> {
		.init(
			get: { wrappedValue[key] },
			set: {
				wrappedValue[key] = $0
			}
		)
	}
}


struct MultiTogglePicker<Data: RandomAccessCollection, ElementLabel: View>: View where Data.Element: Hashable & Identifiable {
	let data: Data
	@Binding var selection: Set<Data.Element>
	@ViewBuilder var elementLabel: (Data.Element) -> ElementLabel

	var body: some View {
		ForEach(data) { element in
			Toggle(isOn: $selection.contains(element)) {
				elementLabel(element)
			}
		}
	}
}

typealias _OriginalMultiTogglePicker = MultiTogglePicker

#if !APP_EXTENSION
extension Defaults {
	struct MultiTogglePicker<Data: RandomAccessCollection, ElementLabel: View>: View where Data.Element: Hashable & Identifiable & Defaults.Serializable {
		typealias Element = Data.Element
		typealias Selection = Set<Element>

		@ViewStorage private var onChange: ((Selection) -> Void)?
		private let data: Data
		@Default private var selection: Selection
		private var elementLabel: (Element) -> ElementLabel

		init(
			key: Defaults.Key<Set<Data.Element>>,
			data: Data,
			@ViewBuilder elementLabel: @escaping (Element) -> ElementLabel
		) {
			self.data = data
			self._selection = .init(key)
			self.elementLabel = elementLabel
		}

		var body: some View {
			_OriginalMultiTogglePicker(
				data: data,
				selection: $selection
			) {
				elementLabel($0)
			}
				.onChange(of: selection) {
					onChange?(selection)
				}
		}
	}
}

extension Defaults.MultiTogglePicker {
	/**
	Do something when the value changes to a different value.
	*/
	func onChange(_ action: @escaping (Selection) -> Void) -> Self {
		onChange = action
		return self
	}
}
#endif


extension NSImage {
	/**
	Draw a color as an image.
	*/
	static func color(
		_ color: Color,
		size: CGSize,
		borderWidth: Double = 0,
		borderColor: Color? = nil,
		cornerRadius: Double? = nil
	) -> Self {
		// TODO: Render this with Canvas and ImageRender.
		Self(size: size, flipped: false) { bounds in
			NSGraphicsContext.current?.imageInterpolation = .high

			guard let cornerRadius else {
				color.toXColor.drawSwatch(in: bounds)
				return true
			}

			let targetRect = bounds.insetBy(
				dx: borderWidth,
				dy: borderWidth
			)

			let bezierPath = NSBezierPath(
				roundedRect: targetRect,
				xRadius: cornerRadius,
				yRadius: cornerRadius
			)

			color.toXColor.set()
			bezierPath.fill()

			if
				borderWidth > 0,
				let borderColor
			{
				borderColor.toXColor.setStroke()
				bezierPath.lineWidth = borderWidth
				bezierPath.stroke()
			}

			return true
		}
	}
}


extension SSApp {
	/**
	This is like `SSApp.runOnce()` but let's you have an else-statement too.

	```
	if SSApp.runOnceShouldRun(identifier: "foo") {
		// True only the first time and only once.
	} else {

	}
	```
	*/
	static func runOnceShouldRun(identifier: String) -> Bool {
		let key = "SS_App_runOnce__\(identifier)"

		guard !UserDefaults.standard.bool(forKey: key) else {
			return false
		}

		UserDefaults.standard.set(true, forKey: key)
		return true
	}

	/**
	Run a closure only once ever, even between relaunches of the app.
	*/
	static func runOnce(identifier: String, _ execute: () -> Void) {
		guard runOnceShouldRun(identifier: identifier) else {
			return
		}

		execute()
	}
}


extension Sequence where Element: Equatable {
	/**
	Returns a new sequence without the elements in the sequence that equals the given element.

	```
	[1, 2, 1, 2].removingAll(2)
	//=> [1, 1]
	```
	*/
	func removingAll(_ element: Element) -> [Element] {
		filter { $0 != element }
	}
}


extension Collection {
	func appending(_ newElement: Element) -> [Element] {
		self + [newElement]
	}
}


extension Collection {
	/**
	Truncate a collection to a certain count by removing elements from the end.
	*/
	func truncatingFromStart(toCount newCount: Int) -> [Element] {
		let removeCount = count - newCount

		guard removeCount > 0 else {
			return Array(self)
		}

		return Array(dropFirst(removeCount))
	}
}


extension Collection {
	var nilIfEmpty: Self? { isEmpty ? nil : self }
}


extension View {
	func multilineText() -> some View {
		lineLimit(nil)
			.fixedSize(horizontal: false, vertical: true)
	}
}


extension View {
	func secondaryTextStyle() -> some View {
		font(.system(size: NSFont.smallSystemFontSize))
			.foregroundColor(.secondary)
	}
}


extension View {
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View,
		@ViewBuilder message: () -> some View
	) -> some View {
		background(
			EmptyView()
				.alert(
					title,
					isPresented: isPresented,
					actions: actions,
					message: message
				)
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View,
		@ViewBuilder message: () -> some View
	) -> some View {
		alert2(
			Text(title),
			isPresented: isPresented,
			actions: actions,
			message: message
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		message: String? = nil,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View
	) -> some View {
		alert2(
			title,
			isPresented: isPresented,
			actions: actions,
			message: { // swiftlint:disable:this trailing_closure
				if let message {
					Text(message)
				}
			}
		)
	}

	// This is a convenience method and does not exist natively.
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		message: String? = nil,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View
	) -> some View {
		alert2(
			title,
			isPresented: isPresented,
			actions: actions,
			message: { // swiftlint:disable:this trailing_closure
				if let message {
					Text(message)
				}
			}
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		message: String? = nil,
		isPresented: Binding<Bool>
	) -> some View {
		alert2(
			title,
			message: message,
			isPresented: isPresented,
			actions: {} // swiftlint:disable:this trailing_closure
		)
	}

	// This is a convenience method and does not exist natively.
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		message: String? = nil,
		isPresented: Binding<Bool>
	) -> some View {
		alert2(
			title,
			message: message,
			isPresented: isPresented,
			actions: {} // swiftlint:disable:this trailing_closure
		)
	}
}


extension NSStatusItem {
	/**
	Show a one-time menu from the status item.
	*/
	@MainActor
	func showMenu(_ menu: NSMenu) {
		self.menu = menu
		button!.performClick(nil)
		self.menu = nil
	}
}


extension NSEvent {
	static var modifiers: ModifierFlags {
		modifierFlags
			.intersection(.deviceIndependentFlagsMask)
			// We remove `capsLock` as it shouldn't affect the modifiers.
			// We remove `numericPad`/`function` as arrow keys trigger it, use `event.specialKeys` instead.
			.subtracting([.capsLock, .numericPad, .function])
	}

	/**
	Real modifiers.

	- Note: Prefer this over `.modifierFlags`.

	```
	// Check if Command is one of possible more modifiers keys
	event.modifiers.contains(.command)

	// Check if Command is the only modifier key
	event.modifiers == .command

	// Check if Command and Shift are the only modifiers
	event.modifiers == [.command, .shift]
	```
	*/
	var modifiers: ModifierFlags {
		modifierFlags
			.intersection(.deviceIndependentFlagsMask)
			// We remove `capsLock` as it shouldn't affect the modifiers.
			// We remove `numericPad`/`function` as arrow keys trigger it, use `event.specialKeys` instead.
			.subtracting([.capsLock, .numericPad, .function])
	}
}


extension NSEvent {
	var isAlternativeMouseUp: Bool {
		type == .rightMouseUp
			|| (type == .leftMouseUp && modifiers == .control)
	}

	var isAlternativeClickForStatusItem: Bool {
		isAlternativeMouseUp
			|| (type == .leftMouseUp && modifiers == .option)
	}
}


extension NSError {
	static func appError(
		_ description: String,
		recoverySuggestion: String? = nil,
		userInfo: [String: Any] = [:],
		domainPostfix: String? = nil
	) -> Self {
		var userInfo = userInfo
		userInfo[NSLocalizedDescriptionKey] = description

		if let recoverySuggestion {
			userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
		}

		return .init(
			domain: domainPostfix.map { "\(SSApp.idString) - \($0)" } ?? SSApp.idString,
			code: 1, // This is what Swift errors end up as.
			userInfo: userInfo
		)
	}
}


enum OperatingSystem {
	case macOS
	case iOS
	case tvOS
	case watchOS

	#if os(macOS)
	static let current = macOS
	#elseif os(iOS)
	static let current = iOS
	#elseif os(tvOS)
	static let current = tvOS
	#elseif os(watchOS)
	static let current = watchOS
	#else
	#error("Unsupported platform")
	#endif
}

extension OperatingSystem {
	/**
	- Note: Only use this when you cannot use an `if #available` check. For example, inline in function calls.
	*/
	static let isMacOS16OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 16, *) {
			return true
		}

		return false
		#else
		false
		#endif
	}()

	/**
	- Note: Only use this when you cannot use an `if #available` check. For example, inline in function calls.
	*/
	static let isMacOS15OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 15, *) {
			return true
		}

		return false
		#else
		false
		#endif
	}()
}

typealias OS = OperatingSystem


extension Sequence where Element: Hashable {
	func removingDuplicates() -> [Element] {
		var seen = Set<Element>()
		return filter { seen.insert($0).inserted }
	}
}

extension Sequence where Element: Equatable {
	func removingDuplicates() -> [Element] {
		reduce(into: []) { result, element in
			if !result.contains(element) {
				result.append(element)
			}
		}
	}
}


extension NSColorList {
	static var all: [NSColorList] {
		availableColorLists
			.filter { !$0.allKeys.isEmpty }
			// `availableColorLists` returns duplicates after editing a palette, for example, adding a color to it.
			.removingDuplicates()
			.sorted(using: .keyPath(\.name))
	}

	var colors: [Color.Resolved] {
		allKeys.compactMap { color(withKey: $0)?.toResolvedColor }
	}

	var keysAndColors: [(key: NSColorList.Name, color: Color.Resolved)] {
		Array(zip(allKeys, colors))
	}
}


final class ListenOnlyPublisherObservable: ObservableObject {
	let objectWillChange = ObservableObjectPublisher()
	private var cancellable: AnyCancellable?

	init(for publisher: some Publisher) {
		self.cancellable = publisher.receive(on: DispatchQueue.main).sink(
			receiveCompletion: { _ in },
			receiveValue: { [weak self] _ in
				self?.objectWillChange.send()
			}
		)
	}
}

extension Publisher {
	func toListenOnlyObservableObject() -> ListenOnlyPublisherObservable { .init(for: self) }
}


extension Comparable {
	func clamped(to range: ClosedRange<Self>) -> Self {
		min(max(self, range.lowerBound), range.upperBound)
	}

	func clamped(to range: PartialRangeThrough<Self>) -> Self {
		min(self, range.upperBound)
	}

	func clamped(to range: PartialRangeFrom<Self>) -> Self {
		max(self, range.lowerBound)
	}
}

extension Strideable where Stride: SignedInteger {
	func clamped(to range: Range<Self>) -> Self {
		clamped(to: range.lowerBound...range.upperBound.advanced(by: -1))
	}

	func clamped(to range: PartialRangeUpTo<Self>) -> Self {
		min(self, range.upperBound.advanced(by: -1))
	}
}


extension Color.Resolved {
	var toColor: Color { .init(self) }

	var toXColor: XColor {
		.init(
			red: red.toDouble,
			green: green.toDouble,
			blue: blue.toDouble,
			alpha: opacity.toDouble
		)
	}
}


extension Color {
	/**
	Convert a `Color` to a `NSColor`/`UIColor`.
	*/
	var toXColor: XColor { XColor(self) }
}


extension XColor {
	/**
	Convert a `NSColor`/`UIColor` to a `Color`.
	*/
	var toColor: Color { Color(self) }

	var toResolvedColor: Color.Resolved { toColor.resolve(in: .init()) }
}


extension NSColorPanel {
	var resolvedColor: Color.Resolved {
		get { color.toResolvedColor }
		set {
			color = newValue.toXColor
		}
	}
}


extension SortComparator {
	static func keyPath<Compared, Value: Comparable>(
		_ keyPath: KeyPath<Compared, Value>,
		order: SortOrder = .forward
	) -> KeyPathComparator<Compared> where Self == KeyPathComparator<Compared> {
		.init(keyPath, order: order)
	}

	static func keyPath<Compared, Value: Comparable>(
		_ keyPath: KeyPath<Compared, Value?>,
		order: SortOrder = .forward
	) -> KeyPathComparator<Compared> where Self == KeyPathComparator<Compared> {
		.init(keyPath, order: order)
	}
}
