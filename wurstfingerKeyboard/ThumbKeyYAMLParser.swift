//
//  ThumbKeyYAMLParser.swift
//  Wurstfinger
//
//  Parses thumb-key (Android) YAML key modifications and applies them
//  as overrides to a Wurstfinger LanguageConfig.
//

import Foundation

// MARK: - Data Types

struct ThumbKeyOverride: Codable, Equatable {
    /// Center character overrides: "row_col" -> character (e.g. "0_0" -> "a")
    var centerOverrides: [String: String]

    /// Swipe character overrides: "row_col_direction" -> character (e.g. "0_0_up" -> "v")
    var specialOverrides: [String: String]

    /// Keys to remove: set of "row_col_direction" strings
    var removals: Set<String>

    var isEmpty: Bool {
        centerOverrides.isEmpty && specialOverrides.isEmpty && removals.isEmpty
    }

    var overrideCount: Int {
        centerOverrides.count + specialOverrides.count + removals.count
    }

    static func load(from defaults: UserDefaults) -> ThumbKeyOverride? {
        guard let data = defaults.data(forKey: SettingsKey.keyModificationsParsed.rawValue) else {
            return nil
        }
        return try? JSONDecoder().decode(ThumbKeyOverride.self, from: data)
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: SettingsKey.keyModificationsParsed.rawValue)
        }
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: SettingsKey.keyModificationsYAML.rawValue)
        defaults.removeObject(forKey: SettingsKey.keyModificationsParsed.rawValue)
    }
}

enum ThumbKeyParseError: Error, LocalizedError {
    case emptyInput
    case noMainBlock
    case malformedYAML(line: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Input is empty."
        case .noMainBlock:
            "No 'main:' block found."
        case let .malformedYAML(line, detail):
            "Line \(line): \(detail)"
        }
    }
}

// MARK: - Parser

enum ThumbKeyYAMLParser {
    /// Thumb-key direction name -> Wurstfinger direction name
    private static let directionMap: [String: String] = [
        "top": "up",
        "bottom": "down",
        "left": "left",
        "right": "right",
        "topLeft": "upLeft",
        "topRight": "upRight",
        "bottomLeft": "downLeft",
        "bottomRight": "downRight",
    ]

    private static let allDirections: Set<String> = [
        "center", "top", "bottom", "left", "right",
        "topLeft", "topRight", "bottomLeft", "bottomRight",
    ]

    /// Parse thumb-key YAML and extract character overrides for the 3x3 grid.
    static func parse(_ yaml: String) -> Result<ThumbKeyOverride, ThumbKeyParseError> {
        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }

        let dict: [String: Any]
        do {
            dict = try parseYAMLToDict(trimmed)
        } catch let error as ThumbKeyParseError {
            return .failure(error)
        } catch {
            return .failure(.malformedYAML(line: 0, detail: error.localizedDescription))
        }

        // Find "main" block: either top-level or nested under a layout name
        var mainBlock: [String: Any]?
        if let main = dict["main"] as? [String: Any] {
            mainBlock = main
        } else {
            for (_, value) in dict {
                if let layoutDict = value as? [String: Any],
                   let main = layoutDict["main"] as? [String: Any]
                {
                    mainBlock = main
                    break
                }
            }
        }

        guard let mainBlock else {
            return .failure(.noMainBlock)
        }

        var override = ThumbKeyOverride(centerOverrides: [:], specialOverrides: [:], removals: [])

        for (keyName, keyValue) in mainBlock {
            guard let (row, col) = parseKeyPosition(keyName) else { continue }
            guard row <= 2, col <= 2 else { continue }
            guard let keyDict = keyValue as? [String: Any] else { continue }

            for (direction, dirValue) in keyDict {
                guard allDirections.contains(direction) else { continue }
                guard let dirDict = dirValue as? [String: Any] else { continue }

                if let remove = dirDict["remove"] as? String, remove == "true" {
                    let wfDir = direction == "center" ? "center" : (directionMap[direction] ?? direction)
                    override.removals.insert("\(row)_\(col)_\(wfDir)")
                    continue
                }

                if let text = dirDict["text"] as? String, !text.isEmpty {
                    if direction == "center" {
                        override.centerOverrides["\(row)_\(col)"] = text
                    } else if let mapped = directionMap[direction] {
                        override.specialOverrides["\(row)_\(col)_\(mapped)"] = text
                    }
                }
            }
        }

