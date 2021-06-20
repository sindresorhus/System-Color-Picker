import SwiftUI
import Defaults

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
	@State private var hexColor = ""
	@State private var hslColor = ""
	@State private var rgbColor = ""
	@State private var lchColor = ""
	@State private var isPreventingUpdate = false
	@State private var isTextFieldFocused = false

	let colorPanel: NSColorPanel

	private var hexColorView: some View {
		HStack {
			NativeTextField(
				text: $hexColor,
				placeholder: "Hex",
				font: .monospacedSystemFont(ofSize: 0, weight: .regular),
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
				font: .monospacedSystemFont(ofSize: 0, weight: .regular),
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
				font: .monospacedSystemFont(ofSize: 0, weight: .regular),
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
				font: .monospacedSystemFont(ofSize: 0, weight: .regular),
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

		if !excludeHex {
			hexColor = colorPanel.hexColorString
		}

		if !excludeHSL {
			hslColor = colorPanel.hslColorString
		}

		if !excludeRGB {
			rgbColor = colorPanel.rgbColorString
		}

		if !excludeLCH {
			lchColor = colorPanel.lchColorString
		}

		if preventUpdate {
			DispatchQueue.main.async {
				isPreventingUpdate = false
			}
		}
	}
}

extension NSColorPanel {
	var hexColorString: String {
		color.usingColorSpace(.sRGB)!.format(
			.hex(
				isUppercased: Defaults[.uppercaseHexColor],
				hasPrefix: Defaults[.hashPrefixInHexColor]
			)
		)
	}

	var hslColorString: String {
		color.usingColorSpace(.sRGB)!.format(Defaults[.legacyColorSyntax] ? .hslLegacy : .hsl)
	}

	var rgbColorString: String {
		color.usingColorSpace(.sRGB)!.format(Defaults[.legacyColorSyntax] ? .rgbLegacy : .rgb)
	}

	var lchColorString: String {
		color.usingColorSpace(.sRGB)!.format(.lch)
	}
}

struct ColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
		ColorPickerView(colorPanel: NSColorPanel.shared)
    }
}
