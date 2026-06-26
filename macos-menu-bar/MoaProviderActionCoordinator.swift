import AppKit
import Foundation
import SwiftUI

final class MoaProviderActionCoordinator {
    unowned let app: AppDelegate

    init(app: AppDelegate) {
        self.app = app
    }

    var profileController: ConfigProfileController { app.profileController }
    var providerBridgeProfileController: ProviderBridgeProfileController { app.providerBridgeProfileController }
    var providerBridgeServer: MoaProviderBridgeServer { app.providerBridgeServer }
    var controller: FastStateController { app.controller }
    var statusItemText: NSMenuItem { app.statusItemText }

    var providerBridgeLastHealthCheckAt: Date? {
        get { app.providerBridgeLastHealthCheckAt }
        set { app.providerBridgeLastHealthCheckAt = newValue }
    }

    var providerBridgeLastErrorSummary: String {
        get { app.providerBridgeLastErrorSummary }
        set { app.providerBridgeLastErrorSummary = newValue }
    }

    func rebuildCodexProviderMenus() { app.rebuildCodexProviderMenus() }
    func refreshStatus() { app.refreshStatus() }
    func showError(_ message: String) { app.showError(message) }
    func showAddProfilePanel() -> (name: String, baseURL: String, apiKey: String)? { app.showAddProfilePanel() }
    func copyToPasteboard(_ text: String) { app.copyToPasteboard(text) }
    func stopProviderBridge() { app.stopProviderBridge() }
    func preferredProviderBridgeProfile() throws -> ConfigProfile { try app.preferredProviderBridgeProfile() }
    func preparedProviderBridgeRuntimeProfile() throws -> ConfigProfile { try app.preparedProviderBridgeRuntimeProfile() }
    func preparedProviderBridgeRuntimeProfile(_ source: ConfigProfile) throws -> ConfigProfile { try app.preparedProviderBridgeRuntimeProfile(source) }
    func ensureProviderBridge(for profile: ConfigProfile) throws -> ConfigProfile { try app.ensureProviderBridge(for: profile) }
    func syncCodexProviderBridgeModeIfNeeded(_ profile: ConfigProfile, reopenCodex: Bool = false) throws -> ConfigProfile {
        try app.syncCodexProviderBridgeModeIfNeeded(profile, reopenCodex: reopenCodex)
    }

    func applyProviderBridgeProfileAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        statusItemText.title = AppDelegate.statusTitle("Switching Provider Bridge...")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.providerBridgeProfileController.applyProfile(id: id)
                guard self.providerBridgeServer.snapshot().isRunning else {
                    return profile
                }

