import Foundation

struct ProviderConnectionTestResult {
    let model: String
    let endpoint: String
}

private enum ProviderConnectionTestError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL(String)
    case missingAPIKey
    case requestFailed(Int, String)
    case noReachableEndpoint(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return MoaL10n.text("Fill API Base URL first.")
        case .invalidBaseURL(let message):
            return message
        case .missingAPIKey:
            return MoaL10n.text("Fill API Key first.")
        case .requestFailed(let status, let message):
            if message.isEmpty {
                return MoaL10n.format("Connection test failed: HTTP %d.", status)
            }
            return MoaL10n.format("Connection test failed: HTTP %d, %@.", status, message)
        case .noReachableEndpoint(let message):
            return message.isEmpty ? MoaL10n.text("No test endpoint is reachable.") : message
        }
    }
}

enum ProviderConnectionTester {
    static let codexTestModel = "gpt-5.5"
    static let claudeDefaultTestModel = "claude-opus-4-8"

    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func codexTestModel(for baseURL: String) -> String {
        baseURL.lowercased().contains("api.deepseek.com")
            ? MoaProviderBridgeDefaults.deepSeekChatModel
            : codexTestModel
    }

    static func testCodex(baseURL: String, apiKey: String, modelOverride: String? = nil) async throws -> ProviderConnectionTestResult {
        let baseURL = try validatedBaseURL(baseURL)
        let apiKey = try validatedAPIKey(apiKey)
        let model = modelOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? modelOverride!.trimmingCharacters(in: .whitespacesAndNewlines)
            : codexTestModel(for: baseURL.absoluteString)
        let responsesBody: [String: Any] = [
            "model": model,
            "input": "ping",
            "max_output_tokens": 1
        ]

        do {
            let endpoint = try await postJSON(
                body: responsesBody,
                baseURL: baseURL,
                endpoint: "responses",
                apiKey: apiKey,
                headers: [:])
            return ProviderConnectionTestResult(model: model, endpoint: endpoint)
        } catch ProviderConnectionTestError.requestFailed(let status, _) where shouldFallbackToChatCompletions(forHTTPStatus: status) {
            let chatBody: [String: Any] = [
                "model": model,
                "messages": [["role": "user", "content": "ping"]],
                "max_tokens": 1
            ]
            let endpoint = try await postJSON(
                body: chatBody,
                baseURL: baseURL,
                endpoint: "chat/completions",
                apiKey: apiKey,
                headers: [:])
            return ProviderConnectionTestResult(model: model, endpoint: endpoint)
        }
    }

