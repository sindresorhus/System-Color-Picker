import Foundation
import Defaults
import KeyboardShortcuts

extension Defaults.Keys {
	static let showInMenuBar = Key<Bool>("showInMenuBar", default: false)
	static let showColorSamplerOnOpen = Key<Bool>("showColorSamplerOnOpen", default: false)
	static let colorFormatToCopyAfterPicking = Key<CopyColorFormat>("colorFormatToCopyAfterPicking", default: .none)
	static let stayOnTop = Key<Bool>("stayOnTop", default: true)
	static let uppercaseHexColor = Key<Bool>("uppercaseHexColor", default: false)
	static let legacyColorSyntax = Key<Bool>("legacyColorSyntax", default: false)
}

extension KeyboardShortcuts.Name {
	static let toggleWindow = Self("toggleWindow")
}

enum CopyColorFormat: String, Codable, CaseIterable {
	case none
	case hex
	case hsl
	case rgb

	var title: String {
		switch self {
		case .none:
			return "None"
		case .hex:
			return "Hex"
		case .hsl:
			return "HSL"
		case .rgb:
			return "RGB"
		}
	}
}
