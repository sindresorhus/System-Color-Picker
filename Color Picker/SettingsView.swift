import SwiftUI
import Defaults
import LaunchAtLogin
import KeyboardShortcuts

private struct ShowInMenuBarSetting: View {
	@State private var isShowingTip = false

	var body: some View {
		Defaults.Toggle("Show in menu bar", key: .showInMenuBar)
			.onChange {
				guard $0 else {
					return
				}

				isShowingTip = true
			}
			.alert(isPresented: $isShowingTip) {
				Alert(
					title: Text("Tips"),
					message: Text("Click the menu bar icon to toggle the color picker window.\n\nRight-click the menu bar icon to quit the app or access the preferences.")
				)
			}
	}
}

private struct KeyboardShortcutSetting: View {
	@Default(.showInMenuBar) private var showInMenuBar

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text("Toggle Window:")
				.respectDisabled()
			KeyboardShortcuts.Recorder(for: .toggleWindow)
		}
			.disabled(!showInMenuBar)
			.overlay(
				showInMenuBar
					? nil
					: Text("Requires “Show in menu bar” to be enabled.")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
						.offset(y: 20),
				alignment: .bottomLeading
			)
			.padding(.bottom, showInMenuBar ? 0 : 20)
	}
}

struct SettingsView: View {
	var body: some View {
		Form {
			VStack(alignment: .leading) {
				ShowInMenuBarSetting()
				LaunchAtLogin.Toggle()
				Defaults.Toggle("Stay on top", key: .stayOnTop)
					.help("Make the color picker window stay on top of all other windows.")
				Defaults.Toggle("Show color sampler when opening window", key: .showColorSamplerOnOpen)
					.help("Show the color picker loupe when the color picker window is shown.")
				Defaults.Toggle("Uppercase Hex color", key: .uppercaseHexColor)
				Defaults.Toggle("Use legacy syntax for HSL and RGB", key: .legacyColorSyntax)
					.help("Use the legacy “hsl(198, 28%, 50%)” syntax instead of the modern “hsl(198deg 28% 50%)” syntax. This setting is meant for users that need to support older browsers. All modern browsers support the modern syntax.")
				Divider()
					.padding(.vertical)
				KeyboardShortcutSetting()
			}
		}
			.padding()
			.padding()
			.frame(width: 380)
			.windowLevel(.floating + 1) // Ensure it's always above the color picker.
	}
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
