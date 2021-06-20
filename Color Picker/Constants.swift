import Foundation
import Defaults
import KeyboardShortcuts

extension Defaults.Keys {
	static let showInMenuBar = Key<Bool>("showInMenuBar", default: false)
	static let showColorSamplerOnOpen = Key<Bool>("showColorSamplerOnOpen", default: false)
	static let colorFormatToCopyAfterPicking = Key<CopyColorFormat>("colorFormatToCopyAfterPicking", default: .none)
	static let stayOnTop = Key<Bool>("stayOnTop", default: true)
	static let uppercaseHexColor = Key<Bool>("uppercaseHexColor", default: false)
	static let hashPrefixInHexColor = Key<Bool>("hashPrefixInHexColor", default: false)
	static let legacyColorSyntax = Key<Bool>("legacyColorSyntax", default: false)
	static let shownColorFormats = Key<Set<ColorFormat>>("shownColorFormats", default: [.hex, .hsl, .rgb, .lch])
}

extension KeyboardShortcuts.Name {
	static let pickColor = Self("pickColor")
	static let toggleWindow = Self("toggleWindow")
}

enum CopyColorFormat: String, CaseIterable, Defaults.Serializable {
	case none
	case hex
	case hsl
	case rgb
	case lch

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
		case .lch:
			return "LCH"
		}
	}
}

// TODO: Remove in 2022.
enum CodableCopyColorFormat: String {
	case none
	case hex
	case hsl
	case rgb
	case lch
}

extension CodableCopyColorFormat: Defaults.CodableType {
	typealias NativeForm = CopyColorFormat
}

extension CopyColorFormat: Defaults.NativeType {
	typealias CodableForm = CodableCopyColorFormat
}

enum ColorFormat: String, CaseIterable, Defaults.Serializable {
	case hex
	case hsl
	case rgb
	case lch

	var title: String {
		switch self {
		case .hex:
			return "Hex"
		case .hsl:
			return "HSL"
		case .rgb:
			return "RGB"
		case .lch:
			return "LCH"
		}
	}
}

extension ColorFormat: Identifiable {
	var id: Self { self }
}

// TODO: Remove in 2022.
enum CodableColorFormat: String {
	case hex
	case hsl
	case rgb
	case lch
}

extension CodableColorFormat: Defaults.CodableType {
	typealias NativeForm = ColorFormat
}

extension ColorFormat: Defaults.NativeType {
	typealias CodableForm = CodableColorFormat
}
