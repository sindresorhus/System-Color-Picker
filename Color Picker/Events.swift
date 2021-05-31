import SwiftUI
import Defaults
import KeyboardShortcuts

extension AppState {
	func setUpEvents() {
		Defaults.publisher(.showInMenuBar)
			.receive(on: DispatchQueue.main)
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
			.store(in: &cancellables)

		Defaults.publisher(.stayOnTop)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] in
				self?.colorPanel.level = $0.newValue ? .floating : .normal
			}
			.store(in: &cancellables)

		KeyboardShortcuts.onKeyUp(for: .pickColor) { [weak self] in
			self?.pickColor()
		}

		KeyboardShortcuts.onKeyUp(for: .toggleWindow) { [weak self] in
			self?.colorPanel.toggle()
		}

		// Workaround for the color picker window not becoming active after the settings window closes. (macOS 11.3)
		NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
			.sink { [self] _ in
				DispatchQueue.main.async {
					if colorPanel.isVisible, SSApp.settingsWindow?.isVisible != true {
						colorPanel.makeKeyAndOrderFront(nil)
					}
				}
			}
			.store(in: &cancellables)
	}
}
