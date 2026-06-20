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
            ("LiteLLM preset no longer uses original Moa model name", testLiteLLMPresetName)
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
}
