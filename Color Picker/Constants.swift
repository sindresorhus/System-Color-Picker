import Foundation
import Defaults
import KeyboardShortcuts

extension Defaults.Keys {
	static let showInMenuBar = Key<Bool>("showInMenuBar", default: false)
	static let showColorSamplerOnOpen = Key<Bool>("showColorSamplerOnOpen", default: false)
	static let stayOnTop = Key<Bool>("stayOnTop", default: true)
	static let uppercaseHexColor = Key<Bool>("uppercaseHexColor", default: false)
	static let legacyColorSyntax = Key<Bool>("legacyColorSyntax", default: false)
}

extension KeyboardShortcuts.Name {
	static let toggleWindow = Self("toggleWindow")
}
