import Foundation

enum MoaProviderPresetFamily: String, CaseIterable {
    case responsesNative
    case responsesGateway
    case chatCompletionsLocalBridge
}

struct MoaProviderPreset: Equatable {
    let id: String
    let family: MoaProviderPresetFamily
    let name: String
    let baseURL: String
    let upstreamBaseURL: String?
    let model: String
    let testModel: String
    let models: [String]
    let providerKind: MoaProviderKind
    let clientTarget: MoaProviderClientTarget
    let upstreamProtocol: MoaProviderUpstreamProtocol
    let bridgeMode: MoaProviderBridgeMode
    let reasoningMode: MoaProviderReasoningMode
    let responsesPath: [String]
    let chatCompletionsPath: [String]

    var resolvedUpstreamBaseURL: String {
        upstreamBaseURL ?? baseURL
    }

    var usesResponsesEndpoint: Bool {
        upstreamProtocol == .responses && !responsesPath.isEmpty
    }

    var usesChatCompletionsEndpoint: Bool {
        upstreamProtocol == .chatCompletions && !chatCompletionsPath.isEmpty
    }

    func makeConfigProfile(
        id profileID: String,
        apiKey: String = "",
        bridgeToken: String? = nil,
        bridgePort: Int? = nil
    ) -> ConfigProfile {
        ConfigProfile(
            id: profileID,
            name: name,
            baseURL: baseURL,
            apiKey: apiKey,
            schemaVersion: 2,
            providerKind: providerKind,
            clientTarget: clientTarget,
            upstreamProtocol: upstreamProtocol,
            bridgeMode: bridgeMode,
            upstreamBaseURL: upstreamBaseURL,
            model: model,
            testModel: testModel,
            models: models,
            reasoningMode: reasoningMode,
            bridgeToken: bridgeToken,
            bridgePort: bridgePort
        )
    }

    func responsesURL() throws -> URL? {
        guard usesResponsesEndpoint else { return nil }
        return try endpointURL(baseURL: baseURL, path: responsesPath)
    }

    func chatCompletionsURL() throws -> URL? {
        guard usesChatCompletionsEndpoint else { return nil }
        return try endpointURL(baseURL: resolvedUpstreamBaseURL, path: chatCompletionsPath)
    }

    private func endpointURL(baseURL raw: String, path: [String]) throws -> URL {
        let validation = try MoaProviderBaseURLPolicy.validate(raw)
        guard var components = URLComponents(url: validation.url, resolvingAgainstBaseURL: false) else {
            throw MoaProviderBaseURLError.invalid(raw)
        }

        components.query = nil
        components.fragment = nil
        guard var url = components.url else {
            throw MoaProviderBaseURLError.invalid(raw)
        }

        for component in path {
            url.appendPathComponent(component)
        }
        return url
    }
}

enum MoaProviderPresets {
    static let responsesNative: [MoaProviderPreset] = [
        MoaProviderPreset(
            id: "openai-responses-native",
            family: .responsesNative,
            name: "OpenAI Responses Native",
            baseURL: "https://api.openai.com/v1",
            upstreamBaseURL: nil,
            model: "gpt-5.2-codex",
            testModel: "gpt-5.2-codex",
            models: [
                "gpt-5.2-codex",
                "gpt-5.1-codex-max",
                "gpt-5-codex"
            ],
            providerKind: .openai,
            clientTarget: .codex,
            upstreamProtocol: .responses,
            bridgeMode: .direct,
            reasoningMode: .auto,
            responsesPath: ["responses"],
            chatCompletionsPath: []
        )
    ]

