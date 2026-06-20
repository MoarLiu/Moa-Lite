import Foundation

extension ConfigProfileController {
    func officialAccounts() throws -> [CodexOfficialAccount] {
        try loadOfficialAccountDatabase().accounts
    }

    func selectedOfficialAccountID() throws -> String? {
        try loadOfficialAccountDatabase().selectedAccountID
    }

    func selectedOfficialAccountName() -> String? {
        guard
            let database = try? loadOfficialAccountDatabase(),
            let selectedID = database.selectedAccountID,
            let account = database.accounts.first(where: { $0.id == selectedID })
        else {
            return nil
        }
        return account.name
    }

    func selectedOfficialAccount() throws -> CodexOfficialAccount? {
        let database = try loadOfficialAccountDatabase()
        guard let selectedID = database.selectedAccountID else {
            return nil
        }
        return database.accounts.first(where: { $0.id == selectedID })
    }

    func currentOfficialLoginSaveStatus() throws -> (hasLogin: Bool, savedAccountName: String?) {
        let auth = preferredCurrentOfficialAuth()
        guard hasOfficialAuthSession(auth) else {
            return (false, nil)
        }
        return (true, try matchingOfficialAccount(for: auth)?.name)
    }
    @discardableResult
    func addOfficialAccountFromCurrentLogin(name: String) throws -> CodexOfficialAccount {
        try stateLock.withLock {
            try ensureStore()

            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw CodexOfficialAccountError.invalidAccountName
            }

            let auth = preferredCurrentOfficialAuth()
            guard hasOfficialAuthSession(auth) else {
                throw CodexOfficialAccountError.noCurrentLogin
            }
            if let existing = try matchingOfficialAccount(for: auth) {
                throw CodexOfficialAccountError.duplicateCurrentLogin(existing.name)
            }

            try backupCodexFiles()

            var officialDatabase = try loadOfficialAccountDatabase()
            var account = makeOfficialAccount(name: trimmedName)
            try writeAuthJSON(auth, to: officialAuthURL(for: account))
            try writeAuthJSON(auth, to: moaAuthURL)
            try copyFile(from: moaAuthURL, to: codexAuthURL)

            account.lastUsedAt = Self.isoTimestamp()
            officialDatabase.accounts.append(account)
            officialDatabase.selectedAccountID = account.id
            try saveOfficialAccountDatabase(officialDatabase)
            return account
        }
    }

    @discardableResult
    func applyOfficialAccount(id: String) throws -> CodexOfficialAccount {
        try stateLock.withLock {
            try ensureStore()

            try syncMoaAuthSessionFromCodex(updateSelectedOfficialAccount: true)

            var officialDatabase = try loadOfficialAccountDatabase()
            guard let index = officialDatabase.accounts.firstIndex(where: { $0.id == id }) else {
                throw CodexOfficialAccountError.accountNotFound
            }
            try backupCodexFiles()

            var account = officialDatabase.accounts[index]
            let authURL = officialAuthURL(for: account)
            guard fileManager.fileExists(atPath: authURL.path),
                  hasOfficialAuthSession(readAuthJSON(from: authURL))
            else {
                throw CodexOfficialAccountError.noCurrentLogin
            }

            try copyFile(from: authURL, to: moaAuthURL)
            try copyFile(from: authURL, to: codexAuthURL)

            account.lastUsedAt = Self.isoTimestamp()
            officialDatabase.accounts[index] = account
            officialDatabase.selectedAccountID = account.id
            try saveOfficialAccountDatabase(officialDatabase)
            return account
        }
    }

    @discardableResult
    func renameSelectedOfficialAccount(name: String) throws -> CodexOfficialAccount {
        try stateLock.withLock {
            try ensureStore()

            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw CodexOfficialAccountError.invalidAccountName
            }

            var database = try loadOfficialAccountDatabase()
            guard let selectedID = database.selectedAccountID else {
                throw CodexOfficialAccountError.noSelectedAccount
            }
            guard let index = database.accounts.firstIndex(where: { $0.id == selectedID }) else {
                throw CodexOfficialAccountError.accountNotFound
            }

            database.accounts[index].name = trimmedName
            let account = database.accounts[index]
            try saveOfficialAccountDatabase(database)
            return account
        }
    }

    struct DeletedOfficialAccountResult {
        var deleted: CodexOfficialAccount
        var activated: CodexOfficialAccount?
    }

    @discardableResult
    func deleteSelectedOfficialAccount() throws -> DeletedOfficialAccountResult {
        try stateLock.withLock {
            try ensureStore()

            try syncMoaAuthSessionFromCodex(updateSelectedOfficialAccount: true)

            var database = try loadOfficialAccountDatabase()
            guard let selectedID = database.selectedAccountID else {
                throw CodexOfficialAccountError.noSelectedAccount
            }
            guard let index = database.accounts.firstIndex(where: { $0.id == selectedID }) else {
                throw CodexOfficialAccountError.accountNotFound
            }

            try backupCodexFiles()

            let deleted = database.accounts.remove(at: index)
            try? fileManager.removeItem(at: officialAuthURL(for: deleted))

            let activated: CodexOfficialAccount?
            if database.accounts.isEmpty {
                database.selectedAccountID = nil
                activated = nil
            } else {
                let nextIndex = min(index, database.accounts.count - 1)
                var next = database.accounts[nextIndex]
                next.lastUsedAt = Self.isoTimestamp()
                database.accounts[nextIndex] = next
                database.selectedAccountID = next.id
                try copyFile(from: officialAuthURL(for: next), to: moaAuthURL)
                try copyFile(from: officialAuthURL(for: next), to: codexAuthURL)
                activated = next
            }

            try saveOfficialAccountDatabase(database)
            return DeletedOfficialAccountResult(deleted: deleted, activated: activated)
        }
    }
    func makeOfficialAccount(name: String) -> CodexOfficialAccount {
        let id = UUID().uuidString
        let now = Self.isoTimestamp()
        return CodexOfficialAccount(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            authPath: "\(Self.officialAuthAccountsRelativePath)/\(id).json",
            createdAt: now,
            lastUsedAt: now
        )
    }

    func officialAuthURL(for account: CodexOfficialAccount) -> URL {
        moaHome.appendingPathComponent(account.authPath)
    }

    func preferredCurrentOfficialAuth() -> [String: Any] {
        let codexAuth = readAuthJSON(from: codexAuthURL)
        if hasOfficialAuthSession(codexAuth) {
            return codexAuth
        }
        return readAuthJSON(from: moaAuthURL)
    }

    func hasOfficialAuthSession(_ auth: [String: Any]) -> Bool {
        auth["tokens"] != nil
    }

    func matchingOfficialAccount(for auth: [String: Any]) throws -> CodexOfficialAccount? {
        guard hasOfficialAuthSession(auth) else {
            return nil
        }

        let database = try loadOfficialAccountDatabase()
        let refreshToken = officialAuthRefreshToken(from: auth)
        let comparableAuth = officialAuthComparableData(from: auth)
        return database.accounts.first { account in
            let savedAuth = readAuthJSON(from: officialAuthURL(for: account))
            if let refreshToken, officialAuthRefreshToken(from: savedAuth) == refreshToken {
                return true
            }
            guard let comparableAuth,
                  let savedComparableAuth = officialAuthComparableData(from: savedAuth)
            else {
                return false
            }
            return comparableAuth == savedComparableAuth
        }
    }

    func officialAuthRefreshToken(from auth: [String: Any]) -> String? {
        guard let tokens = auth["tokens"] as? [String: Any] else {
            return nil
        }
        return authStringValue(tokens["refresh_token"])
            ?? authStringValue(tokens["refreshToken"])
    }

    func officialAuthComparableData(from auth: [String: Any]) -> Data? {
        var comparable = normalizedMoaAuth(auth)
        comparable["last_refresh"] = nil
        return normalizedJSONData(for: comparable)
    }
}
