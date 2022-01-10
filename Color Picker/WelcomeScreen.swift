import Cocoa

extension AppState {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)

		NSAlert.showModal(
			title: "Welcome to Color Picker!",
			message:
				"""
				If you have any feedback, bug reports, or feature requests, use the feedback button in the “Help” menu. I quickly respond to all submissions.

				There's often not enough info in an app review to fix a bug and I cannot easily ask for more info there.
				""",
			buttonTitles: [
				"Get Started"
			],
			defaultButtonIndex: -1
		)
	}
}
