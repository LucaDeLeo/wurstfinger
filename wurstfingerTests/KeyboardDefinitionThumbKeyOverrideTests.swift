//
//  KeyboardDefinitionThumbKeyOverrideTests.swift
//  WurstfingerTests
//

import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardDefinitionThumbKeyOverrideTests {
    private func englishBase() -> KeyboardDefinition {
        guard let descriptor = LanguageDefinitions.all.first(where: { $0.id == "en_US" }) else {
            preconditionFailure("English MessagEase definition not found")
        }
        return descriptor.makeDefinition()
    }

    @Test func emptyOverrideReturnsSelf() {
        let base = englishBase()
        let override = ThumbKeyOverride(centerOverrides: [:], specialOverrides: [:], removals: [])
        #expect(base.applying(override) == base)
    }

    @Test func centerOverrideRewritesTapBindingInMain() {
        let base = englishBase()
        let override = ThumbKeyOverride(
            centerOverrides: ["0_0": "z"],
            specialOverrides: [:],
            removals: []
        )
        let result = base.applying(override)
        let main = try! #require(result.mode(ModeNames.main))
        let topLeft = try! #require(main.key(for: GridSlot.topLeft))
        let tap = try! #require(topLeft.bindings[.tap])
        #expect(tap.action == .commitText("z"))
        #expect(tap.label == "z")
    }

    @Test func centerOverrideUppercasesInShifted() {
        let base = englishBase()
        let override = ThumbKeyOverride(
            centerOverrides: ["0_0": "z"],
            specialOverrides: [:],
            removals: []
        )
        let result = base.applying(override)
        let shifted = try! #require(result.mode(ModeNames.shifted))
        let topLeft = try! #require(shifted.key(for: GridSlot.topLeft))
        let tap = try! #require(topLeft.bindings[.tap])
        #expect(tap.action == .commitText("Z"))
    }

    @Test func directionalOverrideRewritesSwipeBinding() {
        let base = englishBase()
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: ["1_1_up": "ñ"],
            removals: []
        )
        let result = base.applying(override)
        let main = try! #require(result.mode(ModeNames.main))
        let center = try! #require(main.key(for: GridSlot.center))
        let swipe = try! #require(center.bindings[.swipeUp])
        #expect(swipe.action == .commitText("ñ"))
    }

    @Test func removalDropsBinding() {
        let base = englishBase()
        guard let mainBefore = base.mode(ModeNames.main),
              let centerBefore = mainBefore.key(for: GridSlot.center),
              centerBefore.bindings[.swipeRight] != nil
        else {
            return
        }
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: [:],
            removals: ["1_1_right"]
        )
        let result = base.applying(override)
        let main = try! #require(result.mode(ModeNames.main))
        let center = try! #require(main.key(for: GridSlot.center))
        #expect(center.bindings[.swipeRight] == nil)
    }
}
