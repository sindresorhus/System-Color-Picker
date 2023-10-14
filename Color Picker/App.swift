import SwiftUI

/**
NOTES:
- The "com.apple.security.files.user-selected.read-only" entitlement is required by the "Open" menu in the "Color Palettes" pane.

TODO:
 - test the action when not already running:
  if NSApp.activationPolicy() == .prohibited {
	  SSApp.url.open()
  }
- Show screenshot in App Store of the palette in menu bar.

- Use `Color.Resolved` instead of `XColor` and `RGBA`.

TODO shortcut action ideas;
- Convert color
- Toggle color panel
- Toggle color sampler in app
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general, onlyWhileAppIsActive: true)

	init() {
		setUpConfig()
	}

	var body: some Scene {
		WindowGroup {
			if false {}
		}
			// TODO: How to replace `File` menu with `Color`?
			// TODO: Would be nice to be able to remove the `View` menu: https://github.com/feedback-assistant/reports/issues/252
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandMenu("Color") {
					Button("Pick") {
						appState.pickColor()
					}
						.keyboardShortcut("p")
					Divider()
					Button("Copy as Hex") {
						appState.colorPanel.color.hexColorString.copyToPasteboard()
					}
						.keyboardShortcut("h", modifiers: [.shift, .command])
					Button("Copy as HSL") {
						appState.colorPanel.color.hslColorString.copyToPasteboard()
					}
						.keyboardShortcut("s", modifiers: [.shift, .command])
					Button("Copy as RGB") {
						appState.colorPanel.color.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("r", modifiers: [.shift, .command])
					Button("Copy as LCH") {
						appState.colorPanel.color.lchColorString.copyToPasteboard()
					}
						.keyboardShortcut("l", modifiers: [.shift, .command])
					Button("Paste") {
						appState.pasteColor()
					}
						.help("Paste color in the format Hex, HSL, RGB, or LCH")
						.keyboardShortcut("v", modifiers: [.shift, .command])
						.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
				}
				CommandGroup(after: .windowSize) {
					Defaults.Toggle("Stay on Top", key: .stayOnTop)
						.keyboardShortcut("t", modifiers: [.control, .command])
				}
				CommandGroup(replacing: .help) {
					Link("What is LCH color?", destination: "https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/")
					Link("FAQ", destination: "https://github.com/sindresorhus/System-Color-Picker#faq")
					Link("Website", destination: "https://sindresorhus.com/system-color-picker")
					Divider()
					Link("Rate App", destination: "macappstore://apps.apple.com/app/id1545870783?action=write-review")
					// TODO: Doesn't work. (macOS 14.0)
//					ShareLink("Share App", item: "https://apps.apple.com/app/id1545870783")
					Link("More Apps by Me", destination: "macappstore://apps.apple.com/developer/id328077650")
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
		Settings {
			SettingsScreen()
		}
	}

	private func setUpConfig() {
		SSApp.initSentry("https://e89cb93d693444ee8829f521ab75025a@o844094.ingest.sentry.io/6139060")
	}
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		SSApp.swiftUIMainWindow?.close()
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		AppState.shared.handleAppReopen()
		return false
	}
}
