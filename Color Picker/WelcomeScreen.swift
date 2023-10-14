import Cocoa

extension AppState {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		if NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor {
			Defaults[.showAccessibilityColorName] = true
		}

		SSApp.activateIfAccessory()

		NSAlert.showModal(
			title: "Welcome to Color Picker!",
			message:
				"""
				If you have any feedback, bug reports, or feature requests, use the feedback button in the “Help” menu. I quickly respond to all submissions.

				There's often not enough info in an app review to fix a bug and I cannot easily ask for more info there.

				Known issue: The color picker can in some obscure situations crash when interacting with the palette at the bottom. This crash is caused by a bug in macOS and is out of my control.
				""",
			buttonTitles: [
				"Get Started"
			],
			defaultButtonIndex: -1
		)
	}
}
