import SwiftUI
import Defaults
import KeyboardShortcuts
import LaunchAtLogin

extension AppState {
	func setUpEvents() {
		Defaults.publisher(.showInMenuBar)
			.receive(on: DispatchQueue.main)
			.sink { [self] in
				// We only set the state if it's in Dock mode or menu bar mode showing the icon.
				if !$0.newValue || ($0.newValue && !Defaults[.hideMenuBarIcon]) {
					self.statusItem.isVisible = $0.newValue
				}

				SSApp.isDockIconVisible = !$0.newValue
				NSApp.activate(ignoringOtherApps: true)

				if !$0.newValue {
					LaunchAtLogin.isEnabled = false
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

		// We use this instead of `applicationShouldHandleReopen` because of the macOS bug.
		// https://github.com/feedback-assistant/reports/issues/246
		NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
			.sink { [self] _ in
				handleAppReopen()
			}
			.store(in: &cancellables)

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
