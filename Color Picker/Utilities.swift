import SwiftUI
import Combine
import Carbon
import Defaults
import Regex


enum SSApp {
	static let id = Bundle.main.bundleIdentifier!
	static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
	static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
	static let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
	static let versionWithBuild = "\(version) (\(build))"
	static let icon = NSApp.applicationIconImage!
	static let url = Bundle.main.bundleURL

	static func quit() {
		NSApp.terminate(nil)
	}

	static let isFirstLaunch: Bool = {
		let key = "SS_hasLaunched"

		if UserDefaults.standard.bool(forKey: key) {
			return false
		} else {
			UserDefaults.standard.set(true, forKey: key)
			return true
		}
	}()

	static func openSendFeedbackPage() {
		let metadata =
			"""
			\(SSApp.name) \(SSApp.versionWithBuild) - \(SSApp.id)
			macOS \(Device.osVersion)
			\(Device.hardwareModel)
			"""

		let query: [String: String] = [
			"product": SSApp.name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback/").addingDictionaryAsQuery(query).open()
	}

	static var isDockIconVisible: Bool {
		get { NSApp.activationPolicy() == .regular }
		set {
			NSApp.setActivationPolicy(newValue ? .regular : .accessory)
		}
	}
}


extension SSApp {
	/// Manually show the SwiftUI settings window.
	static func showSettingsWindow() {
		if NSApp.activationPolicy() == .accessory {
			NSApp.activate(ignoringOtherApps: true)
		}

		// Run in the next runloop so it doesn't conflict with SwiftUI if run at startup.
		DispatchQueue.main.async {
			NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
		}
	}
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
	var attributedString: NSAttributedString { NSAttributedString(string: self) }
}


extension NSAttributedString {
	/// Returns a `NSMutableAttributedString` version.
	func mutable() -> NSMutableAttributedString {
		// Force-casting here is safe as it can only be nil if there's no `mutableCopy` implementation, but we know there is for `NSMutableAttributedString`.
		// swiftlint:disable:next force_cast
		mutableCopy() as! NSMutableAttributedString
	}

	var nsRange: NSRange { NSRange(0..<length) }

	/// Get an attribute if it applies to the whole string.
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

	/// The `.font` attribute for the whole string, falling back to the system font if none.
	/// - Note: It even handles if half the string has one attribute and the other half has another, as long as those attributes are identical.
	var font: NSFont {
		attributeForWholeString(.font) as? NSFont ?? .systemFont(ofSize: NSFont.systemFontSize)
	}

	/// - Important: This does not preserve font-related styles like bold and italic.
	func withFontSizeFast(_ fontSize: Double) -> NSAttributedString {
		addingAttributes([.font: font.withSize(CGFloat(fontSize))])
	}

	func addingAttributes(_ attributes: [Key: Any]) -> NSAttributedString {
		let new = mutable()
		new.addAttributes(attributes, range: nsRange)
		return new
	}

	/// - Important: This does not preserve font-related styles like bold and italic.
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
		monitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] in
			guard let self = self else {
				return $0
			}

			self.objectWillChange.send($0)
			return self.callback?($0) ?? $0
		} as AnyObject

		return self
	}

	func stop() {
		guard let monitor = monitor else {
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
		guard let superview = superview else {
			assertionFailure("There is no superview for this view")
			return
		}

		constrainEdges(to: superview)
	}
}


extension NSColor {
	typealias RGBA = (
		red: Double,
		green: Double,
		blue: Double,
		alpha: Double
	)

	var rgba: RGBA {
		#if canImport(AppKit)
		guard let color = usingColorSpace(.extendedSRGB) else {
			assertionFailure("Unsupported color space")
			return RGBA(0, 0, 0, 0)
		}
		#elseif canImport(UIKit)
		let color = self
		#endif

		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0

		color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

		return RGBA(red.double, green.double, blue.double, alpha.double)
	}
}


