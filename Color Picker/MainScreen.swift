import SwiftUI
import TipKit

struct MainScreen: View {
	// Note to self: Do not access the color picker here as it would create an infinite loop.

	@Default(.uppercaseHexColor) private var uppercaseHexColor
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor
	@Default(.legacyColorSyntax) private var legacyColorSyntax
	@Default(.shownColorFormats) private var shownColorFormats
	@Default(.largerText) private var largerText
	@Default(.showAccessibilityColorName) private var showAccessibilityColorName
	@State private var isPreventingUpdate = false
	@State private var focusedTextField: ColorFormat?
	@State private var colorStrings = EnumCaseMap<ColorFormat, String>(defaultValue: "")
	@State private var colorAccessibilityName: String?

	let colorPanel: NSColorPanel

	var body: some View {
		VStack {
			BarView()
			colorInputs
			colorName
			if SSApp.isFirstLaunch { // Note: We only show it on first launch as TipKit doesn't currently preserve the dismissed state. (macOS 14.3)
				TipView(ColorPaletteTip())
			}
		}
			.padding(9)
			// 244 makes `HSL` always fit in the text field.
			.frame(minWidth: 244, maxWidth: .infinity)
			.task {
				updateColorsFromPanel()
			}
			// TODO: Use a tuple here when tuples can be equatable.
			.onChange(of: uppercaseHexColor) {
				updateColorsFromPanel()
			}
			.onChange(of: hashPrefixInHexColor) {
				updateColorsFromPanel()
			}
			.onChange(of: legacyColorSyntax) {
				updateColorsFromPanel()
			}
			.onReceive(colorPanel.colorDidChange) {
				colorAccessibilityName = colorPanel.color.accessibilityName

				guard focusedTextField == nil else {
					return
				}

				updateColorsFromPanel(preventUpdate: true)
			}
			.task {
				try? Tips.configure()
			}
	}

	private func updateColorsFromPanel(
		excluding excludedFormat: ColorFormat? = nil,
		preventUpdate: Bool = false
	) {
		if preventUpdate {
			isPreventingUpdate = true
		}

		let color = colorPanel.resolvedColor

		for format in ColorFormat.allCases where format != excludedFormat {
			colorStrings[format] = color.colorString(for: format)
		}

		if preventUpdate {
			DispatchQueue.main.async {
				isPreventingUpdate = false
			}
		}
	}

	private func updateColorFromTextField(
		colorFormat: ColorFormat,
		colorString: String
	) {
		guard
			focusedTextField == colorFormat,
			!isPreventingUpdate
		else {
			return
		}

		var colorString = colorString

		if colorFormat == .hex {
			if colorString.hasPrefix("##") {
				colorString = colorString.dropFirst().toString
				colorStrings[.hex] = colorString
			}
		}

		let newColor = switch colorFormat {
		case .hex:
			Color.Resolved(cssHexString: colorString)
		case .hsl:
			Color.Resolved(cssHSLString: colorString)
		case .rgb:
			Color.Resolved(cssRGBString: colorString)
		case .oklch:
			Color.Resolved(cssOKLCHString: colorString)
		case .lch:
			Color.Resolved(cssLCHString: colorString)
		}

		guard let newColor else {
			return
		}

		colorPanel.resolvedColor = newColor
		updateColorsFromPanel(excluding: colorFormat, preventUpdate: true)
	}

	private var colorInputs: some View {
		ForEach(ColorFormat.allCases.filter(allowedValues: shownColorFormats)) { colorFormat in
			ColorInputView(
				colorFormat: colorFormat,
				colorString: $colorStrings[colorFormat],
				focusedTextField: $focusedTextField
			) { newColor in
				updateColorFromTextField(
					colorFormat: colorFormat,
					colorString: newColor
				)
			}
		}
	}

	@ViewBuilder
	private var colorName: some View {
		if showAccessibilityColorName {
			Text(colorAccessibilityName ?? colorPanel.color.accessibilityName)
				.font(.system(largerText ? .title3 : .body))
				.textSelection(.enabled)
				.accessibilityHidden(true)
		}
	}
}

#Preview {
	MainScreen(colorPanel: .shared)
}

private struct ColorInputView: View {
	@Default(.largerText) private var largerText

	let colorFormat: ColorFormat
	@Binding var colorString: String
	@Binding var focusedTextField: ColorFormat?
	let updateColor: (String) -> Void

	var body: some View {
		HStack {
			NativeTextField(
				text: $colorString,
				placeholder: colorFormat.title,
				font: .monospacedSystemFont(ofSize: largerText ? 16 : 0, weight: .regular),
				isFocused: .conditionalSetOrClearBinding(to: colorFormat, with: $focusedTextField)
			)
			.controlSize(.large)
			.onChange(of: colorString) {
				updateColor(colorString)
			}
			Button("Copy \(colorFormat.title)", systemImage: "doc.on.doc.fill") {
				colorString.copyToPasteboard()
			}
			.labelStyle(.iconOnly)
			.symbolRenderingMode(.hierarchical)
			.buttonStyle(.borderless)
			.contentShape(.rect)
			.keyboardShortcut(colorFormat.keyboardShortcutKey, modifiers: [.shift, .command])
		}
	}
}

