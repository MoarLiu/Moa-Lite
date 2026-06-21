import Foundation

private enum TestError: Error, CustomStringConvertible {
    case failure(String)

    var description: String {
        switch self {
        case .failure(let message):
            return message
        }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw TestError.failure(message)
    }
}

private func expectClose(_ actual: Double, _ expected: Double, _ message: String, tolerance: Double = 0.000001) throws {
    guard abs(actual - expected) <= tolerance else {
        throw TestError.failure("\(message): expected \(expected), got \(actual)")
    }
}

private func temporaryHome() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("moa-lite-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@main
private enum MoaLiteCoreTests {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("data root paths are Moa-Lite scoped", testDataRootPaths),
            ("provider bridge defaults use Moa-Lite port", testProviderBridgeDefaultPort),
            ("Codex bridge provider IDs use Moa-Lite prefix", testCodexBridgeProviderIDs),
            ("official restore only removes Moa-Lite provider tables", testOfficialRestoreLeavesOriginalMoaTables),
            ("LiteLLM preset no longer uses original Moa model name", testLiteLLMPresetName),
            ("ZCode GLM pricing is estimated from usage tokens", testZCodePricing),
            ("ZCode usage scanner aggregates local SQLite usage", testZCodeUsageScanner)
        ]

        var failures: [String] = []
        for (name, test) in tests {
            do {
                try test()
                print("PASS \(name)")
            } catch {
                failures.append("\(name): \(error)")
                print("FAIL \(name): \(error)")
            }
        }

        if !failures.isEmpty {
            fputs(failures.joined(separator: "\n") + "\n", stderr)
            exit(1)
        }
    }

    private static func testDataRootPaths() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let environment = ["HOME": home.path]
        try expect(MoaDataRoot.localURL(environment: environment).lastPathComponent == ".moa-lite", "local data root should be ~/.moa-lite")
        try expect(MoaDataRoot.supportDirectory(environment: environment).lastPathComponent == "Moa-Lite", "Application Support root should be Moa-Lite")
        try expect(MoaDataRoot.iCloudURL(environment: environment).lastPathComponent == "Moa-Lite", "iCloud folder should be Moa-Lite")
        try expect(MoaDataRoot.legacyNestedICloudURL(environment: environment).lastPathComponent == ".moa-lite", "legacy nested iCloud folder should be .moa-lite")
        try expect(MoaDataRoot.currentURL(environment: environment).path.hasSuffix("/.moa-lite"), "default current root should stay local")
    }

    private static func testProviderBridgeDefaultPort() throws {
        let profile = ConfigProfile(
            id: "bridge",
            name: "DeepSeek Bridge",
            baseURL: "https://api.deepseek.com",
            apiKey: "sk-test",
            providerKind: .deepseek,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge
        )

        try expect(MoaProviderBridgeDefaults.defaultPort == 19361, "Moa-Lite provider bridge should avoid Moa's original 19360 port")
        try expect(profile.resolvedBridgePort == 19361, "local bridge profiles should inherit the Moa-Lite port")
        try expect(profile.codexBaseURL == "http://127.0.0.1:19361/v1", "Codex base URL should use the Moa-Lite bridge port")
    }

    private static func testCodexBridgeProviderIDs() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let controller = ConfigProfileController(environment: [
            "HOME": home.path,
            "CODEX_HOME": home.appendingPathComponent(".codex").path
        ])
        let deepSeek = ConfigProfile(
            id: "deepseek",
            name: "DeepSeek Bridge",
            baseURL: "https://api.deepseek.com",
            apiKey: "sk-test",
            providerKind: .deepseek,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge
        )
        let custom = ConfigProfile(
            id: "custom",
            name: "Kimi Chat",
            baseURL: "https://api.moonshot.ai/v1",
            apiKey: "sk-test",
            providerKind: .custom,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge
        )

        try expect(ConfigProfileController.providerBridgeModeID == "moa-lite-provider-bridge", "provider bridge mode ID should be Moa-Lite scoped")
        try expect(controller.providerID(for: deepSeek, in: "") == "moa-lite-deepseek", "DeepSeek bridge provider ID should use Moa-Lite prefix")
        try expect(controller.providerID(for: custom, in: "") == "moa-lite-kimi_chat", "custom bridge provider ID should use Moa-Lite prefix")
    }

    private static func testOfficialRestoreLeavesOriginalMoaTables() throws {
        let config = """
        model = "deepseek-chat"
        model_provider = "moa-lite-deepseek"

        [model_providers.moa-deepseek]
        name = "Original Moa DeepSeek"
        base_url = "http://127.0.0.1:19360/v1"
        experimental_bearer_token = "original-token"
        wire_api = "responses"

        [model_providers.moa-lite-deepseek]
        name = "Moa-Lite DeepSeek"
        base_url = "http://127.0.0.1:19361/v1"
        experimental_bearer_token = "lite-token"
        wire_api = "responses"
        """

        let restored = MoaCodexConfigEditor.restoringOfficialMode(from: config)
        try expect(restored.contains("[model_providers.moa-deepseek]"), "Moa-Lite should not remove original Moa provider tables")
        try expect(restored.contains("original-token"), "original Moa provider secrets should not be touched by Moa-Lite official restore")
        try expect(!restored.contains("[model_providers.moa-lite-deepseek]"), "Moa-Lite managed provider table should be removed")
        try expect(!restored.contains("lite-token"), "Moa-Lite managed provider token should be removed")
        try expect(!restored.contains(#"model_provider = "moa-lite-deepseek""#), "official restore should remove root provider selection")
    }

    private static func testLiteLLMPresetName() throws {
        let preset = MoaProviderPresets.responsesGateways.first { $0.id == "litellm-responses-gateway" }
        try expect(preset?.model == "moa-lite-codex", "LiteLLM sample model should be Moa-Lite scoped")
        try expect(preset?.models == ["moa-lite-codex"], "LiteLLM sample models should be Moa-Lite scoped")
    }

    private static func testZCodePricing() throws {
        let estimate = MoaUsagePricing.zcodeCostEstimate(
            model: "zhipu/glm-5-turbo",
            inputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            outputTokens: 1_000_000
        )
        try expect(estimate?.normalizedModel == "GLM-5-Turbo", "ZCode model names should normalize GLM-5-Turbo")
        try expect(estimate?.pricingModel == "GLM-5-Turbo", "known ZCode models should use their own pricing model")
        try expect(estimate?.usesFallbackPricing == false, "known ZCode models should not use fallback pricing")
        try expectClose(estimate?.costUSD ?? -1, 5.44, "GLM-5-Turbo cost should use input, cached input, free cache storage, and output prices")

        let fallback = MoaUsagePricing.zcodeCostEstimate(
            model: "glm-future",
            inputTokens: 1_000_000,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 0,
            outputTokens: 0
        )
        try expect(fallback?.pricingModel == "GLM-5.2", "unknown ZCode models should fall back to GLM-5.2 pricing")
        try expect(fallback?.usesFallbackPricing == true, "unknown ZCode models should be marked as fallback pricing")
    }

    private static func testZCodeUsageScanner() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let dbDirectory = home
            .appendingPathComponent(".zcode", isDirectory: true)
            .appendingPathComponent("cli", isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        let db = dbDirectory.appendingPathComponent("db.sqlite")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startedAt = Int(now.timeIntervalSince1970 * 1000)
        try runSQLite(db: db, sql: """
        create table model_usage (
          status text,
          started_at integer,
          model_id text,
          input_tokens integer,
          output_tokens integer,
          cache_read_input_tokens integer,
          cache_creation_input_tokens integer
        );
        insert into model_usage values ('completed', \(startedAt), 'glm-5.2', 1000, 50, 200, 100);
        insert into model_usage values ('error', \(startedAt), 'glm-5.2', 9999, 9999, 9999, 9999);
        """)

        let scanner = ZCodeUsageScanner(environment: [
            "HOME": home.path,
            "ZCODE_USAGE_DB": db.path,
            "SQLITE3_PATH": "/usr/bin/sqlite3"
        ])
        let report = try scanner.loadReport(now: now, persistCache: false)
        try expect(report.rows.count == 1, "ZCode scanner should aggregate only completed rows")
        guard let row = report.rows.first else {
            throw TestError.failure("ZCode scanner should return one aggregate row")
        }

        try expect(row.source == .zcode, "ZCode scanner rows should be marked as ZCode")
        try expect(row.dayKey == MoaUsageReport.dayKey(from: now), "ZCode scanner should bucket rows by local day")
        try expect(row.model == "GLM-5.2", "ZCode scanner should normalize GLM model IDs")
        try expect(row.input == 700, "ZCode scanner should subtract cache read and storage tokens from raw input")
        try expect(row.cacheReadInput == 200, "ZCode scanner should preserve cache read tokens")
        try expect(row.cacheCreationInput == 100, "ZCode scanner should preserve cache creation/storage tokens")
        try expect(row.output == 50, "ZCode scanner should preserve output tokens")
        try expect(row.totalTokens == 1050, "ZCode scanner total tokens should include raw prompt tokens plus output")
        try expect(row.cacheHitTokens == 200, "ZCode scanner cache hit tokens should include cache read tokens")
        try expectClose(row.costUSD, 0.001252, "ZCode scanner should estimate GLM-5.2 row cost")

        let summary = try scanner.loadSummary(now: now)
        try expect(summary.todayTokens == 1050, "ZCode summary should include today's tokens")
        try expect(summary.totalTokens == 1050, "ZCode summary should include total tokens")
        try expectClose(summary.cacheHitPercent, 19.047619, "ZCode summary should calculate cache hit percentage", tolerance: 0.00001)
    }

    private static func runSQLite(db: URL, sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [db.path, sql]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "sqlite3 failed"
            throw TestError.failure(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
