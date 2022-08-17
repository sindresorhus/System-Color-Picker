//
//  ColorChecker.swift
//  Color Picker
//
//  Created by William Mead on 16/08/2022.
//

import Foundation

/// Color checker
final class ColorChecker: ObservableObject, Identifiable {
    // MARK: - Properties
    internal let id: UUID
    @Published var hexColorValid: Bool
    @Published var hexColor: String
    // MARK: - Init & deinit
    init() {
        print("ColorChecker init ...")
        self.id = UUID()
        self.hexColor = "ffffff"
        self.hexColorValid = true
    }
    deinit {
        print("... deinit ColorChecker")
    }
    // MARK: - Methods
    func checkHexColorTextInput() {
        if hexColor.contains(where: { _ in
            hexColor.rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefABCDEF0123456789").inverted) != nil
        }) {
            hexColorValid = false
            hexColor = hexColor.trimmingCharacters(in: CharacterSet(charactersIn: "abcdeABCDE0123456789").inverted)
        }
        if hexColor.count > 6 {
            hexColorValid = false
            hexColor = String(hexColor.prefix(6))
        }
        if hexColor.count < 6 {
            hexColorValid = false
        }
        if hexColor.count == 6 {
            hexColorValid = true
        }
    }
}
