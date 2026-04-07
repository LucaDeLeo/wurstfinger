//
//  ThumbKeyYAMLParserTests.swift
//  wurstfingerTests
//

import Foundation
import Testing

@testable import WurstfingerApp

struct ThumbKeyYAMLParserTests {
    // MARK: - Valid YAML

    @Test func parsesMinimalCenterOverride() throws {
        let yaml = """
            ENThumbKey:
              main:
                key0_0:
                  center:
                    text: x
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides == ["0_0": "x"])
        #expect(result.specialOverrides.isEmpty)
    }

    @Test func parsesSwipeDirectionOverrides() throws {
        let yaml = """
            ENThumbKey:
              main:
                key1_1:
                  top:
                    text: a
                  bottomLeft:
                    text: b
                  right:
                    text: c
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.specialOverrides["1_1_up"] == "a")
        #expect(result.specialOverrides["1_1_downLeft"] == "b")
        #expect(result.specialOverrides["1_1_right"] == "c")
    }

    @Test func parsesInlineDictFormat() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center: { text: n }
                  top: { text: v }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["0_0"] == "n")
        #expect(result.specialOverrides["0_0_up"] == "v")
    }

    @Test func parsesMixedInlineAndMultiline() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center: { text: a }
                  top:
                    text: b
                key2_2:
                  bottomRight: { text: z }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["0_0"] == "a")
        #expect(result.specialOverrides["0_0_up"] == "b")
        #expect(result.specialOverrides["2_2_downRight"] == "z")
    }

    @Test func parsesUnicodeCharacters() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center: { text: ä }
                  top: { text: ö }
                  right: { text: ü }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["0_0"] == "ä")
        #expect(result.specialOverrides["0_0_up"] == "ö")
        #expect(result.specialOverrides["0_0_right"] == "ü")
    }

    @Test func parsesMultipleKeys() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center: { text: a }
                key0_1:
                  center: { text: b }
                key0_2:
                  center: { text: c }
                key1_0:
                  center: { text: d }
                key2_2:
                  center: { text: e }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides.count == 5)
        #expect(result.centerOverrides["0_0"] == "a")
        #expect(result.centerOverrides["2_2"] == "e")
    }

    @Test func parsesAllEightDirections() throws {
        let yaml = """
            Layout:
              main:
                key1_1:
                  topLeft: { text: q }
                  top: { text: u }
                  topRight: { text: p }
                  left: { text: c }
                  center: { text: o }
                  right: { text: b }
                  bottomLeft: { text: g }
                  bottom: { text: d }
                  bottomRight: { text: j }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["1_1"] == "o")
        #expect(result.specialOverrides["1_1_upLeft"] == "q")
        #expect(result.specialOverrides["1_1_up"] == "u")
        #expect(result.specialOverrides["1_1_upRight"] == "p")
        #expect(result.specialOverrides["1_1_left"] == "c")
        #expect(result.specialOverrides["1_1_right"] == "b")
        #expect(result.specialOverrides["1_1_downLeft"] == "g")
        #expect(result.specialOverrides["1_1_down"] == "d")
        #expect(result.specialOverrides["1_1_downRight"] == "j")
    }

    @Test func handlesRemoveTrue() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  top:
                    remove: true
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.removals.contains("0_0_up"))
    }

    @Test func ignoresShiftedBlock() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center: { text: a }
              shifted:
                key0_0:
                  center: { text: A }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides == ["0_0": "a"])
        #expect(result.overrideCount == 1)
    }

    @Test func ignoresKeyPositionsOutsideGrid() throws {
        let yaml = """
            Layout:
              main:
                key3_0:
                  center: { text: x }
                key0_5:
                  center: { text: y }
                key0_0:
                  center: { text: a }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides == ["0_0": "a"])
    }

    @Test func ignoresNonDirectionFields() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  swipeType: EIGHT_WAY
                  slideType: NONE
                  center: { text: a }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides == ["0_0": "a"])
        #expect(result.specialOverrides.isEmpty)
    }

    @Test func handlesDirectMainBlock() throws {
        // Some users might strip the layout name
        let yaml = """
            main:
              key0_0:
                center: { text: x }
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides == ["0_0": "x"])
    }

    @Test func handlesCommentsInYAML() throws {
        let yaml = """
            Layout: # my custom layout
              main:
                # center key
                key1_1:
                  center: { text: o } # the center
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["1_1"] == "o")
    }

    @Test func handlesQuotedValues() throws {
        let yaml = """
            Layout:
              main:
                key0_0:
                  center:
                    text: "a"
                key0_1:
                  center:
                    text: 'b'
            """
        let result = try ThumbKeyYAMLParser.parse(yaml).get()
        #expect(result.centerOverrides["0_0"] == "a")
        #expect(result.centerOverrides["0_1"] == "b")
    }

    // MARK: - Error Cases

    @Test func failsOnEmptyInput() {
        let result = ThumbKeyYAMLParser.parse("")
        guard case .failure(.emptyInput) = result else {
            Issue.record("Expected emptyInput error")
            return
        }
    }

    @Test func failsOnWhitespaceOnlyInput() {
        let result = ThumbKeyYAMLParser.parse("   \n\n  ")
        guard case .failure(.emptyInput) = result else {
            Issue.record("Expected emptyInput error")
            return
        }
    }

    @Test func failsOnNoMainBlock() {
        let yaml = """
            Layout:
              shifted:
                key0_0:
                  center: { text: a }
            """
        let result = ThumbKeyYAMLParser.parse(yaml)
        guard case .failure(.noMainBlock) = result else {
            Issue.record("Expected noMainBlock error")
            return
        }
    }

    // MARK: - Post-Processing Override Application

    @Test func postProcessAppliesCenterOverride() {
        let override = ThumbKeyOverride(
            centerOverrides: ["0_0": "x"],
            specialOverrides: [:],
            removals: []
        )
        let layout = KeyboardLayout.layout(for: .english, overrides: override)
        let rows = layout.rows(for: .lower)
        #expect(rows[0][0].center == "x")
        #expect(rows[0][1].center == "n")
    }

    @Test func postProcessReplacesHardcodedPosition() {
        // key1_0 left is hardcoded "(" — override it with "ñ"
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: ["1_0_left": "ñ"],
            removals: []
        )
        let layout = KeyboardLayout.layout(for: .english, overrides: override)
        let key = layout.rows(for: .lower)[1][0]
        if case let .text(value) = key.output(for: .left) {
            #expect(value == "ñ")
        } else {
            Issue.record("Expected .text output for left swipe")
        }
    }

    @Test func postProcessGeneratesUppercaseReturnOverride() {
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: ["1_0_left": "ñ"],
            removals: []
        )
        let layout = KeyboardLayout.layout(for: .spanish, overrides: override)
        let key = layout.rows(for: .lower)[1][0]
        if case let .text(value) = key.output(for: .left, returning: true) {
            #expect(value == "Ñ")
        } else {
            Issue.record("Expected uppercase return override")
        }
    }

    @Test func postProcessFillsUnmappedPosition() {
        // key2_1 left is not mapped at all — add "í"
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: ["2_1_left": "í"],
            removals: []
        )
        let layout = KeyboardLayout.layout(for: .english, overrides: override)
        let key = layout.rows(for: .lower)[2][1]
        if case let .text(value) = key.output(for: .left) {
            #expect(value == "í")
        } else {
            Issue.record("Expected .text output for previously unmapped left swipe")
        }
    }

    @Test func postProcessRemovesDirection() {
        let override = ThumbKeyOverride(
            centerOverrides: [:],
            specialOverrides: [:],
            removals: ["0_0_right"]
        )
        let layout = KeyboardLayout.layout(for: .english, overrides: override)
        let key = layout.rows(for: .lower)[0][0]
        #expect(key.output(for: .right) == nil)
    }

    @Test func postProcessUpdatesCircularOnCenterChange() {
        let override = ThumbKeyOverride(
            centerOverrides: ["0_0": "z"],
            specialOverrides: [:],
            removals: []
        )
        let layout = KeyboardLayout.layout(for: .english, overrides: override)
        let key = layout.rows(for: .lower)[0][0]
        if case let .text(value) = key.circularOutput(for: .clockwise) {
            #expect(value == "Z")
        } else {
            Issue.record("Expected uppercase Z circular output")
        }
    }

    // MARK: - Codable Round-Trip

    @Test func overrideRoundTripsViaJSON() throws {
        let original = ThumbKeyOverride(
            centerOverrides: ["0_0": "ä", "1_1": "ö"],
            specialOverrides: ["0_0_up": "ü"],
            removals: ["2_2_down"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThumbKeyOverride.self, from: data)
        #expect(decoded == original)
    }
}
