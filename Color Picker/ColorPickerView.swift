import SwiftUI
import Defaults

private struct RecentlyPickedColorsButton: View {
	@EnvironmentObject private var appState: AppState
	@Default(.recentlyPickedColors) private var recentlyPickedColors
	@Default(.preferredColorFormat) private var preferredColorFormat // Only to get updates

	var body: some View {
		Menu {
			ForEach(recentlyPickedColors.reversed()) { color in
				Button {
					appState.colorPanel.color = color
				} label: {
					// TODO: Using `Label` does not work. (macOS 11.6)
					HStack {
						// We don't use SwiftUI here as it only supports showing an actual image. (macOS 11.6)
						Image(nsImage: color.swatchImage)
						Text(color.stringRepresentation)
					}
				}
			}
		} label: {
			Image(systemName: "clock.fill")
		}
			// TODO: Use `.menuIndicator(.hidden)` when using Xcode 13.1.
			.menuStyle(BorderedButtonMenuStyle())
			.fixedSize()
			.disabled(recentlyPickedColors.isEmpty)
			.help(recentlyPickedColors.isEmpty ? "No recently picked colors" : "Recently picked colors")
	}
}

private struct BarView: View {
	@EnvironmentObject private var appState: AppState
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general).stop()

	var body: some View {
		HStack {
			Button {
				appState.pickColor()
			} label: {
				Image(systemName: "eyedropper")
			}
				.help("Pick color")
				.keyboardShortcut("p")
			Button {
				appState.pasteColor()
			} label: {
				Image(systemName: "paintbrush.fill")
			}
				.help("Paste color in the format Hex, HSL, RGB, or LCH")
				.keyboardShortcut("V")
				.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
			RecentlyPickedColorsButton()
			Spacer()
		}
			.onAppearOnScreen {
				pasteboardObserver.start()
			}
			.onDisappearFromScreen {
				pasteboardObserver.stop()
			}
	}
}

struct ColorPickerView: View {
	@Default(.uppercaseHexColor) private var uppercaseHexColor
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor
	@Default(.legacyColorSyntax) private var legacyColorSyntax
	@Default(.shownColorFormats) private var shownColorFormats
	@Default(.largerText) private var largerText
	@State private var hexColor = ""
	@State private var hslColor = ""
	@State private var rgbColor = ""
	@State private var lchColor = ""
	@State private var isPreventingUpdate = false
	@State private var isTextFieldFocused = false

	let colorPanel: NSColorPanel

	private var textFieldFontSize: Double { largerText ? 16 : 0 }

	private var hexColorView: some View {
		HStack {
			NativeTextField(
				text: $hexColor,
				placeholder: "Hex",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocused
			)
				.controlSize(.large)
				.onChange(of: hexColor) {
					if
						isTextFieldFocused,
						!isPreventingUpdate,
						let newColor = NSColor(hexString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeHex: true, preventUpdate: true)
					}
				}
			Button {
				hexColor.copyToPasteboard()
			} label: {
				Image(systemName: "doc.on.doc.fill")
					.controlSize(.small)
			}
				.keyboardShortcut("H")
		}
	}

	private var hslColorView: some View {
		HStack {
			NativeTextField(
				text: $hslColor,
				placeholder: "HSL",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocused
			)
				.controlSize(.large)
				.onChange(of: hslColor) {
					if
						isTextFieldFocused,
						!isPreventingUpdate,
						let newColor = NSColor(cssHSLString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeHSL: true, preventUpdate: true)
					}
				}
			Button {
				hslColor.copyToPasteboard()
			} label: {
				Image(systemName: "doc.on.doc.fill")
					.controlSize(.small)
			}
				.keyboardShortcut("S")
		}
	}

	private var rgbColorView: some View {
		HStack {
			NativeTextField(
				text: $rgbColor,
				placeholder: "RGB",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocused
			)
				.controlSize(.large)
				.onChange(of: rgbColor) {
					if
						isTextFieldFocused,
						!isPreventingUpdate,
						let newColor = NSColor(cssRGBString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeRGB: true, preventUpdate: true)
					}
				}
			Button {
				rgbColor.copyToPasteboard()
			} label: {
				Image(systemName: "doc.on.doc.fill")
					.controlSize(.small)
			}
				.keyboardShortcut("R")
		}
	}

	private var lchColorView: some View {
		HStack {
			NativeTextField(
				text: $lchColor,
				placeholder: "LCH",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocused
			)
				.controlSize(.large)
				.onChange(of: lchColor) {
					if
						isTextFieldFocused,
						!isPreventingUpdate,
						let newColor = NSColor(cssLCHString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeLCH: true, preventUpdate: true)
					}
				}
			Button {
				lchColor.copyToPasteboard()
			} label: {
				Image(systemName: "doc.on.doc.fill")
					.controlSize(.small)
			}
				.keyboardShortcut("L")
		}
	}

	var body: some View {
		VStack {
			BarView()
			if shownColorFormats.contains(.hex) {
				hexColorView
			}
			if shownColorFormats.contains(.hsl) {
				hslColorView
			}
			if shownColorFormats.contains(.rgb) {
				rgbColorView
			}
			if shownColorFormats.contains(.lch) {
				lchColorView
			}
		}
			.padding(9)
			// 244 makes `HSL` always fit in the text field.
			.frame(minWidth: 244, maxWidth: .infinity)
			.onAppear {
				updateColorsFromPanel()
			}
			.onChange(of: uppercaseHexColor) { _ in
				updateColorsFromPanel()
			}
			.onChange(of: hashPrefixInHexColor) { _ in
				updateColorsFromPanel()
			}
			.onChange(of: legacyColorSyntax) { _ in
				updateColorsFromPanel()
			}
			.onReceive(colorPanel.colorDidChangePublisher) {
				guard !isTextFieldFocused else {
					return
				}

				updateColorsFromPanel(preventUpdate: true)
			}
	}

	// TODO: Find a better way to handle this.
	private func updateColorsFromPanel(
		excludeHex: Bool = false,
		excludeHSL: Bool = false,
		excludeRGB: Bool = false,
		excludeLCH: Bool = false,
		preventUpdate: Bool = false
	) {
		if preventUpdate {
			isPreventingUpdate = true
		}

		let color = colorPanel.color

		if !excludeHex {
			hexColor = color.hexColorString
		}

		if !excludeHSL {
			hslColor = color.hslColorString
		}

		if !excludeRGB {
			rgbColor = color.rgbColorString
		}

		if !excludeLCH {
			lchColor = color.lchColorString
		}

		if preventUpdate {
			DispatchQueue.main.async {
				isPreventingUpdate = false
			}
		}
	}
}

struct ColorPickerView_Previews: PreviewProvider {
	static var previews: some View {
		ColorPickerView(colorPanel: NSColorPanel.shared)
	}
}
