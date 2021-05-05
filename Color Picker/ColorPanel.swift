import Cocoa
import Defaults

final class ColorPanel: NSColorPanel, NSWindowDelegate {
	override var canBecomeMain: Bool { true }
	override var canBecomeKey: Bool { true }

	override func makeKeyAndOrderFront(_ sender: Any?) {
		super.makeKeyAndOrderFront(sender)

		if Defaults[.showColorSamplerOnOpen] {
			showColorSampler()
		}
	}

	// Ensures the app closes when the window does.
	override func close() {
		super.close()

		if !Defaults[.showInMenuBar] {
			SSApp.quit()
		}
	}
}
