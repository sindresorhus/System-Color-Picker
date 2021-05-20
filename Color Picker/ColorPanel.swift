import Cocoa
import Defaults

final class ColorPanel: NSColorPanel, NSWindowDelegate {
	override var canBecomeMain: Bool { true }
	override var canBecomeKey: Bool { true }

	override func makeKeyAndOrderFront(_ sender: Any?) {
		hideNativePickerButton()

		super.makeKeyAndOrderFront(sender)

		if Defaults[.showColorSamplerOnOpen] {
			showColorSampler()
		}

		// Prevent the first tab from showing focus ring.
		DispatchQueue.main.async {
			DispatchQueue.main.async { [self] in
				makeFirstResponder(nil)
			}
		}
	}

	// Ensures the app closes when the window does.
	override func close() {
		super.close()

		if !Defaults[.showInMenuBar] {
			SSApp.quit()
		}
	}

	private func hideNativePickerButton() {
		let pickerButton = contentView?
			.firstSubview(deep: true) { $0.simpleClassName == "NSButtonImageView" }?
			.superview

		assert(pickerButton != nil)

		pickerButton?.isHidden = true
	}
}
