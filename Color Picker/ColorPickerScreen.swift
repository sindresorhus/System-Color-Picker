import SwiftUI
import Defaults

private struct RecentlyPickedColorsButton: View {
	@EnvironmentObject private var appState: AppState
	@Default(.recentlyPickedColors) private var recentlyPickedColors

	// TODO: Find a better way to handle this than having to subscribe to each key.
	@Default(.preferredColorFormat) private var preferredColorFormat // Only to get updates
	@Default(.uppercaseHexColor) private var uppercaseHexColor // Only to get updates
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor // Only to get updates
	@Default(.legacyColorSyntax) private var legacyColorSyntax // Only to get updates

	var body: some View {
		Menu {
			Group {
				ForEach(recentlyPickedColors.reversed()) { color in
					Button {
						appState.colorPanel.color = color
					} label: {
						Label {
							Text(color.stringRepresentation)
						} icon: {
							// We don't use SwiftUI here as it only supports showing an actual image. (macOS 12.0)
							// https://github.com/feedback-assistant/reports/issues/247
							Image(nsImage: color.swatchImage)
						}
							.labelStyle(.titleAndIcon)
					}
				}
				Divider()
				Button("Clear") {
					recentlyPickedColors = []
				}
			}
				// Without, it becomes disabled. (macOS 12.4)
				.buttonStyle(.automatic)
		} label: {
			Image(systemName: "clock.fill")
				.controlSize(.large)
//				.padding(8) // Has no effect. (macOS 12.0.1)
				.contentShape(.rectangle)
		}
			.menuIndicator(.hidden)
			.padding(8)
			.fixedSize()
			.opacity(0.6) // Try to match the other buttons.
			.disabled(recentlyPickedColors.isEmpty)
			.help(recentlyPickedColors.isEmpty ? "No recently picked colors" : "Recently picked colors")
	}
}

private struct BarView: View {
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var appState: AppState
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general).stop()
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		HStack(spacing: 12) {
			Button {
				appState.pickColor()
			} label: {
				Image(systemName: "eyedropper")
					.font(.system(size: 14).bold())
					.padding(8)
			}
				.contentShape(.rectangle)
				.help("Pick color")
				.keyboardShortcut("p")
				.padding(.leading, 4)
			Button {
				appState.pasteColor()
			} label: {
				Image(systemName: "paintbrush.fill")
					.padding(8)
			}
				.contentShape(.rectangle)
				.help("Paste color in the format Hex, HSL, RGB, or LCH")
				.keyboardShortcut("v", modifiers: [.shift, .command])
				.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
			RecentlyPickedColorsButton()
			moreButton
			Spacer()
		}
			// Cannot do this as the `Menu` buttons don't respect it. (macOS 12.0.1)
			// https://github.com/feedback-assistant/reports/issues/249
//			.font(.title3)
			.background2 {
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.fill(Color.black.opacity(colorScheme == .dark ? 0.17 : 0.05))
			}
			.padding(.vertical, 4)
			.buttonStyle(.borderless)
			.menuStyle(.borderlessButton)
			.onAppearOnScreen {
				pasteboardObserver.start()
			}
			.onDisappearFromScreen {
				pasteboardObserver.stop()
			}
	}

	private var moreButton: some View {
		Menu {
			Button("Copy as HSB") {
				appState.colorPanel.color.hsbColorString.copyToPasteboard()
			}
			if showInMenuBar {
				Divider()
				Button(OS.isMacOS13OrLater ? "Settings…" : "Preferences…") {
					SSApp.showSettingsWindow()
				}
					.keyboardShortcut(",")
			}
		} label: {
			Label("More", systemImage: "ellipsis.circle.fill")
				.labelStyle(.iconOnly)
//				.padding(8) // Has no effect. (macOS 12.0.1)
		}
			.buttonStyle(.automatic) // Without, it becomes disabled: https://github.com/feedback-assistant/reports/issues/250 (macOS 12.0.1)
			.padding(8)
			.contentShape(.rectangle)
			.fixedSize()
			.opacity(0.6) // Try to match the other buttons.
			.menuIndicator(.hidden)
	}
}

struct ColorInputView: View {
    @EnvironmentObject private var appState: AppState
    @State private var textColor: Color = .primary
    @Binding var inputColorText: String
    @Binding var isTextFieldFocused: Bool
    @Binding var isPreventingUpdate: Bool
    let colorPanel: NSColorPanel
    let textFieldFontSize: Double
    let inputColorType: ColorFormat

