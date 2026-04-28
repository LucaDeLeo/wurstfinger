//
//  ThumbKeyOverride.swift
//  Wurstfinger
//
//  Persistent thumb-key (Android) layout override applied to a
//  KeyboardDefinition's letter modes at runtime.
//

import Foundation

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
