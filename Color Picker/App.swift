import SwiftUI

/**
TODO macOS 15:
- Migrate `recentlyPickedColors` to `Color.Resolved`.
- Write regex tests using swift-test.

TODO shortcut action ideas:
- Convert color
- Toggle color panel
- Toggle color sampler in app
*/

@main
struct AppMain: App {
	private let appState = AppState.shared
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general, onlyWhileAppIsActive: true)

	init() {
		setUpConfig()

		// TODO: Change the default from LCH to OKLCH.
		// We set this so we can change it later on.
		SSApp.runOnce(identifier: "asdsadewr34323432432") {
			Defaults[.shownColorFormats] = SSApp.isFirstLaunch ? [.hex, .hsl, .rgb, .oklch] : Defaults[.shownColorFormats]
		}
	}

	var body: some Scene {
		WindowGroup {
			if false {}
		}
			.handlesExternalEvents(matching: []) // Makes sure it does not open a new window when dragging files onto the Dock icon.
			// TODO: How to replace `File` menu with `Color`?
			// TODO: Would be nice to be able to remove the `View` menu: https://github.com/feedback-assistant/reports/issues/252
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandMenu("Color") {
					lazy var color = appState.colorPanel.resolvedColor // It crashes when not lazy.
					Button("Pick") {
						appState.pickColor()
					}
					.keyboardShortcut("p")
					Divider()
					ForEach(ColorFormat.allCases) { colorFormat in
						Button("Copy as \(colorFormat.title)") {
							color.colorString(for: colorFormat).copyToPasteboard()
						}
						.keyboardShortcut(colorFormat.keyboardShortcutKey, modifiers: [.shift, .command])
					}
					Button("Paste") {
						appState.pasteColor()
					}
					.help("Paste color in the format Hex, HSL, RGB, OKLCH, or LCH")
					.keyboardShortcut("v", modifiers: [.shift, .command])
					.disabled(Color.Resolved.fromPasteboardGraceful(.general) == nil)
					Divider()
					Button("Reset Opacity") {
						appState.colorPanel.resolvedColor = color.withOpacity(1)
					}
					.keyboardShortcut("o", modifiers: [.shift, .control])
					// This crashes. (macOS 14.3)
//					.disabled(color.opacity == 1)
				}
				CommandGroup(after: .windowSize) {
					Defaults.Toggle("Stay on Top", key: .stayOnTop)
						.keyboardShortcut("t", modifiers: [.control, .command])
				}
				CommandGroup(replacing: .help) {
					Link("What is OKLCH color?", destination: "https://evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl")
					Link("FAQ", destination: "https://github.com/sindresorhus/System-Color-Picker#faq")
					Link("Website", destination: "https://sindresorhus.com/system-color-picker")
					Divider()
					Link("Rate App", destination: "macappstore://apps.apple.com/app/id1545870783?action=write-review")
					// TODO: Doesn't work. (macOS 14.2)
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

	func application(_ application: NSApplication, open urls: [URL]) {
		for url in urls {
			AppState.shared.importColorPalette(url)
		}
	}

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = SSMenu()

		menu.addCallbackItem("Pick Color") {
			AppState.shared.pickColor()
		}

		return menu
	}
}

/**
NOTES:
- The "com.apple.security.files.user-selected.read-only" entitlement is required by the "Open" menu in the "Color Palettes" pane.
*/