        return .success(override)
    }


    // MARK: - Key Position Parsing

    private static func parseKeyPosition(_ name: String) -> (row: Int, col: Int)? {
        guard name.hasPrefix("key"), let underscore = name.firstIndex(of: "_") else {
            return nil
        }
        let rowStr = name[name.index(name.startIndex, offsetBy: 3) ..< underscore]
        let colStr = name[name.index(after: underscore)...]
        guard let row = Int(rowStr), let col = Int(colStr) else { return nil }
        return (row, col)
    }

    // MARK: - Simple YAML Subset Parser

    private struct Entry {
        let indent: Int
        let key: String
        let value: String? // nil = dict parent
    }

    /// Parse a constrained YAML subset (nested mappings with string leaves) into a dictionary.
    private static func parseYAMLToDict(_ yaml: String) throws(ThumbKeyParseError) -> [String: Any] {
        let lines = yaml.components(separatedBy: .newlines)
        var entries: [Entry] = []

        for (lineIndex, rawLine) in lines.enumerated() {
            let line = stripComment(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            guard let colonIdx = findUnquoted(":", in: trimmed) else {
                throw .malformedYAML(line: lineIndex + 1, detail: "Expected 'key: value' format")
            }

            let key = String(trimmed[trimmed.startIndex ..< colonIdx]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            if afterColon.isEmpty {
                entries.append(Entry(indent: indent, key: key, value: nil))
            } else if afterColon.hasPrefix("{") {
                // Inline dict: expand into child entries
                entries.append(Entry(indent: indent, key: key, value: nil))
                for (childKey, childValue) in parseInlineDict(afterColon) {
                    entries.append(Entry(indent: indent + 2, key: childKey, value: childValue))
                }
            } else {
                entries.append(Entry(indent: indent, key: key, value: unquote(afterColon)))
            }
        }

        return buildDict(from: entries, index: 0, parentIndent: -1).dict
    }

    private static func buildDict(
        from entries: [Entry], index start: Int, parentIndent: Int
    ) -> (dict: [String: Any], nextIndex: Int) {
        var dict: [String: Any] = [:]
        var i = start

        while i < entries.count {
            let entry = entries[i]
            guard entry.indent > parentIndent else { break }

            if let value = entry.value {
                dict[entry.key] = value
                i += 1
            } else {
                let child = buildDict(from: entries, index: i + 1, parentIndent: entry.indent)
                dict[entry.key] = child.dict
                i = child.nextIndex
            }
        }

        return (dict, i)
    }

    // MARK: - String Helpers

    private static func findUnquoted(_ target: Character, in str: String) -> String.Index? {
        var inQuote: Character?
        for (i, ch) in zip(str.indices, str) {
            if let q = inQuote {
                if ch == q { inQuote = nil }
            } else if ch == "'" || ch == "\"" {
                inQuote = ch
            } else if ch == target {
                return i
            }
        }
        return nil
    }

    private static func stripComment(_ line: String) -> String {
        findUnquoted("#", in: line).map { String(line[line.startIndex ..< $0]) } ?? line
    }

    private static func parseInlineDict(_ str: String) -> [(key: String, value: String)] {
        let content = str.drop(while: { $0 != "{" }).dropFirst()
        guard let closing = content.lastIndex(of: "}") else { return [] }
        let inner = String(content[content.startIndex ..< closing]).trimmingCharacters(in: .whitespaces)
        guard !inner.isEmpty else { return [] }

        return inner.components(separatedBy: ",").compactMap { pair in
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = unquote(parts[1].trimmingCharacters(in: .whitespaces))
            return key.isEmpty ? nil : (key, value)
        }
    }

    private static func unquote(_ str: String) -> String {
        if (str.hasPrefix("\"") && str.hasSuffix("\"")) ||
            (str.hasPrefix("'") && str.hasSuffix("'"))
        {
            return String(str.dropFirst().dropLast())
        }
        return str
    }
}
