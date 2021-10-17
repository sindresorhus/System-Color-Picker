import SwiftUI
import Defaults
import LaunchAtLogin
import KeyboardShortcuts

private struct MenuBarItemClickActionSetting: View {
	@Default(.menuBarItemClickAction) private var menuBarItemClickAction

	var body: some View {
		VStack {
			EnumPicker(
				enumBinding: $menuBarItemClickAction,
				label: Text("When clicking menu bar icon:")
					.respectDisabled()
					.fixedSize()
			) { element, _ in
				Text(element.title)
			}
				.fixedSize()
			Text(menuBarItemClickAction.tip)
				.settingSubtitleTextStyle()
				.frame(maxWidth: .infinity, alignment: .trailing)
		}
	}
}

private struct PreferredColorFormatSetting: View {
	@Default(.preferredColorFormat) private var preferredColorFormat

	var body: some View {
		EnumPicker(
			enumBinding: $preferredColorFormat,
			label: Text("Preferred color format:")
				.fixedSize()
		) { element, _ in
			Text(element.title)
		}
			.fixedSize()
	}
}

private struct ShownColorFormatsSetting: View {
	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text("Shown color formats:")
			// TODO: Use a dropdown when SwiftUI supports multiple selections in `Picker`.
			Defaults.MultiCheckboxPicker(
				key: .shownColorFormats,
				data: ColorFormat.allCases
			) {
				Text($0.title)
			}
		}
			.accessibilityElement(children: .combine)
			.help("Choose which color formats to show in the color picker window. Disabled formats will still show up in the “Color” menu.")
	}
}

private struct GeneralSettings: View {
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		Form {
			VStack(alignment: .leading) {
				Defaults.Toggle("Stay on top", key: .stayOnTop)
					.help("Make the color picker window stay on top of all other windows.")
					.padding(.bottom, 8)
				Defaults.Toggle("Show in menu bar instead of Dock", key: .showInMenuBar)
					.help("If you have “Keep in Dock” enabled when activating this preference, you should disable that since the Dock icon will no longer be functional.")
				Group {
					LaunchAtLogin.Toggle()
						.help(showInMenuBar ? "" : "There is really no point in launching the app at login if it is not in the menu bar. You can instead just put it in the Dock and launch it when needed.")
					MenuBarItemClickActionSetting()
				}
					.disabled(!showInMenuBar)
					.padding(.leading, 19)
			}
		}
			.padding()
			.padding()
			.padding(.vertical)
	}
}

private struct ColorSettings: View {
	var body: some View {
		Form {
			VStack(alignment: .leading) {
				VStack(alignment: .leading) {
					Defaults.Toggle("Uppercase Hex color", key: .uppercaseHexColor)
					Defaults.Toggle("Prefix Hex color with #", key: .hashPrefixInHexColor)
					Defaults.Toggle("Use legacy syntax for HSL and RGB", key: .legacyColorSyntax)
						.help("Use the legacy “hsl(198, 28%, 50%)” syntax instead of the modern “hsl(198deg 28% 50%)” syntax. This setting is meant for users that need to support older browsers. All modern browsers support the modern syntax.")
				}
					.padding()
					.padding(.horizontal)
				Divider()
				VStack(alignment: .leading) {
					PreferredColorFormatSetting()
				}
					.padding()
					.padding(.horizontal)
				Divider()
				VStack(alignment: .leading) {
					ShownColorFormatsSetting()
				}
					.padding()
					.padding(.horizontal)
					.offset(x: 10)
				Divider()
				HStack {
					Link("What is LCH color?", destination: "https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/")
						.controlSize(.small)
						.padding(.top)
				}
					.frame(maxWidth: .infinity)
			}
		}
			.padding(.vertical)
	}
}

private struct ShortcutsSettings: View {
	@Default(.showInMenuBar) private var showInMenuBar
	private let maxWidth = 100.0

	var body: some View {
		Form {
			VStack {
				HStack(alignment: .firstTextBaseline) {
					Text("Pick color:")
						.respectDisabled()
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .pickColor)
				}
					.accessibilityElement(children: .combine)
					.padding(.bottom, 8)
				HStack(alignment: .firstTextBaseline) {
					Text("Toggle window:")
						.respectDisabled()
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .toggleWindow)
				}
					.accessibilityElement(children: .combine)
					.disabled(!showInMenuBar)
					.overlay(
						showInMenuBar
							? nil
							: Text("Requires “Show in menu bar” to be enabled.")
								.font(.system(size: 10))
								.foregroundColor(.secondary)
								.offset(y: 20),
						alignment: .bottom
					)
					.padding(.bottom, showInMenuBar ? 0 : 20)
			}
		}
			.padding()
			.padding()
			.padding(.vertical)
			.offset(x: -10)
	}
}

private struct AdvancedSettings: View {
	var body: some View {
		Form {
			VStack(alignment: .leading) {
				VStack(alignment: .leading) {
					Defaults.Toggle("Show color sampler when opening window", key: .showColorSamplerOnOpen)
						.help("Show the color picker loupe when the color picker window is shown.")
					Defaults.Toggle("Copy color in preferred format after picking", key: .copyColorAfterPicking)
					Defaults.Toggle("Use larger text in text fields", key: .largerText)
				}
					.padding()
					.padding(.horizontal)
			}
		}
			.padding(.vertical)
			.padding(.vertical)
	}
}

struct SettingsView: View {
	var body: some View {
		TabView {
			GeneralSettings()
				.settingsTabItem(.general)
			ColorSettings()
				.tabItem {
					Label("Color", systemImage: "drop.fill")
				}
			ShortcutsSettings()
				.settingsTabItem(.shortcuts)
			AdvancedSettings()
				.settingsTabItem(.advanced)
		}
			.frame(width: 420)
			.windowLevel(.floating + 1) // Ensure it's always above the color picker.
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
