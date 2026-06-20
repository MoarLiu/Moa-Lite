import Foundation

extension ConfigProfileController {
    func loadDatabase() throws -> ProfileDatabase {
        try stateLock.withLock {
            try ensureStoreIfMissingOnly()
            let modified = (try? fileManager.attributesOfItem(atPath: databaseURL.path))?[.modificationDate] as? Date
            if let cachedDatabase, let cachedDatabaseModified, let modified,
               cachedDatabaseModified == modified {
                return cachedDatabase
            }
            let data = try Data(contentsOf: databaseURL)
            let database = try JSONDecoder().decode(ProfileDatabase.self, from: data)
            cachedDatabase = database
            cachedDatabaseModified = modified
            return database
        }
    }

    func saveDatabase(_ database: ProfileDatabase) throws {
        try stateLock.withLock {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(database)
            try data.write(to: databaseURL, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
            cachedDatabase = database
            cachedDatabaseModified = (try? fileManager.attributesOfItem(atPath: databaseURL.path))?[.modificationDate] as? Date
        }
    }

    func loadOfficialAccountDatabase() throws -> CodexOfficialAccountDatabase {
        try stateLock.withLock {
            try ensureStoreIfMissingOnly()
            let modified = (try? fileManager.attributesOfItem(atPath: officialAccountsDatabaseURL.path))?[.modificationDate] as? Date
            if let cachedOfficialAccountDatabase,
               let cachedOfficialAccountDatabaseModified,
               let modified,
               cachedOfficialAccountDatabaseModified == modified {
                return cachedOfficialAccountDatabase
            }
            let data = try Data(contentsOf: officialAccountsDatabaseURL)
            let database = try JSONDecoder().decode(CodexOfficialAccountDatabase.self, from: data)
            cachedOfficialAccountDatabase = database
            cachedOfficialAccountDatabaseModified = modified
            return database
        }
    }

    func saveOfficialAccountDatabase(_ database: CodexOfficialAccountDatabase) throws {
        try stateLock.withLock {
            try fileManager.createDirectory(at: officialAccountsDatabaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(database)
            try data.write(to: officialAccountsDatabaseURL, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: officialAccountsDatabaseURL.path)
            cachedOfficialAccountDatabase = database
            cachedOfficialAccountDatabaseModified = (try? fileManager.attributesOfItem(atPath: officialAccountsDatabaseURL.path))?[.modificationDate] as? Date
        }
    }

    func ensureStoreIfMissingOnly() throws {
        if !fileManager.fileExists(atPath: databaseURL.path)
            || !fileManager.fileExists(atPath: moaConfigURL.path)
            || !fileManager.fileExists(atPath: moaAuthURL.path)
            || !fileManager.fileExists(atPath: officialAccountsDatabaseURL.path) {
            try ensureStore()
        }
    }
    func readAuthJSON(from url: URL) -> [String: Any] {
        guard
            fileManager.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        return object
    }

    func writeAuthJSON(_ auth: [String: Any], to url: URL) throws {
        let output = try authJSONString(from: auth)
        try output.write(to: url, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func authJSONString(from auth: [String: Any]) throws -> String {
        let normalized = normalizedMoaAuth(auth)
        var fields = [
            #"  "auth_mode": "chatgpt""#,
            #"  "OPENAI_API_KEY": null"#
        ]

        if let tokens = normalized["tokens"] {
            fields.append(#"  "tokens": \#(try jsonObjectText(tokens, continuationIndent: "  "))"#)
        }

        if let lastRefresh = normalized["last_refresh"] {
            fields.append(#"  "last_refresh": \#(try jsonScalarText(lastRefresh))"#)
        }

        return "{\n\(fields.joined(separator: ",\n"))\n}\n"
    }

    func jsonObjectText(_ value: Any, continuationIndent: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        let text = (String(data: data, encoding: .utf8) ?? "{}")
            .replacingOccurrences(of: " : ", with: ": ")
        let lines = text.components(separatedBy: "\n")
        guard let firstLine = lines.first else {
            return "{}"
        }

        return ([firstLine] + lines.dropFirst().map { "\(continuationIndent)\($0)" })
            .joined(separator: "\n")
    }

    func jsonScalarText(_ value: Any) throws -> String {
        guard JSONSerialization.isValidJSONObject([value]) else {
            return tomlQuoted(String(describing: value))
        }

        let data = try JSONSerialization.data(withJSONObject: [value], options: [])
        let text = String(data: data, encoding: .utf8) ?? "[null]"
        guard text.count >= 2 else {
            return "null"
        }

        return String(text.dropFirst().dropLast())
    }

    @discardableResult
    func syncMoaAuthSessionFromCodex(updateSelectedOfficialAccount: Bool = true) throws -> Bool {
        let existingMoaAuth = readAuthJSON(from: moaAuthURL)
        var moaAuth = normalizedMoaAuth(existingMoaAuth)
        var changed = !jsonValuesEqual(existingMoaAuth, moaAuth)

        guard fileManager.fileExists(atPath: codexAuthURL.path) else {
            if changed {
                try writeAuthJSON(moaAuth, to: moaAuthURL)
            }
            if updateSelectedOfficialAccount, hasOfficialAuthSession(moaAuth) {
                try syncSelectedOfficialAccountAuth(moaAuth)
            }
            return changed
        }

        let codexAuth = readAuthJSON(from: codexAuthURL)
        guard codexAuth["tokens"] != nil else {
            if changed {
                try writeAuthJSON(moaAuth, to: moaAuthURL)
            }
            if updateSelectedOfficialAccount, hasOfficialAuthSession(moaAuth) {
                try syncSelectedOfficialAccountAuth(moaAuth)
            }
            return changed
        }

        for key in ["tokens", "last_refresh"] {
            guard let codexValue = codexAuth[key] else {
                continue
            }

            if !jsonValuesEqual(moaAuth[key], codexValue) {
                moaAuth[key] = codexValue
                changed = true
            }
        }

        if changed {
            try writeAuthJSON(moaAuth, to: moaAuthURL)
        }

        if updateSelectedOfficialAccount {
            try syncSelectedOfficialAccountAuth(moaAuth)
        }

        return changed
    }

    func syncSelectedOfficialAccountAuth(_ auth: [String: Any]) throws {
        guard fileManager.fileExists(atPath: officialAccountsDatabaseURL.path),
              hasOfficialAuthSession(auth)
        else {
            return
        }

        var database = try loadOfficialAccountDatabase()
        guard let selectedID = database.selectedAccountID,
              let index = database.accounts.firstIndex(where: { $0.id == selectedID })
        else {
            return
        }

        database.accounts[index].lastUsedAt = Self.isoTimestamp()
        try writeAuthJSON(auth, to: officialAuthURL(for: database.accounts[index]))
        try saveOfficialAccountDatabase(database)
    }

    func normalizedMoaAuth(_ auth: [String: Any]) -> [String: Any] {
        var normalized = Self.defaultAuthJSON()
        if let tokens = auth["tokens"] {
            normalized["tokens"] = tokens
        }
        if let lastRefresh = auth["last_refresh"] {
            normalized["last_refresh"] = lastRefresh
        }
        return normalized
    }

    func authStringValue(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }

        return value as? String
    }

    func jsonValuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        case let (lhs?, rhs?):
            if let lhsData = normalizedJSONData(for: lhs),
               let rhsData = normalizedJSONData(for: rhs) {
                return lhsData == rhsData
            }

            return String(describing: lhs) == String(describing: rhs)
        }
    }

    func normalizedJSONData(for value: Any) -> Data? {
        let wrapped = ["value": value]
        guard JSONSerialization.isValidJSONObject(wrapped) else {
            return nil
        }

        return try? JSONSerialization.data(withJSONObject: wrapped, options: [.sortedKeys])
    }

    func writeText(_ text: String, to url: URL) throws {
        var output = text
        if !output.hasSuffix("\n") {
            output.append("\n")
        }
        try output.write(to: url, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func copyFile(from source: URL, to destination: URL) throws {
        try? fileManager.removeItem(at: destination)
        try fileManager.copyItem(at: source, to: destination)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    func isPlaceholderConfig(at url: URL) throws -> Bool {
        let text = try String(contentsOf: url, encoding: .utf8)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTrimmed = Self.defaultConfig.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == defaultTrimmed
    }

    func backupCodexFiles() throws {
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = Self.timestamp()

        for url in [codexConfigURL, codexAuthURL] where fileManager.fileExists(atPath: url.path) {
            let destination = backupDir.appendingPathComponent("\(url.lastPathComponent).\(stamp)")
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: url, to: destination)
        }
        pruneCodexBackups(keepingPerFile: 12)
    }

    func pruneCodexBackups(keepingPerFile limit: Int) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for prefix in ["config.toml.", "auth.json."] {
            let matching = files
                .filter { $0.lastPathComponent.hasPrefix(prefix) }
                .sorted { left, right in
                    let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return leftDate > rightDate
                }
            for stale in matching.dropFirst(max(0, limit)) {
                try? fileManager.removeItem(at: stale)
            }
        }
    }

    @discardableResult
    func run(_ executable: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return 127
        }
    }
    static func displayName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Current Codex" }

        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return trimmed
        }

        return trimmed
            .split { $0 == "-" || $0 == "_" }
            .map { part in
                let lower = part.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    static func defaultAuthJSON() -> [String: Any] {
        [
            "auth_mode": "chatgpt",
            "OPENAI_API_KEY": NSNull()
        ]
    }
}