    static let responsesGateways: [MoaProviderPreset] = [
        MoaProviderPreset(
            id: "openrouter-responses-gateway",
            family: .responsesGateway,
            name: "OpenRouter Responses Gateway",
            baseURL: "https://openrouter.ai/api/v1",
            upstreamBaseURL: nil,
            model: "openai/gpt-4o",
            testModel: "openai/gpt-4o-mini",
            models: [
                "openai/gpt-4o",
                "openai/gpt-4o-mini"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .responses,
            bridgeMode: .direct,
            reasoningMode: .auto,
            responsesPath: ["responses"],
            chatCompletionsPath: []
        ),
        MoaProviderPreset(
            id: "litellm-responses-gateway",
            family: .responsesGateway,
            name: "LiteLLM Responses Gateway",
            baseURL: "http://127.0.0.1:4000/v1",
            upstreamBaseURL: nil,
            model: "moa-lite-codex",
            testModel: "moa-lite-codex",
            models: [
                "moa-lite-codex"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .responses,
            bridgeMode: .direct,
            reasoningMode: .auto,
            responsesPath: ["responses"],
            chatCompletionsPath: []
        ),
        MoaProviderPreset(
            id: "portkey-responses-gateway",
            family: .responsesGateway,
            name: "Portkey Responses Gateway",
            baseURL: "https://api.portkey.ai/v1",
            upstreamBaseURL: nil,
            model: "gpt-4o-mini",
            testModel: "gpt-4o-mini",
            models: [
                "gpt-4o-mini"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .responses,
            bridgeMode: .direct,
            reasoningMode: .auto,
            responsesPath: ["responses"],
            chatCompletionsPath: []
        ),
        MoaProviderPreset(
            id: "helicone-responses-gateway",
            family: .responsesGateway,
            name: "Helicone Responses Gateway",
            baseURL: "https://ai-gateway.helicone.ai/v1",
            upstreamBaseURL: nil,
            model: "gpt-4o-mini",
            testModel: "gpt-4o-mini",
            models: [
                "gpt-4o-mini"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .responses,
            bridgeMode: .direct,
            reasoningMode: .auto,
            responsesPath: ["responses"],
            chatCompletionsPath: []
        )
    ]

    static let chatCompletionsLocalBridge: [MoaProviderPreset] = [
        MoaProviderPreset(
            id: "deepseek-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "DeepSeek Chat Bridge",
            baseURL: "https://api.deepseek.com",
            upstreamBaseURL: "https://api.deepseek.com",
            model: "deepseek-v4-pro",
            testModel: "deepseek-v4-flash",
            models: [
                "deepseek-v4-pro",
                "deepseek-v4-flash",
                "deepseek-chat",
                "deepseek-reasoner"
            ],
            providerKind: .deepseek,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["v1", "chat", "completions"]
        ),
        MoaProviderPreset(
            id: "kimi-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "Kimi Chat Bridge",
            baseURL: "https://api.moonshot.ai/v1",
            upstreamBaseURL: "https://api.moonshot.ai/v1",
            model: "kimi-k2.6",
            testModel: "kimi-k2.6",
            models: [
                "kimi-k2.6",
                "kimi-k2.5"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        ),
        MoaProviderPreset(
            id: "qwen-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "Qwen Chat Bridge",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            upstreamBaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            model: "qwen-plus",
            testModel: "qwen-plus",
            models: [
                "qwen-plus",
                "qwen-turbo",
                "qwen-max"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        ),
        MoaProviderPreset(
            id: "glm-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "GLM Chat Bridge",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            upstreamBaseURL: "https://open.bigmodel.cn/api/paas/v4",
            model: "glm-4.7",
            testModel: "glm-4.7",
            models: [
                "glm-4.7",
                "glm-4-plus",
                "glm-4-flash"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        ),
        MoaProviderPreset(
            id: "minimax-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "MiniMax Chat Bridge",
            baseURL: "https://api.minimax.io/v1",
            upstreamBaseURL: "https://api.minimax.io/v1",
            model: "MiniMax-M2.7",
            testModel: "MiniMax-M2.7",
            models: [
                "MiniMax-M2.7",
                "MiniMax-M2.7-highspeed"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        ),
        MoaProviderPreset(
            id: "siliconflow-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "SiliconFlow Chat Bridge",
            baseURL: "https://api.siliconflow.cn/v1",
            upstreamBaseURL: "https://api.siliconflow.cn/v1",
            model: "Qwen/Qwen3-32B",
            testModel: "Qwen/Qwen3-32B",
            models: [
                "Qwen/Qwen3-32B",
                "openai/gpt-oss-120b"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        ),
        MoaProviderPreset(
            id: "stepfun-chat-bridge",
            family: .chatCompletionsLocalBridge,
            name: "StepFun Chat Bridge",
            baseURL: "https://api.stepfun.ai/v1",
            upstreamBaseURL: "https://api.stepfun.ai/v1",
            model: "step-2-16k",
            testModel: "step-2-16k",
            models: [
                "step-2-16k",
                "step-1-8k"
            ],
            providerKind: .custom,
            clientTarget: .codex,
            upstreamProtocol: .chatCompletions,
            bridgeMode: .localBridge,
            reasoningMode: .auto,
            responsesPath: [],
            chatCompletionsPath: ["chat", "completions"]
        )
    ]

    static let all: [MoaProviderPreset] = responsesNative + responsesGateways + chatCompletionsLocalBridge

    static func preset(id: String) -> MoaProviderPreset? {
        all.first { $0.id == id }
    }
}
