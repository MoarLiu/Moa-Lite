import Foundation

enum MoaCodexConfigEditor {
    static func removingExperimentalBearerTokens(from text: String) -> String {
        var outputLines: [String] = []
        var currentTable = ""
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let tableName = MoaTomlEditor.tableName(from: trimmed) {
                currentTable = tableName
            }
            if isManagedRemovalLine(line, currentTable: currentTable) {
                continue
            }
            outputLines.append(line)
        }
        return MoaTomlEditor.collapseBlankLines(outputLines.joined(separator: "\n"))
    }

    static func restoringOfficialMode(from text: String) -> String {
        var outputLines: [String] = []
        var currentTable = ""
        var skippingProviderTable = false

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let tableName = MoaTomlEditor.tableName(from: trimmed) {
                currentTable = tableName
                skippingProviderTable = isMoaManagedProviderTable(tableName)
                if skippingProviderTable {
                    continue
                }
            }

            if skippingProviderTable {
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    outputLines.append(line)
                }
                continue
            }

            if isManagedRemovalLine(line, currentTable: currentTable) {
                continue
            }

            outputLines.append(line)
        }

        return MoaTomlEditor.collapseBlankLines(outputLines.joined(separator: "\n"))
    }

    static func providerBlock(
        providerID: String,
        displayName: String? = nil,
        baseURL: String,
        apiKey: String,
        extraLines: [String]
    ) -> String {
        ([
            "[model_providers.\(providerID)]",
            "name = \(MoaTomlEditor.quotedString(displayName ?? providerID))",
            "base_url = \(MoaTomlEditor.quotedString(baseURL))",
            "experimental_bearer_token = \(MoaTomlEditor.quotedString(apiKey))",
            #"wire_api = "responses""#,
            "requires_openai_auth = true"
        ] + extraLines).joined(separator: "\n")
    }

    private static func isManagedRemovalLine(_ line: String, currentTable: String) -> Bool {
        if currentTable.isEmpty {
            return isOfficialModeRootRemovedLine(line)
        }
        guard isMoaManagedProviderTable(currentTable) else {
            return false
        }
        return isMoaProviderRemovedLine(line)
    }

    private static func isMoaProviderRemovedLine(_ line: String) -> Bool {
        let trimmed = MoaTomlEditor.trimInlineComment(from: line)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let equals = trimmed.firstIndex(of: "=") else {
            return false
        }

        let key = trimmed[..<equals]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return key == "experimental_bearer_token" || key == "base_url"
    }

    private static func isMoaManagedProviderTable(_ tableName: String) -> Bool {
        tableName.hasPrefix("model_providers.moa-lite-")
    }

    private static func isOfficialModeRootRemovedLine(_ line: String) -> Bool {
        let trimmed = MoaTomlEditor.trimInlineComment(from: line)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let equals = trimmed.firstIndex(of: "=") else {
            return false
        }

        let key = trimmed[..<equals]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "model",
            "model_provider",
            "experimental_bearer_token",
            "base_url"
        ].contains(key)
    }

}
