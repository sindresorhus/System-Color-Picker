import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsScreen: View {
	var body: some View {
		TabView {
			GeneralSettings()
				.settingsTabItem(.general)
			ColorSettings()
				.settingsTabItem("Color", systemImage: "drop.fill")
			ShortcutsSettings()
				.settingsTabItem(.shortcuts)
			AdvancedSettings()
				.settingsTabItem(.advanced)
		}
			.formStyle(.grouped)
			.frame(width: 460)
			.frame(maxHeight: 480)
			.fixedSize()
			.windowLevel(.utility + 1) // Ensure it's always above the color picker.
	}
}

#Preview {
	SettingsScreen()
}

private struct GeneralSettings: View {
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		Form {
			Section {
				Defaults.Toggle("Show in menu bar instead of Dock", key: .showInMenuBar)
					.help("If you have “Keep in Dock” enabled when activating this setting, you should disable that since the Dock icon will no longer be functional.")
				if showInMenuBar {
					LaunchAtLogin.Toggle()
						.help("There is really no point in launching the app at login if it is not in the menu bar. You can instead just put it in the Dock and launch it when needed.")
					HideMenuBarIconSetting()
					MenuBarItemClickActionSetting()
				}
			}
			Section {
				Defaults.Toggle("Stay on top", key: .stayOnTop)
					.help("Make the color picker window stay on top of all other windows.")
				Defaults.Toggle("Copy color in preferred format after picking", key: .copyColorAfterPicking)
			}
			Section {} footer: {
				Button("Feedback & Support") {
					SSApp.openSendFeedbackPage()
				}
					.buttonStyle(.link)
					.controlSize(.small)
			}
		}
	}
}

private struct ColorSettings: View {
	var body: some View {
		Form {
			Section {
				PreferredColorFormatSetting()
				ShownColorFormatsSetting()
			}
			Section {
				Defaults.Toggle("Uppercase Hex color", key: .uppercaseHexColor)
				Defaults.Toggle("Prefix Hex color with #", key: .hashPrefixInHexColor)
				Defaults.Toggle("Use legacy syntax for HSL and RGB", key: .legacyColorSyntax)
					.help("Use the legacy “hsl(198, 28%, 50%)” syntax instead of the modern “hsl(198deg 28% 50%)” syntax. This setting is meant for users that need to support older browsers. All modern browsers support the modern syntax.")
			}
			Section {} footer: {
				Link("What is LCH color?", destination: "https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/")
					.controlSize(.small)
			}
		}
	}
}

private struct ShortcutsSettings: View {
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		Form {
			KeyboardShortcuts.Recorder("Pick color", name: .pickColor)
			KeyboardShortcuts.Recorder(for: .toggleWindow) {
				Text("Toggle window")
				if !showInMenuBar {
					Text("Requires “Show in menu bar” to be enabled")
				}
			}
				.disabled(!showInMenuBar)
		}
	}
}

private struct AdvancedSettings: View {
	var body: some View {
		Form {
			Defaults.Toggle("Show color sampler when opening window", key: .showColorSamplerOnOpen)
				.help("Show the color picker loupe when the color picker window is shown.")
			Defaults.Toggle("Use larger text in text fields", key: .largerText)
			Defaults.Toggle("Show accessibility color name", key: .showAccessibilityColorName)
			StickyPaletteSetting()
		}
	}
}

private struct HideMenuBarIconSetting: View {
	@State private var isAlertPresented = false

	var body: some View {
		Defaults.Toggle("Hide menu bar icon", key: .hideMenuBarIcon)
			.onChange {
				isAlertPresented = $0
			}
			.help("This can be useful if you only use this app with the global keyboard shortcuts.")
			.alert2(
				"If you need to access the menu bar icon, launch the app to reveal it for 5 seconds.",
				isPresented: $isAlertPresented
			)
	}
}

private struct MenuBarItemClickActionSetting: View {
	@Default(.menuBarItemClickAction) private var menuBarItemClickAction

	var body: some View {
		EnumPicker(selection: $menuBarItemClickAction) {
			Text($0.title)
		} label: {
			Text("When clicking menu bar icon")
			Text(menuBarItemClickAction.tip)
		}
	}
}

private struct PreferredColorFormatSetting: View {
	@Default(.preferredColorFormat) private var preferredColorFormat

	var body: some View {
		EnumPicker("Preferred color format", selection: $preferredColorFormat) {
			Text($0.title)
		}
	}
}

private struct ShownColorFormatsSetting: View {
	var body: some View {
		LabeledContent("Shown color formats") {
			Defaults.MultiTogglePicker(
				key: .shownColorFormats,
				data: ColorFormat.allCases
			) {
				Text($0.title)
			}
		}
			.help("Choose which color formats to show in the color picker window. Disabled formats will still show up in the “Color” menu.")
	}
}

private struct StickyPaletteSetting: View {
	@Default(.stickyPaletteName) private var stickyPalette
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		Picker(selection: $stickyPalette) {
			Text("None")
				.tag(nil as String?)
			Divider()
			ForEach(NSColorList.all, id: \.self) { colorList in
				if let name = colorList.name {
					Text(name)
						.tag(name as String?)
				}
			}
		} label: {
			Text("Sticky palette")
			Text(showInMenuBar ? "Palette to show at the top-level of the menu bar menu and at the top of the palette menu in the color picker window" : "Palette to show at the top of the palette menu")
		}
	}
}
