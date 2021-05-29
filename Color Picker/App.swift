import SwiftUI

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general, onlyWhileAppIsActive: true)

	var body: some Scene {
		WindowGroup {
			if false {}
		}
			// TODO: How to replace `File` menu with `Color`?
			// TODO: Remove `View` menu.
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandMenu("Color") {
					Button("Pick") {
						appState.pickColor()
					}
						.keyboardShortcut("p")
					Divider()
					Button("Copy as Hex") {
						appState.colorPanel.hexColorString.copyToPasteboard()
					}
						.keyboardShortcut("H")
					Button("Copy as HSL") {
						appState.colorPanel.hslColorString.copyToPasteboard()
					}
						.keyboardShortcut("S")
					Button("Copy as RGB") {
						appState.colorPanel.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("R")
					Button("Copy as LCH") {
						appState.colorPanel.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("L")
					Button("Paste") {
						appState.pasteColor()
					}
						.help("Paste color in the format Hex, HSL, RGB, or LCH")
						.keyboardShortcut("V")
						.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
				}
				CommandGroup(replacing: .help) {
					Button("What is LCH color?") {
						"https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/".openUrl()
					}
					Button("FAQ") {
						"https://github.com/sindresorhus/System-Color-Picker#faq".openUrl()
					}
					Divider()
					// TODO: Use `Link` when it's supported here.
					Button("Website") {
						"https://sindresorhus.com/system-color-picker".openUrl()
					}
					Button("Rate on the App Store") {
						"macappstore://apps.apple.com/app/id1545870783?action=write-review".openUrl()
					}
					Button("More Apps by Me") {
						"macappstore://apps.apple.com/developer/id328077650".openUrl()
					}
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
		Settings {
			SettingsView()
		}
	}
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
