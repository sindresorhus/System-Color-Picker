import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

extension AppState {
	func setUpEvents() {
		Defaults.publisher(.showInMenuBar)
			.receive(on: DispatchQueue.main)
			.sink { [self] in
				// We only set the state if it's in Dock mode or menu bar mode showing the icon.
				if !$0.newValue || ($0.newValue && !Defaults[.hideMenuBarIcon]) {
					statusItem.isVisible = $0.newValue
				}

				SSApp.isDockIconVisible = !$0.newValue
				SSApp.forceActivate()

				if !$0.newValue {
					LaunchAtLogin.isEnabled = false
					colorPanel.makeKeyAndOrderFront(nil)
				}
			}
			.store(in: &cancellables)

		Defaults.publisher(.stayOnTop)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] in
				// We use `.utility` instead of `.floating` to ensure it's always above other windows.
				// For example, the Simulator uses `.modalPane` level when "stay on top" is enabled.
				self?.colorPanel.level = $0.newValue ? .utility : .normal
			}
			.store(in: &cancellables)

		Defaults.publisher(.hideMenuBarIcon, options: [])
			.receive(on: DispatchQueue.main)
			.sink { [self] in
				statusItem.isVisible = !$0.newValue
			}
			.store(in: &cancellables)

		KeyboardShortcuts.onKeyUp(for: .pickColor) { [self] in
			pickColor()
		}

		KeyboardShortcuts.onKeyUp(for: .toggleWindow) { [self] in
			colorPanel.toggle()
		}

		if #unavailable(macOS 14) {
			// Workaround for the color picker window not becoming active after the settings window closes. (macOS 11.3)
			NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
				.sink { [self] _ in
					DispatchQueue.main.async { [self] in
						if colorPanel.isVisible, SSApp.settingsWindow?.isVisible != true {
							colorPanel.makeKeyAndOrderFront(nil)
						}
					}
				}
				.store(in: &cancellables)
		}
	}
}
