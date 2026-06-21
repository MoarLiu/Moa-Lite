import AppKit
import Foundation
import SwiftUI

extension AppDelegate {
    func rebuildProfileMenu() { mainMenuCoordinator.rebuildProfileMenu() }
    func rebuildProviderBridgeMenu() { mainMenuCoordinator.rebuildProviderBridgeMenu() }
    func rebuildZCodeMenu() { mainMenuCoordinator.rebuildZCodeMenu() }
    func providerPresetSubmenuItem(title: String, presets: [MoaProviderPreset]) -> NSMenuItem {
        mainMenuCoordinator.providerPresetSubmenuItem(title: title, presets: presets)
    }
    func rebuildClaudeDesktopProfilesMenu() { mainMenuCoordinator.rebuildClaudeDesktopProfilesMenu() }
    @objc func applyProviderBridgeProfileAction(_ sender: NSMenuItem) { providerActionCoordinator.applyProviderBridgeProfileAction(sender) }
    @objc func addProfileAction() { providerActionCoordinator.addProfileAction() }
    @objc func addProviderBridgeConfigAction() { providerActionCoordinator.addProviderBridgeConfigAction() }
    @objc func addProviderPresetAction(_ sender: NSMenuItem) { providerActionCoordinator.addProviderPresetAction(sender) }
    func addProviderPresetProfile(_ input: (name: String, baseURL: String, apiKey: String), preset: MoaProviderPreset) {
        providerActionCoordinator.addProviderPresetProfile(input, preset: preset)
    }
    @objc func startProviderBridgeAction() { providerActionCoordinator.startProviderBridgeAction() }
    @objc func applyCodexProviderBridgeModeAction() { providerActionCoordinator.applyCodexProviderBridgeModeAction() }
    @objc func stopProviderBridgeAction() { providerActionCoordinator.stopProviderBridgeAction() }
    @objc func repairProviderBridgeAction() { providerActionCoordinator.repairProviderBridgeAction() }
    @objc func copyBridgeCurlCommandAction() { providerActionCoordinator.copyBridgeCurlCommandAction() }
    @objc func refreshBridgeModelsAction() { providerActionCoordinator.refreshBridgeModelsAction() }
    @objc func regenerateBridgeTokenAction() { providerActionCoordinator.regenerateBridgeTokenAction() }
    @objc func testCodexActiveProviderAction() { providerActionCoordinator.testCodexActiveProviderAction() }
    func testProviderBridgeActiveProfileAction() { providerActionCoordinator.testProviderBridgeActiveProfileAction() }
    func testCodexProvider(_ profile: ConfigProfile) async throws -> ProviderConnectionTestResult {
        try await providerActionCoordinator.testCodexProvider(profile)
    }
    func testProviderBridgeProvider(_ profile: ConfigProfile) async throws -> ProviderConnectionTestResult {
        try await providerActionCoordinator.testProviderBridgeProvider(profile)
    }
    func bridgeCurlCommand(forProviderBridgeProfile profile: ConfigProfile) throws -> String {
        try providerActionCoordinator.bridgeCurlCommand(forProviderBridgeProfile: profile)
    }
    func bridgeCurlCommand(forRunningProviderBridgeProfile running: ConfigProfile) -> String {
        providerActionCoordinator.bridgeCurlCommand(forRunningProviderBridgeProfile: running)
    }
    @objc func copyCodexConfigAction() { providerActionCoordinator.copyCodexConfigAction() }
    func copyProviderBridgeCodexConfigAction() { providerActionCoordinator.copyProviderBridgeCodexConfigAction() }
    func codexConfigSnippet(for profile: ConfigProfile) throws -> String { try providerActionCoordinator.codexConfigSnippet(for: profile) }
    func providerBridgeCodexConfigSnippet(for profile: ConfigProfile) throws -> String {
        try providerActionCoordinator.providerBridgeCodexConfigSnippet(for: profile)
    }
    func codexConfigSnippetContent(for readyProfile: ConfigProfile) -> String { providerActionCoordinator.codexConfigSnippetContent(for: readyProfile) }
    func codexProviderSnippetID(for profile: ConfigProfile) -> String { providerActionCoordinator.codexProviderSnippetID(for: profile) }
    func providerDisplayName(for profile: ConfigProfile) -> String { providerActionCoordinator.providerDisplayName(for: profile) }
}