extension NSColor {
	typealias HSBA = (hue: Double, saturation: Double, brightness: Double, alpha: Double)

	var hsba: HSBA {
		#if canImport(AppKit)
		guard let color = usingColorSpace(.extendedSRGB) else {
			assertionFailure("Unsupported color space")
			return HSBA(0, 0, 0, 0)
		}
		#elseif canImport(UIKit)
		let color = self
		#endif

		var hue: CGFloat = 0
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		var alpha: CGFloat = 0

		color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

		return HSBA(
			hue: hue.double,
			saturation: saturation.double,
			brightness: brightness.double,
			alpha: alpha.double
		)
	}
}


extension NSColor {
	typealias HSLA = (
		hue: Double,
		saturation: Double,
		lightness: Double,
		alpha: Double
	)

	/// - Important: Ensure you use a compatible color space, otherwise it will just be black.
	var hsla: HSLA {
		let hsba = self.hsba

		var saturation = hsba.saturation * hsba.brightness
		var lightness = (2.0 - hsba.saturation) * hsba.brightness

		let saturationDivider = (lightness <= 1.0 ? lightness : 2.0 - lightness)
		if saturationDivider != 0 {
			saturation /= saturationDivider
		}

		lightness /= 2.0

		return HSLA(
			hue: hsba.hue,
			saturation: saturation,
			lightness: lightness,
			alpha: hsba.alpha
		)
	}

	/**
	Create from HSL components.
	*/
	convenience init(
		colorSpace: NSColorSpace,
		hue: CGFloat,
		saturation: CGFloat,
		lightness: CGFloat,
		alpha: CGFloat
	) {
		precondition(
			0...1 ~= hue
				&& 0...1 ~= saturation
				&& 0...1 ~= lightness
				&& 0...1 ~= alpha,
			"Input is out of range 0...1"
		)

		let brightness = lightness + saturation * min(lightness, 1 - lightness)
		let newSaturation = brightness == 0 ? 0 : (2 * (1 - lightness / brightness))

		self.init(
			colorSpace: colorSpace,
			hue: hue,
			saturation: newSaturation,
			brightness: brightness,
			alpha: alpha
		)
	}
}


extension Color {
	/**
	Create a `Color` from HSL components.

	Assumes `extendedSRGB` input.
	*/
	init(
		hue: Double,
		saturation: Double,
		lightness: Double,
		opacity: Double
	) {
		precondition(
			0...1 ~= hue
				&& 0...1 ~= saturation
				&& 0...1 ~= lightness
				&& 0...1 ~= opacity,
			"Input is out of range 0...1"
		)

		let brightness = lightness + saturation * min(lightness, 1 - lightness)
		let newSaturation = brightness == 0 ? 0 : (2 * (1 - lightness / brightness))

		self.init(
			hue: hue,
			saturation: newSaturation,
			brightness: brightness,
			opacity: opacity
		)
	}
}