    static func testClaude(baseURL: String, apiKey: String, models: [String]) async throws -> ProviderConnectionTestResult {
        let baseURL = try validatedBaseURL(baseURL)
        let apiKey = try validatedAPIKey(apiKey)
        let model = models.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? models[0].trimmingCharacters(in: .whitespacesAndNewlines)
            : claudeDefaultTestModel
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ping"]]
        ]
        let endpoint = try await postJSON(
            body: body,
            baseURL: baseURL,
            endpoint: "messages",
            apiKey: apiKey,
            headers: ["anthropic-version": "2023-06-01"])
        return ProviderConnectionTestResult(model: model, endpoint: endpoint)
    }

    static func fetchModelIDs(baseURL: String, apiKey: String, limit: Int = 80) async throws -> [String] {
        let baseURL = try validatedBaseURL(baseURL)
        let apiKey = try validatedAPIKey(apiKey)
        var lastError: Error?
        for url in endpointURLs(baseURL: baseURL, endpoint: "models") {
            do {
                let modelIDs = try await getModelIDs(from: url, apiKey: apiKey, limit: limit)
                if !modelIDs.isEmpty {
                    return modelIDs
                }
                lastError = ProviderConnectionTestError.noReachableEndpoint(MoaL10n.text("The models endpoint returned no model IDs."))
            } catch let error as ProviderConnectionTestError {
                lastError = error
                if case .requestFailed(let status, _) = error,
                   !shouldTryNextEndpointCandidate(forHTTPStatus: status) {
                    throw error
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        throw ProviderConnectionTestError.noReachableEndpoint("")
    }

    private static func validatedBaseURL(_ raw: String) throws -> URL {
        do {
            return try MoaProviderBaseURLPolicy.validate(raw).url
        } catch MoaProviderBaseURLError.empty {
            throw ProviderConnectionTestError.missingBaseURL
        } catch {
            throw ProviderConnectionTestError.invalidBaseURL(error.localizedDescription)
        }
    }

    private static func validatedAPIKey(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderConnectionTestError.missingAPIKey
        }
        return trimmed
    }

    private static func postJSON(
        body: [String: Any],
        baseURL: URL,
        endpoint: String,
        apiKey: String,
        headers: [String: String]
    ) async throws -> String {
        var lastError: Error?
        for url in endpointURLs(baseURL: baseURL, endpoint: endpoint) {
            do {
                try await postJSON(body, to: url, apiKey: apiKey, headers: headers)
                return url.absoluteString
            } catch let error as ProviderConnectionTestError {
                lastError = error
                if case .requestFailed(let status, _) = error,
                   !shouldTryNextEndpointCandidate(forHTTPStatus: status) {
                    throw error
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        throw ProviderConnectionTestError.noReachableEndpoint("")
    }

    private static func postJSON(_ body: [String: Any], to url: URL, apiKey: String, headers: [String: String]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderConnectionTestError.noReachableEndpoint(MoaL10n.text("The connection test did not receive a valid response."))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ProviderConnectionTestError.requestFailed(httpResponse.statusCode, errorMessage(from: data))
        }
    }

    private static func getModelIDs(from url: URL, apiKey: String, limit: Int) async throws -> [String] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderConnectionTestError.noReachableEndpoint(MoaL10n.text("The models request did not receive a valid response."))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ProviderConnectionTestError.requestFailed(httpResponse.statusCode, errorMessage(from: data))
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = object["data"] as? [[String: Any]]
        else {
            throw ProviderConnectionTestError.noReachableEndpoint(MoaL10n.text("The models endpoint did not return a model list."))
        }

        var seen = Set<String>()
        var output: [String] = []
        for entry in dataArray {
            guard let id = entry["id"] as? String else { continue }
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            output.append(trimmed)
            if output.count >= max(1, limit) {
                break
            }
        }
        return output
    }

    private static func endpointURLs(baseURL: URL, endpoint: String) -> [URL] {
        let normalizedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let existingPath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if existingPath.hasSuffix(normalizedEndpoint) {
            return [baseURL]
        }

        var candidates: [URL] = []
        if existingPath.isEmpty {
            candidates.append(baseURL.appendingPathComponent("v1").appendingPathComponent(normalizedEndpoint))
        } else if !existingPath.hasSuffix("v1") && !existingPath.contains("/v1/") {
            candidates.append(baseURL.appendingPathComponent("v1").appendingPathComponent(normalizedEndpoint))
        }

        candidates.append(baseURL.appendingPathComponent(normalizedEndpoint))
        return deduplicated(candidates)
    }

    private static func shouldFallbackToChatCompletions(forHTTPStatus status: Int) -> Bool {
        status == 400 || status == 404 || status == 405
    }

    private static func shouldTryNextEndpointCandidate(forHTTPStatus status: Int) -> Bool {
        status == 400 || status == 404 || status == 405
    }

    private static func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var output: [URL] = []
        for url in urls where !seen.contains(url.absoluteString) {
            seen.insert(url.absoluteString)
            output.append(url)
        }
        return output
    }

    private static func errorMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        if let error = object["error"] as? [String: Any] {
            return (error["message"] as? String) ?? String(describing: error)
        }

        if let message = object["message"] as? String {
            return message
        }

        return ""
    }
}
