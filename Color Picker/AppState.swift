import SwiftUI
import Combine
import Defaults
import AppCenter
import AppCenterCrashes

final class AppState: ObservableObject {
	static let shared = AppState()

	var cancellables = Set<AnyCancellable>()

	private(set) lazy var colorPanel: ColorPanel = {
		let colorPanel = ColorPanel()
		colorPanel.titleVisibility = .hidden
		colorPanel.hidesOnDeactivate = false
		colorPanel.isFloatingPanel = false
		colorPanel.isRestorable = false
		colorPanel.styleMask.remove(.utilityWindow)
		colorPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
		colorPanel.standardWindowButton(.zoomButton)?.isHidden = true
		colorPanel.tabbingMode = .disallowed
		colorPanel.collectionBehavior = [
			.moveToActiveSpace,
			.fullScreenAuxiliary
		]
		colorPanel.makeMain()

		let view = ColorPickerView(colorPanel: colorPanel)
			.environmentObject(self)
		let accessoryView = NSHostingView(rootView: view)
		colorPanel.accessoryView = accessoryView
		accessoryView.constrainEdgesToSuperview()

		// This has to be after adding the accessory view to get correct size.
		colorPanel.setFrameUsingName(SSApp.name)
		colorPanel.setFrameAutosaveName(SSApp.name)

		return colorPanel
	}()

	private lazy var menu = with(NSMenu()) {
		$0.addCallbackItem("Pick Color") { [self] _ in
			pickColor()
		}

		$0.addSeparator()

		$0.addSettingsItem()

		$0.addSeparator()

		$0.addCallbackItem("Send Feedback…") { _ in
			SSApp.openSendFeedbackPage()
		}

		$0.addSeparator()

		$0.addQuitItem()
	}

	private(set) lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = false
		$0.button!.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
		$0.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])

		let item = $0

		$0.button!.onAction { [self] _ in
			let event = NSApp.currentEvent!

			if event.type == .rightMouseUp {
				item.menu = menu
				item.button!.performClick(nil)
				item.menu = nil
			} else {
				colorPanel.toggle()
			}
		}
	}

	init() {
		AppCenter.start(
			withAppSecret: "f44a0ef2-9271-4bdb-8320-dcceaa857c36",
			services: [
				Crashes.self
			]
		)

		// TODO: Remove in 2022.
		Defaults.migrate(.shownColorFormats, to: .v5)
		Defaults.migrate(.colorFormatToCopyAfterPicking, to: .v5)

		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		// Make the invisible native SwitUI window not block access to the desktop. (macOS 11.3)
		NSApp.windows.first?.ignoresMouseEvents = true

		// We hide the “View” menu as there's a macOS bug where it sometimes enables even though it doesn't work and then causes a crash when clicked.
		NSApp.mainMenu?.item(withTitle: "View")?.isHidden = true

		setUpEvents()
		showWelcomeScreenIfNeeded()
		requestReview()

		#if DEBUG
//		SSApp.showSettingsWindow()
		#endif
	}

	private func copyColorIfNeeded() {
		switch Defaults[.colorFormatToCopyAfterPicking] {
		case .none:
			break
		case .hex:
			colorPanel.hexColorString.copyToPasteboard()
		case .hsl:
			colorPanel.hslColorString.copyToPasteboard()
		case .rgb:
			colorPanel.rgbColorString.copyToPasteboard()
		case .lch:
			colorPanel.lchColorString.copyToPasteboard()
		}
	}

	private func requestReview() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([10, 200, 1000])
	}

	func pickColor() {
		NSColorSampler().show { [weak self] in
			guard
				let self = self,
				let color = $0
			else {
				return
			}

			self.colorPanel.color = color
			self.copyColorIfNeeded()
			self.requestReview()
		}
	}

	func pasteColor() {
		guard let color = NSColor.fromPasteboardGraceful(.general) else {
			return
		}

		colorPanel.color = color.usingColorSpace(.sRGB) ?? color
	}
}
