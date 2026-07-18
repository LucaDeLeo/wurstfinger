//
//  EmojiSettingsView.swift
//  wurstfinger
//
//  Lets the user pick the 12 emojis shown on the keyboard's emoji layer.
//

import SwiftUI

struct EmojiSettingsView: View {
    /// Working copy of the 12 slots, saved back to shared defaults on change.
    @State private var emojis: [String]
    @FocusState private var focusedSlot: Int?

    init() {
        let stored = SharedDefaults.store.stringArray(forKey: SettingsKey.customEmojis.rawValue)
        _emojis = State(initialValue: EmojiSettingsView.validated(stored))
    }

    private static var defaultFlat: [String] {
        EmojiLayouts.defaultEmojis.flatMap { $0 }
    }

    private static func validated(_ stored: [String]?) -> [String] {
        guard let stored, stored.count == EmojiLayouts.slotCount else { return defaultFlat }
        return stored
    }

    private var isDefault: Bool {
        emojis == Self.defaultFlat
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(0 ..< EmojiLayouts.slotCount, id: \.self) { index in
                        EmojiSlotField(
                            emoji: binding(for: index),
                            isFocused: $focusedSlot, index: index
                        )
                    }
                }
                .padding(.vertical, 8)
            } footer: {
                Text("Tap a slot and pick an emoji. The keyboard shows these twelve on its emoji layer, in this order.")
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    emojis = Self.defaultFlat
                    save()
                }
                .disabled(isDefault)
            }
        }
        .navigationTitle("Emoji Keys")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { emojis[index] },
            set: { newValue in
                let cleaned = Self.lastEmoji(in: newValue) ?? emojis[index]
                emojis[index] = cleaned
                save()
            }
        )
    }

    private func save() {
        if isDefault {
            SharedDefaults.store.removeObject(forKey: SettingsKey.customEmojis.rawValue)
        } else {
            SharedDefaults.store.set(emojis, forKey: SettingsKey.customEmojis.rawValue)
        }
    }

    /// Extracts the most recently typed emoji from raw text-field input,
    /// ignoring non-emoji characters so stray keyboard input can't put a
    /// letter on an emoji key.
    static func lastEmoji(in text: String) -> String? {
        text.reversed().first { character in
            let scalars = character.unicodeScalars
            guard let first = scalars.first else { return false }
            return first.properties.isEmojiPresentation
                || scalars.count > 1 && first.properties.isEmoji
        }
        .map(String.init)
    }
}

/// One editable emoji slot: renders the current emoji large, edits through a
/// hidden text field so the system emoji keyboard can be used directly.
private struct EmojiSlotField: View {
    @Binding var emoji: String
    var isFocused: FocusState<Int?>.Binding
    let index: Int

    @State private var rawInput = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isFocused.wrappedValue == index ? Color.accentColor : Color(.separator),
                            lineWidth: isFocused.wrappedValue == index ? 2 : 1
                        )
                )
            Text(emoji)
                .font(.system(size: 32))
            TextField("", text: $rawInput)
                .focused(isFocused, equals: index)
                .opacity(0.02)
                .onChange(of: rawInput) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    emoji = newValue
                    rawInput = ""
                }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = index }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Emoji slot \(index + 1): \(emoji)"))
    }
}

#Preview {
    NavigationStack {
        EmojiSettingsView()
    }
}
