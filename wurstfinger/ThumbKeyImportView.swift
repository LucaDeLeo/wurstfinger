//
//  ThumbKeyImportView.swift
//  wurstfinger
//
//  Import a thumb-key (Android) YAML layout to customize the keyboard.
//

import SwiftUI

struct ThumbKeyImportView: View {
    @State private var yamlText: String = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var hasOverride = false

    private let defaults = SharedDefaults.store

    var body: some View {
        Form {
            Section {
                TextEditor(text: $yamlText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 200)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Thumb-Key YAML")
            } footer: {
                Text("Paste your thumb-key 'Modify Keys' YAML here. Only the 'main' block is used.")
            }

            Section {
                Button("Apply") {
                    applyYAML()
                }
                .disabled(yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasOverride {
                    Button("Clear Custom Layout", role: .destructive) {
                        clearOverride()
                    }
                }
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: isError ? "xmark.circle" : "checkmark.circle")
                        .foregroundColor(isError ? .red : .green)
                }
            }
        }
        .navigationTitle("Import Layout")
        .onAppear {
            yamlText = defaults.string(forKey: SettingsKey.keyModificationsYAML.rawValue) ?? ""
            updateStatus()
        }
    }

    private func applyYAML() {
        let result = ThumbKeyYAMLParser.parse(yamlText)
        switch result {
        case let .success(override):
            if override.isEmpty {
                statusMessage = "YAML parsed but no character overrides found for the 3x3 grid."
                isError = true
                return
            }
            defaults.set(yamlText, forKey: SettingsKey.keyModificationsYAML.rawValue)
            override.save(to: defaults)
            statusMessage = "\(override.overrideCount) character override(s) applied."
            isError = false
            hasOverride = true

        case let .failure(error):
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func clearOverride() {
        ThumbKeyOverride.clear(from: defaults)
        yamlText = ""
        statusMessage = "Custom layout cleared."
        isError = false
        hasOverride = false
    }

    private func updateStatus() {
        guard let override = ThumbKeyOverride.load(from: defaults) else {
            statusMessage = nil
            hasOverride = false
            return
        }
        statusMessage = "\(override.overrideCount) character override(s) active."
        isError = false
        hasOverride = true
    }
}