extension NSColor {
	private static let cssHSLRegex = Regex(#"^\s*hsla?\((?<hue>\d+)(?:deg)?[\s,]*(?<saturation>[\d.]+)%[\s,]*(?<lightness>[\d.]+)%\)\s*$"#)

	// TODO: Support `alpha` in HSL (both comma and `/` separated): https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/hsl()
	// TODO: Write a lot of tests for the regex.
	/// Assumes `sRGB` color space.
	convenience init?(cssHSLString: String) {
		guard
			let match = Self.cssHSLRegex.firstMatch(in: cssHSLString),
			let hueString = match.group(named: "hue")?.value,
			let saturationString = match.group(named: "saturation")?.value,
			let lightnessString = match.group(named: "lightness")?.value,
			let hue = Double(hueString),
			let saturation = Double(saturationString),
			let lightness = Double(lightnessString),
			(0...360).contains(hue),
			(0...100).contains(saturation),
			(0...100).contains(lightness)
		else {
			return nil
		}

		self.init(
			colorSpace: .sRGB,
			hue: hue.cgFloat / 360,
			saturation: saturation.cgFloat / 100,
			lightness: lightness.cgFloat / 100,
			alpha: 1
		)
	}
}


extension NSColor {
	private static let cssRGBRegex = Regex(#"^\s*rgba?\((?<red>[\d.]+)[\s,]*(?<green>[\d.]+)[\s,]*(?<blue>[\d.]+)\)\s*$"#)

	// TODO: Need to handle `rgb(10%, 10%, 10%)`.
	// TODO: Support `alpha` in RGB (both comma and `/` separated): https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/hsl()
	// TODO: Write a lot of tests for the regex.
	/// Assumes `sRGB` color space.
	convenience init?(cssRGBString: String) {
		guard
			let match = Self.cssRGBRegex.firstMatch(in: cssRGBString),
			let redString = match.group(named: "red")?.value,
			let greenString = match.group(named: "green")?.value,
			let blueString = match.group(named: "blue")?.value,
			let red = Double(redString),
			let green = Double(greenString),
			let blue = Double(blueString),
			(0...255).contains(red),
			(0...255).contains(green),
			(0...255).contains(blue)
		else {
			return nil
		}

		self.init(
			srgbRed: red.cgFloat,
			green: green.cgFloat,
			blue: blue.cgFloat,
			alpha: 1
		)
	}
}


extension NSColor {
	/**
	```
	NSColor(hex: 0xFFFFFF)
	```
	*/
	convenience init(hex: Int, alpha: Double = 1) {
		self.init(
			red: CGFloat((hex >> 16) & 0xFF) / 255,
			green: CGFloat((hex >> 8) & 0xFF) / 255,
			blue: CGFloat(hex & 0xFF) / 255,
			alpha: CGFloat(alpha)
		)
	}

	convenience init?(hexString: String, alpha: Double = 1) {
		var string = hexString

		if hexString.hasPrefix("#") {
			string = String(hexString.dropFirst())
		}

		if string.count == 3 {
			string = string.map { "\($0)\($0)" }.joined()
		}

		guard let hex = Int(string, radix: 16) else {
			return nil
		}

		self.init(hex: hex, alpha: alpha)
	}

	/**
	- Important: Don't forget to convert it to the correct color space first.

	```
	NSColor(hexString: "#fefefe")!.hex
	//=> 0xFEFEFE
	```
	*/
	var hex: Int {
		#if canImport(AppKit)
		guard numberOfComponents == 4 else {
			assertionFailure()
			return 0x0
		}
		#endif

		let red = Int((redComponent * 0xFF).rounded())
		let green = Int((greenComponent * 0xFF).rounded())
		let blue = Int((blueComponent * 0xFF).rounded())

		return red << 16 | green << 8 | blue
	}

	/**
	- Important: Don't forget to convert it to the correct color space first.

	```
	NSColor(hexString: "#fefefe")!.hexString
	//=> "#fefefe"
	```
	*/
	var hexString: String {
		String(format: "#%06x", hex)
	}
}


extension NSColor {
	enum ColorStringFormat {
		case hex(isUppercased: Bool = false, hasPrefix: Bool = false)
		case hsl
		case rgb
		case hslLegacy
		case rgbLegacy
	}

