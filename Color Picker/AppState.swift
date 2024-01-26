import SwiftUI

@MainActor
final class AppState {
	static let shared = AppState()

	var cancellables = Set<AnyCancellable>()

	private(set) lazy var colorPanel: ColorPanel = {
		let colorPanel = ColorPanel()
		colorPanel.titleVisibility = .hidden
		colorPanel.hidesOnDeactivate = false
		colorPanel.becomesKeyOnlyIfNeeded = false
		colorPanel.isFloatingPanel = false
		colorPanel.isRestorable = false
		colorPanel.styleMask.remove(.utilityWindow)
		colorPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
		colorPanel.standardWindowButton(.zoomButton)?.isHidden = true
		colorPanel.tabbingMode = .disallowed

		var collectionBehavior: NSWindow.CollectionBehavior = [
			.fullScreenAuxiliary
			// We cannot enable tiling as then it doesn't show up in fullscreen spaces. (macOS 12.5)
//			.fullScreenAllowsTiling
		]

		if Defaults[.showOnAllSpaces] {
			// If we remove this, the window cannot be dragged if it's moved into a fullscreen space. (macOS 14.3)
			collectionBehavior.insert(.canJoinAllSpaces)
		}

		colorPanel.collectionBehavior = collectionBehavior

		colorPanel.center()
		colorPanel.makeMain()

		let view = MainScreen(colorPanel: colorPanel)
//			.environment(self)
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
			menu.addHeader("Recently Picked")

			for color in colors {
				let colorString = color.toResolvedColor.ss_stringRepresentation
				let menuItem = menu.addCallbackItem(colorString) {
					colorString.copyToPasteboard()
				}

				menuItem.image = color.toColor.swatchImage(size: 20)
			}
		}

		addPalettes(menu)

		menu.addSeparator()

		menu.addSettingsItem()

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

	private init() {
		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		setUpEvents()
		handleMenuBarIcon()
		showWelcomeScreenIfNeeded()
		requestReview()

		if Defaults[.showInMenuBar] {
			SSApp.isDockIconVisible = false
			colorPanel.close()
		} else {
			colorPanel.makeKeyAndOrderFront(nil)
		}

		#if DEBUG
//		SSApp.showSettingsWindow()
		#endif
	}

	private func requestReview() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([6, 100, 200, 1000])
	}

	private func addToRecentlyPickedColor(_ color: Color.Resolved) {
		let xColor = color.toXColor

		Defaults[.recentlyPickedColors] = Defaults[.recentlyPickedColors]
			.removingAll(xColor)
			.appending(xColor)
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
			guard let color = await NSColorSampler().sample()?.toResolvedColor else {
				return
			}

			colorPanel.resolvedColor = color
			addToRecentlyPickedColor(color)
			requestReview()

			if Defaults[.copyColorAfterPicking] {
				color.ss_stringRepresentation.copyToPasteboard()
			}

			if NSEvent.modifiers == .shift {
				pickColor()
			}

			if
				Defaults[.quitAfterPicking],
				Defaults[.copyColorAfterPicking],
				!Defaults[.showInMenuBar]
			{
				SSApp.quit()
			}
		}
	}

	func pasteColor() {
		guard let color = Color.Resolved.fromPasteboardGraceful(.general) else {
			return
		}

		colorPanel.resolvedColor = color
	}

	func handleAppReopen() {
		handleMenuBarIcon()
	}

	private func addPalettes(_ menu: NSMenu) {
		func createColorListMenu(menu: NSMenu, colorList: NSColorList) {
			for (key, color) in colorList.keysAndColors {
				let menuItem = menu.addCallbackItem(key) {
					color.ss_stringRepresentation.copyToPasteboard()
				}

				// TODO: Cache the swatch image.
				menuItem.image = color.toColor.swatchImage(size: Constants.swatchImageSize)
			}
		}

		if
			let colorListName = Defaults[.stickyPaletteName],
			let colorList = NSColorList(named: colorListName)
		{
			menu.addHeader(colorList.name ?? "<Unnamed>")
			createColorListMenu(menu: menu, colorList: colorList)
		}

		guard let colorLists = NSColorList.all.withoutStickyPalette().nilIfEmpty else {
			return
		}

		menu.addHeader("Palettes")

		for colorList in colorLists {
			guard let colorListName = colorList.name else {
				continue
			}

			menu.addItem(colorListName)
				.withSubmenuLazy {
					let menu = SSMenu()
					createColorListMenu(menu: menu, colorList: colorList)
					return menu
				}
		}
	}
}
