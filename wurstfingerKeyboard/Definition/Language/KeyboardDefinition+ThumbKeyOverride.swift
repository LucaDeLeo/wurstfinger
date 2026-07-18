//
//  KeyboardDefinition+ThumbKeyOverride.swift
//  Wurstfinger
//
//  Applies a user-imported thumb-key override to the letter modes
//  (main / shifted / capsLock) of a KeyboardDefinition.
//

import Foundation

extension KeyboardDefinition {
    func applying(_ override: ThumbKeyOverride) -> KeyboardDefinition {
        guard !override.isEmpty else { return self }

        let letterModes = [ModeNames.main, ModeNames.shifted, ModeNames.capsLock]
        var newModes = modes
        for modeName in letterModes {
            guard let mode = modes[modeName] else { continue }
            let uppercase = (modeName != ModeNames.main)
            newModes[modeName] = mode.applyingThumbKeyOverride(override, locale: locale, uppercase: uppercase)
        }

        return KeyboardDefinition(
            title: title,
            id: id,
            localeIdentifier: localeIdentifier,
            modes: newModes,
            defaultMode: defaultMode,
            settings: settings
        )
    }
}

extension KeyboardMode {
    fileprivate static let thumbKeyDirectionMap: [String: GestureType] = [
        "up": .swipeUp,
        "down": .swipeDown,
        "left": .swipeLeft,
        "right": .swipeRight,
        "upLeft": .swipeUpLeft,
        "upRight": .swipeUpRight,
        "downLeft": .swipeDownLeft,
        "downRight": .swipeDownRight,
    ]

    fileprivate func applyingThumbKeyOverride(
        _ override: ThumbKeyOverride,
        locale: Locale,
        uppercase: Bool
    ) -> KeyboardMode {
        var newKeys = keys

        for row in 0 ..< 3 {
            for col in 0 ..< 3 {
                let slotId = GridSlot.allSlots[row][col]
                guard let existing = keys[slotId] else { continue }
                var bindings = existing.bindings
                let coord = "\(row)_\(col)"

                if let center = override.centerOverrides[coord] {
                    let text = uppercase ? center.keyboardUppercased(with: locale) : center
                    bindings[.tap] = KeyBinding(
                        label: text,
                        action: .commitText(text),
                        category: nil,
                        returnAction: nil,
                        accessibilityLabel: nil
                    )
                }

                for (suffix, gesture) in Self.thumbKeyDirectionMap {
                    let key = "\(coord)_\(suffix)"
                    guard let char = override.specialOverrides[key] else { continue }
                    let text = uppercase ? char.keyboardUppercased(with: locale) : char
                    let isLetter = char.unicodeScalars.contains { CharacterSet.letters.contains($0) }
                    let returnAction: KeyAction? = (isLetter && !uppercase)
                        ? .commitText(text.keyboardUppercased(with: locale))
                        : nil
                    bindings[gesture] = KeyBinding(
                        label: text,
                        action: .commitText(text),
                        category: nil,
                        returnAction: returnAction,
                        accessibilityLabel: nil
                    )
                }

                let coordPrefix = "\(coord)_"
                for removal in override.removals where removal.hasPrefix(coordPrefix) {
                    let suffix = String(removal.dropFirst(coordPrefix.count))
                    if suffix == "center" {
                        bindings.removeValue(forKey: .tap)
                    } else if let gesture = Self.thumbKeyDirectionMap[suffix] {
                        bindings.removeValue(forKey: gesture)
                    }
                }

                newKeys[slotId] = KeyConfig(
                    id: existing.id,
                    bindings: bindings,
                    swipeMode: existing.swipeMode,
                    slideType: existing.slideType,
                    style: existing.style,
                    tapCycleActions: existing.tapCycleActions
                )
            }
        }

        return KeyboardMode(
            name: name,
            keys: newKeys,
            arrangements: arrangements,
            autoTransitions: autoTransitions
        )
    }
}
