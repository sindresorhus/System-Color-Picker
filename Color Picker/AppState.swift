import SwiftUI
import Combine
import Defaults
import Sentry

@MainActor
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

		let view = ColorPickerScreen(colorPanel: colorPanel)
			.environmentObject(self)
		let accessoryView = NSHostingView(rootView: view)
		colorPanel.accessoryView = accessoryView
		accessoryView.constrainEdgesToSuperview()

		// This has to be after adding the accessory view to get correct size.
		colorPanel.setFrameUsingName(SSApp.name)
		colorPanel.setFrameAutosaveName(SSApp.name)

		colorPanel.orderOut(nil)

		return colorPanel
	}()

	private func createMenu() -> NSMenu {
		let menu = NSMenu()

		if Defaults[.menuBarItemClickAction] != .showColorSampler {
			menu.addCallbackItem("Pick Color") { [self] in
				pickColor()
			}
				.setShortcut(for: .pickColor)
		}

		if Defaults[.menuBarItemClickAction] != .toggleWindow {
			menu.addCallbackItem("Toggle Window") { [self] in
				colorPanel.toggle()
			}
				.setShortcut(for: .toggleWindow)
		}

		menu.addSeparator()

		if let colors = Defaults[.recentlyPickedColors].reversed().nilIfEmpty {
			menu.addHeader("Recently Picked Colors")

			for color in colors {
				let menuItem = menu.addCallbackItem(color.stringRepresentation) {
					color.stringRepresentation.copyToPasteboard()
				}

				menuItem.image = color.swatchImage
			}
		}

		menu.addSeparator()

		menu.addSettingsItem()

		menu.addSeparator()

		menu.addCallbackItem("Send Feedback…") {
			SSApp.openSendFeedbackPage()
		}

		menu.addSeparator()

		menu.addQuitItem()

		return menu
	}

	private(set) lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = false
		$0.button!.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
		$0.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])

		// Work around macOS bug where the position is not preserved. (macOS 12.1)
		$0.autosaveName = "Color Picker"

		let item = $0

		$0.button!.onAction = { [self] event in
			let isAlternative = event.isAlternativeClickForStatusItem

			let showMenu = { [self] in
				item.showMenu(createMenu())
			}

			switch Defaults[.menuBarItemClickAction] {
			case .showMenu:
				if isAlternative {
					pickColor()
				} else {
					showMenu()
				}
			case .showColorSampler:
				if isAlternative {
					showMenu()
				} else {
					pickColor()
				}
			case .toggleWindow:
				if isAlternative {
					showMenu()
				} else {
					colorPanel.toggle()
				}
			}
		}
	}

	init() {
		setUpConfig()

		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		fixStuff()
		setUpEvents()
		handleMenuBarIcon()
		showWelcomeScreenIfNeeded()
		requestReview()

		if Defaults[.showInMenuBar] {
			colorPanel.close()
		}

		#if DEBUG
//		SSApp.showSettingsWindow()
		#endif
	}

	private func setUpConfig() {
		#if !DEBUG
		SentrySDK.start {
			$0.dsn = "https://e89cb93d693444ee8829f521ab75025a@o844094.ingest.sentry.io/6139060"
			$0.enableSwizzling = false
		}
		#endif
	}

	private func fixStuff() {
		// Make the invisible native SwitUI window not block access to the desktop. (macOS 12.0)
		// https://github.com/feedback-assistant/reports/issues/253
		SSApp.swiftUIMainWindow?.ignoresMouseEvents = true

		// Make the invisible native SwiftUI window not show up in mission control when in menu bar mode. (macOS 11.6)
		SSApp.swiftUIMainWindow?.collectionBehavior = .stationary
	}

	private func requestReview() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([10, 100, 200, 1000])
	}

	private func addToRecentlyPickedColor(_ color: NSColor) {
		Defaults[.recentlyPickedColors] = Defaults[.recentlyPickedColors]
			.removingAll(color)
			.appending(color)
			.truncatingFromStart(toCount: 6)
	}

	private func handleMenuBarIcon() {
		guard Defaults[.showInMenuBar] else {
			return
		}

		statusItem.isVisible = true

		delay(seconds: 5) { [self] in
			guard Defaults[.hideMenuBarIcon] else {
				return
			}

			statusItem.isVisible = false
		}
	}

	func pickColor() {
		Task {
			guard let color = await NSColorSampler().sample() else {
				return
			}

			colorPanel.color = color
			addToRecentlyPickedColor(color)
			requestReview()

			if Defaults[.copyColorAfterPicking] {
				color.stringRepresentation.copyToPasteboard()
			}
		}
	}

	func pasteColor() {
		guard let color = NSColor.fromPasteboardGraceful(.general) else {
			return
		}

		colorPanel.color = color.usingColorSpace(.sRGB) ?? color
	}

	func handleAppReopen() {
		handleMenuBarIcon()
	}
}