    var body: some View {
        HStack {
            // TODO: When I use `TextField`, add the copy button using `.safeAreaInset()`.
            NativeTextField(
                text: $inputColorText,
                placeholder: inputColorType.rawValue,
                font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
                isFocused: $isTextFieldFocused,
                textColor: textColor
            )
                .controlSize(.large)
                .onChange(of: inputColorText) {
                    switch inputColorType {
                    case .hex:
                        if inputColorText.count > 6 {
                            if inputColorText.prefix(1) == "#" {
                                inputColorText = inputColorText.prefix(7).toString
                            } else {
                                inputColorText = inputColorText.prefix(6).toString
                            }
                        }

                        var hexColor = $0

                        if hexColor.hasPrefix("##") {
                            hexColor = hexColor.dropFirst().toString
                            inputColorText = hexColor
                        }

                        if
                            isTextFieldFocused,
                            !isPreventingUpdate,
                            let newColor = NSColor(hexString: inputColorText.trimmingCharacters(in: .whitespaces))
                        {
                            colorPanel.color = newColor
                        }

                        if NSColor(hexString: inputColorText.trimmingCharacters(in: .whitespaces)) != nil {
                            textColor = .primary
                        } else {
                            textColor = .red
                        }

                        if !isPreventingUpdate {
                          // updateColorsFromPanel(excludeHex: true, preventUpdate: true) // TODO: Method needs refactoring to work here
                        }
                    case .hsl:
                        if
                            isTextFieldFocused,
                            !isPreventingUpdate,
                            let newColor = NSColor(cssHSLString: inputColorText.trimmingCharacters(in: .whitespaces))
                        {
                            colorPanel.color = newColor
                        }

                        if NSColor(cssHSLString: inputColorText.trimmingCharacters(in: .whitespaces)) != nil {
                            textColor = .primary
                        } else {
                            textColor = .red
                        }

                        if !isPreventingUpdate {
                            // updateColorsFromPanel(excludeHSL: true, preventUpdate: true)
                        }
                    case .rgb:
                        return
                    case .lch:
                        return
                    }
                }
            Button("Copy \(inputColorType.rawValue)", systemImage: "doc.on.doc.fill") {
                switch inputColorType {
                case .hex:
                    appState.colorPanel.color.hexColorString.copyToPasteboard()
                case .hsl:
                    appState.colorPanel.color.hslColorString.copyToPasteboard()
                case .rgb:
                    return
                case .lch:
                    return
                }
            }
                .labelStyle(.iconOnly)
                .symbolRenderingMode(.hierarchical)
                .buttonStyle(.borderless)
                .contentShape(.rectangle)
                .keyboardShortcut(inputColorType.keyboardShortcut, modifiers: [.shift, .command])
        }
    }
}

struct ColorPickerScreen: View {
	@EnvironmentObject private var appState: AppState
	@Default(.uppercaseHexColor) private var uppercaseHexColor
	@Default(.hashPrefixInHexColor) private var hashPrefixInHexColor
	@Default(.legacyColorSyntax) private var legacyColorSyntax
	@Default(.shownColorFormats) private var shownColorFormats
	@Default(.largerText) private var largerText
	@State private var hexColor = ""
	@State private var hslColor = ""
	@State private var rgbColor = ""
	@State private var lchColor = ""
	@State private var isTextFieldFocusedHex = false
	@State private var isTextFieldFocusedHSL = false
	@State private var isTextFieldFocusedRGB = false
	@State private var isTextFieldFocusedLCH = false
	@State private var isPreventingUpdate = false
    @State private var textColor = Color.primary

	let colorPanel: NSColorPanel

	private var isAnyTextFieldFocused: Bool {
		isTextFieldFocusedHex
			|| isTextFieldFocusedHSL
			|| isTextFieldFocusedRGB
			|| isTextFieldFocusedLCH
	}

	private var textFieldFontSize: Double { largerText ? 16 : 0 }

	private var rgbColorView: some View {
		HStack {
			NativeTextField(
				text: $rgbColor,
				placeholder: "RGB",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedRGB,
                textColor: textColor
			)
				.controlSize(.large)
				.onChange(of: rgbColor) {
					if
						isTextFieldFocusedRGB,
						!isPreventingUpdate,
						let newColor = NSColor(cssRGBString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeRGB: true, preventUpdate: true)
					}
				}
			Button("Copy RGB", systemImage: "doc.on.doc.fill") {
				rgbColor.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("r", modifiers: [.shift, .command])
		}
	}

	private var lchColorView: some View {
		HStack {
			NativeTextField(
				text: $lchColor,
				placeholder: "LCH",
				font: .monospacedSystemFont(ofSize: textFieldFontSize, weight: .regular),
				isFocused: $isTextFieldFocusedLCH,
                textColor: textColor
			)
				.controlSize(.large)
				.onChange(of: lchColor) {
					if
						isTextFieldFocusedLCH,
						!isPreventingUpdate,
						let newColor = NSColor(cssLCHString: $0.trimmingCharacters(in: .whitespaces))
					{
						colorPanel.color = newColor
					}

					if !isPreventingUpdate {
						updateColorsFromPanel(excludeLCH: true, preventUpdate: true)
					}
				}
			Button("Copy LCH", systemImage: "doc.on.doc.fill") {
				lchColor.copyToPasteboard()
			}
				.labelStyle(.iconOnly)
				.symbolRenderingMode(.hierarchical)
				.buttonStyle(.borderless)
				.contentShape(.rectangle)
				.keyboardShortcut("l", modifiers: [.shift, .command])
		}
	}

	var body: some View {
		VStack {
			BarView()
			if shownColorFormats.contains(.hex) {
                ColorInputView(
                    inputColorText: $hexColor,
                    isTextFieldFocused: $isTextFieldFocusedHex,
                    isPreventingUpdate: $isPreventingUpdate,
                    colorPanel: colorPanel,
                    textFieldFontSize: textFieldFontSize,
                    inputColorType: .hex
                )
			}
			if shownColorFormats.contains(.hsl) {
                ColorInputView(
                    inputColorText: $hslColor,
                    isTextFieldFocused: $isTextFieldFocusedHSL,
                    isPreventingUpdate: $isPreventingUpdate,
                    colorPanel: colorPanel,
                    textFieldFontSize: textFieldFontSize,
                    inputColorType: .hsl
                )
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
				guard !isAnyTextFieldFocused else {
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

extension ColorFormat {
    fileprivate var keyboardShortcut: KeyEquivalent {
        switch self {
        case .hex:
            return KeyEquivalent("h")
        case .hsl:
            return KeyEquivalent("s")
        case .rgb:
            return KeyEquivalent("r")
        case .lch:
            return KeyEquivalent("l")
        }
    }
}

struct ColorPickerScreen_Previews: PreviewProvider {
	static var previews: some View {
		ColorPickerScreen(colorPanel: .shared)
	}
}