	/// Format the color to a string using the given format.
	func format(_ format: ColorStringFormat) -> String {
		switch format {
		case .hex(let isUppercased, let hasPrefix):
			var string = hexString

			if isUppercased {
				string = string.uppercased()
			}

			if !hasPrefix {
				string = string.dropFirst().string
			}

			return string
		case .hsl:
			let hsla = self.hsla
			let hue = Int((hsla.hue * 360).rounded())
			let saturation = Int((hsla.saturation * 100).rounded())
			let lightness = Int((hsla.lightness * 100).rounded())
			return String(format: "hsl(%ddeg %d%% %d%%)", hue, saturation, lightness)
		case .rgb:
			let rgba = self.rgba
			let red = Int((rgba.red * 0xFF).rounded())
			let green = Int((rgba.green * 0xFF).rounded())
			let blue = Int((rgba.blue * 0xFF).rounded())
			return String(format: "rgb(%d %d %d)", red, green, blue)
		case .hslLegacy:
			let hsla = self.hsla
			let hue = Int((hsla.hue * 360).rounded())
			let saturation = Int((hsla.saturation * 100).rounded())
			let lightness = Int((hsla.lightness * 100).rounded())
			return String(format: "hsl(%d, %d%%, %d%%)", hue, saturation, lightness)
		case .rgbLegacy:
			let rgba = self.rgba
			let red = Int((rgba.red * 0xFF).rounded())
			let green = Int((rgba.green * 0xFF).rounded())
			let blue = Int((rgba.blue * 0xFF).rounded())
			return String(format: "rgb(%d, %d, %d)", red, green, blue)
		}
	}
}


extension StringProtocol {
	/// Makes it easier to deal with optional SubStrings.
	var string: String { String(self) }
}


extension NSPasteboard {
	func with(_ callback: (NSPasteboard) -> Void) {
		clearContents()
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


extension Double {
	/// Get a CGFloat from a Double. This makes it easier to work with optionals.
	var cgFloat: CGFloat { CGFloat(self) }
}

extension CGFloat {
	/// Get a Double from a CGFloat. This makes it easier to work with optionals.
	var double: Double { Double(self) }
}

extension Int {
	/// Get a Double from an Int. This makes it easier to work with optionals.
	var double: Double { Double(self) }

	/// Get a CGFloat from an Int. This makes it easier to work with optionals.
	var cgFloat: CGFloat { CGFloat(self) }
}


extension DispatchQueue {
	/**
	Performs the `execute` closure immediately if we're on the main thread or asynchronously puts it on the main thread otherwise.
	*/
	static func mainSafeAsync(execute work: @escaping () -> Void) {
		if Thread.isMainThread {
			work()
		} else {
			main.async(execute: work)
		}
	}
}


extension Binding where Value: Equatable {
	/**
	Get notified when the binding value changes to a different one.

	Can be useful to manually update non-reactive properties.

	```
	Toggle(
		"Foo",
		isOn: $foo.onChange {
			bar.isEnabled = $0
		}
	)
	```
	*/
	func onChange(_ action: @escaping (Value) -> Void) -> Self {
		.init(
			get: { wrappedValue },
			set: {
				let oldValue = wrappedValue
				wrappedValue = $0
				let newValue = wrappedValue
				if newValue != oldValue {
					action(newValue)
				}
			}
		)
	}
}


extension Defaults {
	final class Observable<Value: Codable>: ObservableObject {
		let objectWillChange = ObservableObjectPublisher()
		private var observation: DefaultsObservation?
		private let key: Defaults.Key<Value>

		var value: Value {
			get { Defaults[key] }
			set {
				objectWillChange.send()
				Defaults[key] = newValue
			}
		}

		init(_ key: Key<Value>) {
			self.key = key

			self.observation = Defaults.observe(key, options: [.prior]) { [weak self] change in
				guard change.isPrior else {
					return
				}

				DispatchQueue.mainSafeAsync {
					self?.objectWillChange.send()
				}
			}
		}

		/// Reset the key back to its default value.
		func reset() {
			key.reset()
		}
	}
}


extension Defaults {
	/**
	Creates a SwiftUI `Toggle` view that is connected to a Bool `Defaults` key.

	```
	struct ShowAllDayEventsSetting: View {
		var body: some View {
			Defaults.Toggle("Show All-Day Events", key: .showAllDayEvents)
		}
	}
	```
	*/
	struct Toggle<Label, Key>: View where Label: View, Key: Defaults.Key<Bool> {
		// TODO: Find a way to store the handler without using an embedded class.
		private final class OnChangeHolder {
			var onChange: ((Bool) -> Void)?
		}

		private let label: () -> Label
		@ObservedObject private var observable: Defaults.Observable<Bool>
		private let onChangeHolder = OnChangeHolder()

		init(key: Key, @ViewBuilder label: @escaping () -> Label) {
			self.label = label
			self.observable = Defaults.Observable(key)
		}

		var body: some View {
			SwiftUI.Toggle(isOn: $observable.value, label: label)
				.onChange(of: observable.value) {
					onChangeHolder.onChange?($0)
				}
		}
	}
}

extension Defaults.Toggle where Label == Text {
	init<S>(_ title: S, key: Defaults.Key<Bool>) where S: StringProtocol {
		self.label = { Text(title) }
		self.observable = Defaults.Observable(key)
	}
}

extension Defaults.Toggle {
	/// Do something when the value changes to a different value.
	func onChange(_ action: @escaping (Bool) -> Void) -> Self {
		onChangeHolder.onChange = action
		return self
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
		private var eventMonitor: LocalEventMonitor?

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

			// Cannot be `.leftMouseUp` as the color wheel swallows it.
			eventMonitor = LocalEventMonitor(events: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
				guard let self = self else {
					return nil
				}

				if event.type == .keyDown {
					if event.keyCode == kVK_Escape {
						return nil
					}

					return event
				}

				let clickPoint = self.convert(event.locationInWindow, from: nil)
				let clickMargin: CGFloat = 3

				if !self.frame.insetBy(dx: -clickMargin, dy: -clickMargin).contains(clickPoint) {
					self.blur()
					return nil
				}

				return event
			}.start()

			return super.becomeFirstResponder()
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
			parent.isFocused = false
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

		if let font = font {
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
	/// Show the color sampler.
	func showColorSampler() {
		// "_magnify:"
		let selector = String(":yfingam_".reversed())
		perform(NSSelectorFromString(selector))
	}
}


extension NSColorPanel {
	/**
	Publishes when the color in the color panel changes.
	*/
	var colorDidChangePublisher: AnyPublisher<Void, Never> {
		NotificationCenter.default
			.publisher(for: Self.colorDidChangeNotification, object: self)
			.map { _ in }
			.eraseToAnyPublisher()
	}
}


extension NSAlert {
	/// Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
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

	/// The index in the `buttonTitles` array for the button to use as default.
	/// Set `-1` to not have any default. Useful for really destructive actions.
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

		if let message = message {
			self.informativeText = message
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex = defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/// Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window = window else {
			return runModal()
		}

		beginSheetModal(for: window) { returnCode in
			NSApp.stopModal(withCode: returnCode)
		}

		return NSApp.runModal(for: window)
	}

	/// Adds buttons with the given titles to the alert.
	func addButtons(withTitles buttonTitles: [String]) {
		for buttonTitle in buttonTitles {
			addButton(withTitle: buttonTitle)
		}
	}
}


extension View {
	func onNotification(
		/// Make the view subscribe to the given notification.
		_ name: Notification.Name,
		object: AnyObject? = nil,
		perform action: @escaping (Notification) -> Void
	) -> some View {
		onReceive(NotificationCenter.default.publisher(for: name, object: object)) {
			action($0)
		}
	}
}


private var controlActionClosureProtocolAssociatedObjectKey: UInt8 = 0

protocol ControlActionClosureProtocol: NSObjectProtocol {
	var target: AnyObject? { get set }
	var action: Selector? { get set }
}

private final class ActionTrampoline<T>: NSObject {
	let action: (T) -> Void

	init(action: @escaping (T) -> Void) {
		self.action = action
	}

	@objc
	func action(sender: AnyObject) {
		// This is safe as it can only be `T`.
		// swiftlint:disable:next force_cast
		action(sender as! T)
	}
}

extension ControlActionClosureProtocol {
	/**
	Closure version of `.action`

	```
	let button = NSButton(title: "Unicorn", target: nil, action: nil)

	button.onAction { sender in
		print("Button action: \(sender)")
	}
	```
	*/
	func onAction(_ action: @escaping (Self) -> Void) {
		let trampoline = ActionTrampoline(action: action)
		target = trampoline
		self.action = #selector(ActionTrampoline<Self>.action(sender:))
		objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
	}
}

extension NSControl: ControlActionClosureProtocol {}
extension NSMenuItem: ControlActionClosureProtocol {}


extension NSWindow {
	func toggle() {
		if isVisible, isKeyWindow {
			performClose(nil)
		} else {
			if NSApp.activationPolicy() == .accessory {
				NSApp.activate(ignoringOtherApps: true)
			}

			makeKeyAndOrderFront(nil)
		}
	}
}


final class CallbackMenuItem: NSMenuItem {
	private static var validateCallback: ((NSMenuItem) -> Bool)?

	static func validate(_ callback: @escaping (NSMenuItem) -> Bool) {
		validateCallback = callback
	}

	init(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isHidden: Bool = false,
		callback: @escaping (NSMenuItem) -> Void
	) {
		self.callback = callback
		super.init(title: title, action: #selector(action(_:)), keyEquivalent: key)
		self.target = self
		self.isEnabled = isEnabled
		self.isHidden = isHidden

		if let keyModifiers = keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	@available(*, unavailable)
	required init(coder decoder: NSCoder) {
		fatalError() // swiftlint:disable:this fatal_error_message
	}

	private let callback: (NSMenuItem) -> Void

	@objc
	func action(_ sender: NSMenuItem) {
		callback(sender)
	}
}

extension CallbackMenuItem: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		Self.validateCallback?(menuItem) ?? true
	}
}


extension NSMenu {
	@discardableResult
	func addCallbackItem(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		callback: @escaping (NSMenuItem) -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isHidden: isHidden,
			callback: callback
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addSettingsItem() -> NSMenuItem {
		addCallbackItem("Preferences…", key: ",") { _ in
			SSApp.showSettingsWindow()
		}
	}

	@discardableResult
	func addQuitItem() -> NSMenuItem {
		addSeparator()

		return addCallbackItem("Quit \(SSApp.name)", key: "q") { _ in
			SSApp.quit()
		}
	}

	func addSeparator() {
		addItem(.separator())
	}
}


private struct RespectDisabledViewModifier: ViewModifier {
	@Environment(\.isEnabled) private var isEnabled

	func body(content: Content) -> some View {
		content.opacity(isEnabled ? 1 : 0.5)
	}
}

extension Text {
	/// Make some text respect the current view environment being disabled.
	/// Useful for `Text` label to a control.
	func respectDisabled() -> some View {
		modifier(RespectDisabledViewModifier())
	}
}


/// Convenience for opening URLs.
extension URL {
	func open() {
		NSWorkspace.shared.open(self)
	}
}


extension String {
	/*
	```
	"https://sindresorhus.com".openUrl()
	```
	*/
	func openUrl() {
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
	/// Bind the native backing-window of a SwiftUI window to a property.
	func bindNativeWindow(_ window: Binding<NSWindow?>) -> some View {
		background(WindowAccessor(window))
	}
}

private struct WindowViewModifier: ViewModifier {
	@State private var window: NSWindow?

	let onWindow: (NSWindow?) -> Void

	func body(content: Content) -> some View {
		onWindow(window)

		return content
			.bindNativeWindow($window)
	}
}

extension View {
	/// Access the native backing-window of a SwiftUI window.
	func accessNativeWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
		modifier(WindowViewModifier(onWindow: onWindow))
	}

	/// Set the window level of a SwiftUI window.
	func windowLevel(_ level: NSWindow.Level) -> some View {
		accessNativeWindow {
			$0?.level = level
		}
	}
}
