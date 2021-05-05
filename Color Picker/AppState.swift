import SwiftUI
import Combine
import Defaults
import KeyboardShortcuts
import AppCenter
import AppCenterCrashes

final class AppState: ObservableObject {
	static let shared = AppState()

	lazy var colorPanel: ColorPanel = {
		let colorPanel = ColorPanel()
		colorPanel.titleVisibility = .hidden
		colorPanel.hidesOnDeactivate = false
		colorPanel.isFloatingPanel = false
		colorPanel.isRestorable = false
		colorPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
		colorPanel.standardWindowButton(.zoomButton)?.isHidden = true
		colorPanel.tabbingMode = .disallowed
		colorPanel.collectionBehavior = [
			.moveToActiveSpace,
			.fullScreenAuxiliary
		]

		let accessoryView = NSHostingView(rootView: ColorPickerView(colorPanel: colorPanel))
		colorPanel.accessoryView = accessoryView
		accessoryView.constrainEdgesToSuperview()

		return colorPanel
	}()

	private let menu = with(NSMenu()) {
		$0.addSettingsItem()

		$0.addSeparator()

		$0.addCallbackItem("Send Feedback…") { _ in
			SSApp.openSendFeedbackPage()
		}

		$0.addSeparator()

		$0.addQuitItem()
	}

	lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
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

		DispatchQueue.main.async { [self] in
			setUpEvents()
			showWelcomeScreenIfNeeded()
		}
	}

	private func setUpEvents() {
		Defaults.publisher(.showInMenuBar)
			.sink { [weak self] in
				guard let self = self else {
					return
				}

				self.statusItem.isVisible = $0.newValue
				SSApp.isDockIconVisible = !$0.newValue
				NSApp.activate(ignoringOtherApps: true)

				if !$0.newValue {
					self.colorPanel.makeKeyAndOrderFront(nil)
				}
			}
			.storeForever()

		Defaults.publisher(.stayOnTop)
			.sink { [weak self] in
				self?.colorPanel.level = $0.newValue ? .floating : .normal
			}
			.storeForever()

		KeyboardShortcuts.onKeyUp(for: .toggleWindow) { [weak self] in
			self?.colorPanel.toggle()
		}
	}
}
