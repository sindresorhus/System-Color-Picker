// TODO

//import AppIntents
//import SwiftUI
//
//struct GetSelectedColorIntent: AppIntent {
//	static let title: LocalizedStringResource = "Get Selected Color"
//
//	static let description = IntentDescription(
//		"""
//		Returns the currently selected color in the app.
//		""",
//		resultValueName: "Selected Color"
//	)
//
//	@Parameter(title: "Wait for Quit")
//	var waitForQuit: Bool
//
//	static var parameterSummary: some ParameterSummary {
//		Summary("Get selected color") {
//			\Self.$waitForQuit
//		}
//	}
//
//	@MainActor
//	func perform() async throws -> some IntentResult & ReturnsValue<Color_AppEntity> {
//		if waitForQuit {
//			await withCheckedContinuation { continuation in
//				NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
//					continuation.resume()
//				}
//			}
//		}
//
//		return .result(value: .init(AppState.shared.colorPanel.resolvedColor))
//	}
//}
//
//// TODO: The problem is that waitForQuit does not work because if we quit the actions will not finish... I need to prevent quit until the actions is done. Complicated. I also need to support "wait for window close"
