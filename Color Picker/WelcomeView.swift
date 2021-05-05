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
				""",
			buttonTitles: [
				"Get Started"
			]
		)
	}
}