private struct BarView: View {
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		HStack(spacing: 12) {
			pickColorButton
			PasteColorButton()
			RecentlyPickedColorsButton()
			PalettesButton()
			MoreButton()
			Spacer()
		}
			// Cannot do this as the `Menu` buttons don't respect it. (macOS 13.2)
			// https://github.com/feedback-assistant/reports/issues/249
//			.font(.title3)
			.background {
				RoundedRectangle(cornerRadius: 6)
					.fill(Color.black.opacity(colorScheme == .dark ? 0.17 : 0.05))
			}
			.padding(.vertical, 4)
			.buttonStyle(.borderless)
	}

	@MainActor
	private var pickColorButton: some View {
		Button {
			AppState.shared.pickColor()
		} label: {
			Image(systemName: "eyedropper")
				.font(.system(size: 14).bold())
				.padding(8)
		}
			.contentShape(.rect)
			.help("Pick color")
			.keyboardShortcut("p")
			.padding(.leading, 4)
	}
}

private struct PasteColorButton: View {
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general).stop()

	var body: some View {
		Button {
			AppState.shared.pasteColor()
		} label: {
			Image(systemName: "paintbrush.fill")
				.padding(8)
		}
			.contentShape(.rect)
			.help("Paste color in the format Hex, HSL, RGB, OKLCH, or LCH")
			.keyboardShortcut("v", modifiers: [.shift, .command])
			.disabled(Color.Resolved.fromPasteboardGraceful(.general) == nil)
			.onAppearOnScreen {
				pasteboardObserver.start()
			}
			.onDisappearFromScreen {
				pasteboardObserver.stop()
			}
	}
}

private struct MoreButton: View {
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		Menu {
			Button("Copy as HSB") {
				AppState.shared.colorPanel.resolvedColor.ss_hsbColorString.copyToPasteboard()
			}
			if showInMenuBar {
				Divider()
				Defaults.Toggle("Stay on Top", key: .stayOnTop)
				Divider()
				Button("Settings…") {
					SSApp.showSettingsWindow()
				}
					.keyboardShortcut(",")
			}
		} label: {
			Label("More", systemImage: "ellipsis.circle.fill")
				.labelStyle(.iconOnly)
//				.padding(8) // Has no effect. (macOS 12.0.1)
		}
			.menuIndicator(.hidden)
			.padding(8)
			.contentShape(.rect)
			.opacity(0.6) // Try to match the other buttons.
	}
}

private struct RecentlyPickedColorsButton: View {
	@Default(.recentlyPickedColors) private var recentlyPickedColors

	// TODO: Find a better way to handle this than having to subscribe to each key.
	@Default(.preferredColorFormat) private var preferredColorFormat // Only to get updates
	@Default(.uppercaseHexColor) private var uppercaseHexColor // Only to get updates
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor // Only to get updates
	@Default(.legacyColorSyntax) private var legacyColorSyntax // Only to get updates

	var body: some View {
		Menu {
			Group {
				ForEach(recentlyPickedColors.map(\.toResolvedColor).reversed(), id: \.self) { color in
					Button {
						AppState.shared.colorPanel.resolvedColor = color
					} label: {
						Label {
							Text(color.ss_stringRepresentation)
						} icon: {
							// We don't use SwiftUI here as it only supports showing an actual image. (macOS 14.0)
							// https://github.com/feedback-assistant/reports/issues/247
							Image(nsImage: color.toColor.swatchImage(size: Constants.swatchImageSize))
						}
							.labelStyle(.titleAndIcon)
					}
				}
				Divider()
				Button("Clear") {
					recentlyPickedColors = []
				}
			}
		} label: {
			Image(systemName: "clock.fill")
				.controlSize(.large)
//				.padding(8) // Has no effect. (macOS 12.0.1)
				.contentShape(.rect)
		}
			.menuIndicator(.hidden)
			.padding(8)
			.opacity(0.6) // Try to match the other buttons.
			.disabled(recentlyPickedColors.isEmpty)
			.help(recentlyPickedColors.isEmpty ? "No recently picked colors" : "Recently picked colors")
	}
}

private struct PalettesButton: View {
	@StateObject private var updates = NotificationCenter.default.publisher(for: NSColorList.didChangeNotification).toListenOnlyObservableObject()
	@Default(.stickyPaletteName) private var stickyPaletteName

	var body: some View {
		let colorLists = NSColorList.all.withoutStickyPalette()
		Menu {
			if
				let colorListName = stickyPaletteName,
				let colorList = NSColorList(named: colorListName)
			{
				Section(colorListName) {
					createColorList(colorList)
				}
			}
			Section {
				ForEach(colorLists, id: \.name) { colorList in
					if let name = colorList.name {
						Menu(name) {
							createColorList(colorList)
						}
					}
				}
			}
		} label: {
			Image(systemName: "swatchpalette.fill")
				.controlSize(.large)
//				.padding(8) // Has no effect. (macOS 12.0.1)
				.contentShape(.rect)
		}
			.menuIndicator(.hidden)
			.padding(8)
			.opacity(0.6) // Try to match the other buttons.
			.disabled(colorLists.isEmpty)
			.help(colorLists.isEmpty ? "No palettes" : "Palettes")
	}

	private func createColorList(_ colorList: NSColorList) -> some View {
		ForEach(Array(colorList.keysAndColors), id: \.key) { key, color in
			Button {
				AppState.shared.colorPanel.resolvedColor = color
			} label: {
				Label {
					Text(key)
				} icon: {
					// We don't use SwiftUI here as it only supports showing an actual image. (macOS 14.0)
					// https://github.com/feedback-assistant/reports/issues/247
					Image(nsImage: color.toColor.swatchImage(size: Constants.swatchImageSize))
				}
					.labelStyle(.titleAndIcon)
			}
		}
	}
}

private struct ColorPaletteTip: Tip {
	var title: Text {
		Text("Creating a Color Palette")
	}

	var message: Text? {
		Text("To create a new color palette, click the third tab at the top of the window, click the \(Image(systemName: "ellipsis.circle")) button, and then select “New”.")
	}

	var image: Image? {
		Image(systemName: "swatchpalette")
	}
}
