import SwiftUI

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared

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
						appState.colorPanel.showColorSampler()
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
						.keyboardShortcut("L")
					Button("Copy as RGB") {
						appState.colorPanel.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("R")
					Button("Paste Color") {
						guard let color = NSColor.fromPasteboardGraceful(.general) else {
							return
						}

						appState.colorPanel.color = color
					}
						.keyboardShortcut("V")
						// TODO: I need to use `FocusedBinding` to disable this when `NSColor.fromPasteboardGraceful(.general) == nil`.
				}
				CommandGroup(replacing: .help) {
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