                let prepared = try self.preparedProviderBridgeRuntimeProfile(profile)
                let running = try self.ensureProviderBridge(for: prepared)
                return try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    if self.providerBridgeServer.snapshot().isRunning {
                        self.statusItemText.title = AppDelegate.statusTitle(
                            "Bridge ready: %@ · :%d",
                            profile.name,
                            self.providerBridgeServer.snapshot().port ?? profile.resolvedBridgePort
                        )
                    } else {
                        self.statusItemText.title = AppDelegate.statusTitle("Provider Bridge selected: %@", profile.name)
                    }
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Provider Bridge failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    func addProfileAction() {
        guard let input = showAddProfilePanel() else {
            return
        }

        do {
            _ = try profileController.addProfile(name: input.name, baseURL: input.baseURL, apiKey: input.apiKey)
            rebuildCodexProviderMenus()
            statusItemText.title = AppDelegate.statusTitle("Added %@", input.name)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func addProviderBridgeConfigAction() {
        guard let input = MoaProviderProfilePanels.showAddProviderBridgeConfig() else {
            return
        }

        statusItemText.title = AppDelegate.statusTitle("Adding Provider Bridge config...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.providerBridgeProfileController.addProfile(
                    name: input.name,
                    baseURL: input.baseURL,
                    apiKey: input.apiKey,
                    preset: input.preset
                )
                guard self.providerBridgeServer.snapshot().isRunning else {
                    return profile
                }

                let prepared = try self.preparedProviderBridgeRuntimeProfile(profile)
                let running = try self.ensureProviderBridge(for: prepared)
                return try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    if self.providerBridgeServer.snapshot().isRunning {
                        self.statusItemText.title = AppDelegate.statusTitle(
                            "Bridge ready: %@ · :%d",
                            profile.name,
                            self.providerBridgeServer.snapshot().port ?? profile.resolvedBridgePort
                        )
                    } else {
                        self.statusItemText.title = AppDelegate.statusTitle("Added %@", profile.name)
                    }
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Provider Bridge failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func addProviderPresetAction(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String,
              let preset = MoaProviderPresets.preset(id: presetID)
        else {
            showError(MoaL10n.text("Provider preset not found."))
            return
        }
        guard let input = MoaProviderProfilePanels.showAddCodexPresetProfile(preset) else {
            return
        }

        addProviderPresetProfile(input, preset: preset)
    }

    func addProviderPresetProfile(
        _ input: (name: String, baseURL: String, apiKey: String),
        preset: MoaProviderPreset
    ) {
        do {
            let upstreamBaseURL = preset.bridgeMode == .localBridge
                ? input.baseURL
                : preset.upstreamBaseURL
            _ = try profileController.addProfile(
                name: input.name,
                baseURL: input.baseURL,
                apiKey: input.apiKey,
                providerKind: preset.providerKind,
                clientTarget: preset.clientTarget,
                upstreamProtocol: preset.upstreamProtocol,
                bridgeMode: preset.bridgeMode,
                upstreamBaseURL: upstreamBaseURL,
                model: preset.model,
                testModel: preset.testModel,
                models: preset.models,
                reasoningMode: preset.reasoningMode
            )
            rebuildCodexProviderMenus()
            statusItemText.title = AppDelegate.statusTitle("Added %@", input.name)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func startProviderBridgeAction() {
        statusItemText.title = AppDelegate.statusTitle("Starting Provider Bridge...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preparedProviderBridgeRuntimeProfile()
                let running = try self.ensureProviderBridge(for: profile)
                return try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let runningProfile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle(
                        "Bridge ready: %@ · :%d",
                        runningProfile.name,
                        self.providerBridgeServer.snapshot().port ?? runningProfile.resolvedBridgePort
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Bridge failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func applyCodexProviderBridgeModeAction() {
        statusItemText.title = AppDelegate.statusTitle("Switching Codex to Provider Bridge...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preparedProviderBridgeRuntimeProfile()
                let running = try self.ensureProviderBridge(for: profile)
                return try self.profileController.applyProviderBridgeGateway(profile: running)
            }

            switch result {
            case .success:
                self.controller.reopenCodex()
            case .failure:
                break
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    self.statusItemText.title = AppDelegate.statusTitle("Codex using Provider Bridge: %@", profile.name)
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Provider Bridge failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func stopProviderBridgeAction() {
        stopProviderBridge()
    }

    func repairProviderBridgeAction() {
        statusItemText.title = AppDelegate.statusTitle("Repairing Provider Bridge...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preferredProviderBridgeProfile()
                self.providerBridgeServer.stop()
                let prepared = try self.preparedProviderBridgeRuntimeProfile(profile)
                let running = try self.ensureProviderBridge(for: prepared)
                return try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let runningProfile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    self.statusItemText.title = AppDelegate.statusTitle(
                        "Bridge repaired: %@ · :%d",
                        runningProfile.name,
                        self.providerBridgeServer.snapshot().port ?? runningProfile.resolvedBridgePort
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Bridge repair failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func copyBridgeCurlCommandAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preferredProviderBridgeProfile()
                return try self.bridgeCurlCommand(forProviderBridgeProfile: profile)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let command):
                    self.copyToPasteboard(command)
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Bridge curl copied")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Bridge curl copied"),
                        informativeText: MoaL10n.text("The curl command uses a redacted <bridge-token> placeholder."),
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = AppDelegate.statusTitle("Failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func refreshBridgeModelsAction() {
        statusItemText.title = AppDelegate.statusTitle("Refreshing models...")
        Task.detached { [weak self] in
            guard let self else { return }
            let result: Result<ConfigProfile, Error>
            do {
                let profile = try self.preferredProviderBridgeProfile()
                let models = try await ProviderConnectionTester.fetchModelIDs(
                    baseURL: profile.resolvedUpstreamBaseURL,
                    apiKey: profile.apiKey
                )
                let updated = try self.providerBridgeProfileController.updateModels(id: profile.id, models: models)
                if self.providerBridgeServer.snapshot().profileID == profile.id {
                    self.providerBridgeServer.stop()
                    let prepared = try self.preparedProviderBridgeRuntimeProfile(updated)
                    let running = try self.ensureProviderBridge(for: prepared)
                    _ = try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
                }
                result = .success(updated)
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                switch result {
                case .success(let updated):
                    self.providerBridgeLastHealthCheckAt = Date()
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    self.statusItemText.title = AppDelegate.statusTitle("Models refreshed: %d", updated.models?.count ?? 0)
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Models refreshed"),
                        informativeText: (updated.models ?? []).prefix(12).joined(separator: "\n"),
                        tone: .success
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Model refresh failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func regenerateBridgeTokenAction() {
        guard MoaNonBlockingAlert.confirm(
            messageText: MoaL10n.text("Regenerate Provider Bridge Token?"),
            informativeText: MoaL10n.text("Moa will update the selected Provider Bridge config and restart the local bridge. Any old bridge curl command will stop working."),
            primaryButtonTitle: MoaL10n.text("Regenerate"),
            tone: .warning
        ) else {
            return
        }

        statusItemText.title = AppDelegate.statusTitle("Regenerating bridge token...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preferredProviderBridgeProfile()
                let token = try MoaProviderBridgeToken.generate()
                let updated = try self.providerBridgeProfileController.updateBridgeRuntime(id: profile.id, token: token)
                let prepared = try self.preparedProviderBridgeRuntimeProfile(updated)
                let running = try self.ensureProviderBridge(for: prepared)
                return try self.syncCodexProviderBridgeModeIfNeeded(running, reopenCodex: true)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let runningProfile):
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.refreshStatus()
                    self.statusItemText.title = AppDelegate.statusTitle(
                        "Bridge token regenerated: %@",
                        runningProfile.bridgeToken.map { MoaProviderBridgeToken.sha256Prefix($0) } ?? ""
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Token regeneration failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func testCodexActiveProviderAction() {
        guard let profile = try? profileController.selectedProfile() else {
            showError(MoaL10n.text("Select a configuration before testing."))
            return
        }

        statusItemText.title = AppDelegate.statusTitle("Testing %@...", profile.name)
        Task.detached { [weak self] in
            guard let self else { return }
            let result: Result<ProviderConnectionTestResult, Error>
            do {
                result = .success(try await self.testCodexProvider(profile))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                switch result {
                case .success(let testResult):
                    self.providerBridgeLastHealthCheckAt = Date()
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Connection works: %@", testResult.model)
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Connection works"),
                        informativeText: MoaL10n.format("Model: %@\nEndpoint: %@", testResult.model, testResult.endpoint),
                        tone: .success
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Connection test failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func testProviderBridgeActiveProfileAction() {
        statusItemText.title = AppDelegate.statusTitle("Testing Provider Bridge...")
        Task.detached { [weak self] in
            guard let self else { return }
            let result: Result<ProviderConnectionTestResult, Error>
            do {
                let profile = try self.preferredProviderBridgeProfile()
                result = .success(try await self.testProviderBridgeProvider(profile))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                switch result {
                case .success(let testResult):
                    self.providerBridgeLastHealthCheckAt = Date()
                    self.providerBridgeLastErrorSummary = ""
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Connection works: %@", testResult.model)
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Connection works"),
                        informativeText: MoaL10n.format("Model: %@\nEndpoint: %@", testResult.model, testResult.endpoint),
                        tone: .success
                    )
                case .failure(let error):
                    self.providerBridgeLastErrorSummary = error.localizedDescription
                    NSSound.beep()
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Connection test failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func testCodexProvider(_ profile: ConfigProfile) async throws -> ProviderConnectionTestResult {
        if profile.usesLocalProviderBridge {
            let applied = try profileController.applyProfile(id: profile.id)
            let running = try ensureProviderBridge(for: applied)
            return try await ProviderConnectionTester.testCodex(
                baseURL: running.codexBaseURL,
                apiKey: running.codexBearerToken,
                modelOverride: running.resolvedTestModel ?? running.resolvedModel ?? MoaProviderBridgeDefaults.deepSeekChatModel
            )
        }

        return try await ProviderConnectionTester.testCodex(
            baseURL: profile.baseURL,
            apiKey: profile.apiKey,
            modelOverride: profile.resolvedTestModel
        )
    }

    func testProviderBridgeProvider(_ profile: ConfigProfile) async throws -> ProviderConnectionTestResult {
        let prepared = try preparedProviderBridgeRuntimeProfile(profile)
        let running = try ensureProviderBridge(for: prepared)
        let synced = try syncCodexProviderBridgeModeIfNeeded(running)
        return try await ProviderConnectionTester.testCodex(
            baseURL: synced.codexBaseURL,
            apiKey: synced.codexBearerToken,
            modelOverride: synced.resolvedTestModel ?? synced.resolvedModel ?? MoaProviderBridgeDefaults.deepSeekChatModel
        )
    }

    func bridgeCurlCommand(forProviderBridgeProfile profile: ConfigProfile) throws -> String {
        let prepared = try preparedProviderBridgeRuntimeProfile(profile)
        let running = try ensureProviderBridge(for: prepared)
        let synced = try syncCodexProviderBridgeModeIfNeeded(running)
        return bridgeCurlCommand(forRunningProviderBridgeProfile: synced)
    }

    func bridgeCurlCommand(forRunningProviderBridgeProfile running: ConfigProfile) -> String {
        let model = running.resolvedTestModel
            ?? running.resolvedModel
            ?? running.models?.first
            ?? MoaProviderBridgeDefaults.deepSeekChatModel
        let json = #"{"model":"\#(AppDelegate.jsonEscaped(model))","input":"ping","max_output_tokens":1}"#
        return """
        curl -sS \(AppDelegate.shellSingleQuoted("\(running.codexBaseURL)/responses")) \\
          -H 'Authorization: Bearer <bridge-token>' \\
          -H 'Content-Type: application/json' \\
          -d \(AppDelegate.shellSingleQuoted(json))
        """
    }

    func copyCodexConfigAction() {
        guard let profile = try? profileController.selectedProfile() else {
            showError(MoaL10n.text("Select a configuration before copying."))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.codexConfigSnippet(for: profile)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let snippet):
                    self.copyToPasteboard(snippet)
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Codex config copied")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Codex config copied"),
                        informativeText: MoaL10n.text("The selected Codex provider config snippet is on the clipboard."),
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = AppDelegate.statusTitle("Failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func copyProviderBridgeCodexConfigAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let profile = try self.preferredProviderBridgeProfile()
                return try self.providerBridgeCodexConfigSnippet(for: profile)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let snippet):
                    self.copyToPasteboard(snippet)
                    self.rebuildCodexProviderMenus()
                    self.statusItemText.title = AppDelegate.statusTitle("Codex config copied")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Codex config copied"),
                        informativeText: MoaL10n.text("The Provider Bridge Codex config snippet is on the clipboard."),
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = AppDelegate.statusTitle("Failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func codexConfigSnippet(for profile: ConfigProfile) throws -> String {
        let readyProfile: ConfigProfile
        if profile.usesLocalProviderBridge {
            let applied = try profileController.applyProfile(id: profile.id)
            readyProfile = try ensureProviderBridge(for: applied)
        } else {
            readyProfile = profile
        }

        return codexConfigSnippetContent(for: readyProfile)
    }

    func providerBridgeCodexConfigSnippet(for profile: ConfigProfile) throws -> String {
        let prepared = try preparedProviderBridgeRuntimeProfile(profile)
        let running = try ensureProviderBridge(for: prepared)
        let synced = try syncCodexProviderBridgeModeIfNeeded(running)
        return codexConfigSnippetContent(for: synced)
    }

    func codexConfigSnippetContent(for readyProfile: ConfigProfile) -> String {
        let providerID = codexProviderSnippetID(for: readyProfile)
        let model = readyProfile.resolvedModel
            ?? readyProfile.resolvedTestModel
            ?? ProviderConnectionTester.codexTestModel(for: readyProfile.codexBaseURL)
        let block = MoaCodexConfigEditor.providerBlock(
            providerID: providerID,
            displayName: readyProfile.usesLocalProviderBridge ? providerDisplayName(for: readyProfile) : readyProfile.name,
            baseURL: readyProfile.codexBaseURL,
            apiKey: readyProfile.codexBearerToken,
            extraLines: []
        )

        return """
        model = "\(AppDelegate.tomlEscaped(model))"
        model_provider = "\(AppDelegate.tomlEscaped(providerID))"

        \(block)
        """
    }

    func codexProviderSnippetID(for profile: ConfigProfile) -> String {
        if profile.usesLocalProviderBridge && profile.resolvedProviderKind == .deepseek && profile.name.localizedCaseInsensitiveContains("deepseek") {
            return "moa-deepseek"
        }
        let slug = AppDelegate.identifierSlug(profile.name)
        if profile.usesLocalProviderBridge {
            return slug.isEmpty ? "moa-bridge" : "moa-\(slug)"
        }
        return slug.isEmpty ? "moa-provider" : "moa-\(slug)"
    }

    func providerDisplayName(for profile: ConfigProfile) -> String {
        profile.usesLocalProviderBridge ? "Moa \(profile.name)" : profile.name
    }
}
