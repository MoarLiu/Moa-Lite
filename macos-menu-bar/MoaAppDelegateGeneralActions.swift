import AppKit
import Foundation
import SwiftUI

extension AppDelegate {
    @objc func refreshStatusAction() {
        usageCoordinator.refreshCodex(forceRefresh: true)
    }

    @objc func openCodexAction() {
        controller.openCodex()
    }

    @objc func exportDataPackageAction() {
        guard confirmSensitiveDataPackageExport() else {
            return
        }

        let panel = NSSavePanel()
        panel.title = MoaL10n.text("Export Moa-Lite Data Package")
        panel.nameFieldStringValue = dataPackageController.defaultDataPackageURL().lastPathComponent
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        statusItemText.title = Self.statusTitle("Exporting Moa-Lite data...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.dataPackageController.exportDataPackage(to: destination)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self.statusItemText.title = Self.statusTitle("Exported Moa-Lite data package")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Moa-Lite Data Exported"),
                        informativeText: url.path,
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = Self.statusTitle("Export failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc func importDataPackageAction() {
        let panel = NSOpenPanel()
        panel.title = MoaL10n.text("Import Moa-Lite Data Package")
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let packageURL = panel.url else {
            return
        }
        guard confirmDataPackageImport() else {
            return
        }

        statusItemText.title = Self.statusTitle("Importing Moa-Lite data...")
        NotificationCenter.default.post(name: MoaDataRoot.willChangeNotification, object: nil)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.dataPackageController.importDataPackage(from: packageURL)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let rollbackURL):
                    self.refreshStatus()
                    NotificationCenter.default.post(name: MoaDataRoot.didChangeNotification, object: nil)
                    self.statusItemText.title = Self.statusTitle("Imported Moa-Lite data package")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Moa-Lite Data Imported"),
                        informativeText: MoaL10n.format("Rollback package: %@\nRestart Moa-Lite if any window still shows old data.", rollbackURL.path),
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = Self.statusTitle("Import failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc func exportDiagnosticPackageAction() {
        let panel = NSSavePanel()
        panel.title = MoaL10n.text("Export Diagnostic Package")
        panel.nameFieldStringValue = dataPackageController.defaultDiagnosticPackageURL().lastPathComponent
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        statusItemText.title = Self.statusTitle("Exporting diagnostics...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.dataPackageController.exportDiagnosticPackage(to: destination)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self.statusItemText.title = Self.statusTitle("Exported diagnostics")
                    MoaNonBlockingAlert.present(
                        messageText: MoaL10n.text("Diagnostic Package Exported"),
                        informativeText: url.path,
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = Self.statusTitle("Diagnostic export failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc func toggleICloudStorageAction() {
        let enabled = dataPackageController.isICloudStorageEnabled()
        guard confirmICloudStorageChange(enabling: !enabled) else {
            return
        }

        statusItemText.title = enabled ? Self.statusTitle("Moving Moa-Lite data to this Mac...") : Self.statusTitle("Moving Moa-Lite data to iCloud...")
        NotificationCenter.default.post(name: MoaDataRoot.willChangeNotification, object: nil)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                if enabled {
                    return try self.dataPackageController.disableICloudStorage()
                }
                return try self.dataPackageController.enableICloudStorage()
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let rollbackURL):
                    self.configureMoaDataMenu()
                    NotificationCenter.default.post(name: MoaDataRoot.didChangeNotification, object: nil)
                    self.statusItemText.title = enabled ? Self.statusTitle("Moa-Lite data moved to this Mac") : Self.statusTitle("Moa-Lite data stored in iCloud")
                    MoaNonBlockingAlert.present(
                        messageText: enabled ? MoaL10n.text("Moa-Lite Data Moved to This Mac") : MoaL10n.text("Moa-Lite Data Stored in iCloud"),
                        informativeText: MoaL10n.format("Rollback package: %@\nRestart Moa-Lite if any window still shows old data.", rollbackURL.path),
                        tone: .success
                    )
                case .failure(let error):
                    NSSound.beep()
                    self.statusItemText.title = Self.statusTitle("iCloud data move failed")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc func openMoaDataFolderAction() {
        dataPackageController.openMoaHome()
    }

    @objc func openICloudDataFolderAction() {
        dataPackageController.openICloudMoaHome()
    }

    func confirmSensitiveDataPackageExport() -> Bool {
        MoaNonBlockingAlert.confirm(
            messageText: MoaL10n.text("Export Moa-Lite Data Package?"),
            informativeText: MoaL10n.text("This package contains your full Moa-Lite data folder, including provider API keys and local configuration. Store it only in a trusted place."),
            primaryButtonTitle: MoaL10n.text("Export"),
            tone: .warning
        )
    }

    func confirmDataPackageImport() -> Bool {
        MoaNonBlockingAlert.confirm(
            messageText: MoaL10n.text("Import Moa-Lite Data Package?"),
            informativeText: MoaL10n.text("Importing replaces the current Moa-Lite data folder. Moa-Lite will create a rollback package first."),
            primaryButtonTitle: MoaL10n.text("Import"),
            tone: .warning
        )
    }

    func confirmICloudStorageChange(enabling: Bool) -> Bool {
        MoaNonBlockingAlert.confirm(
            messageText: enabling ? MoaL10n.text("Store Moa-Lite Data in iCloud?") : MoaL10n.text("Move Moa-Lite Data Back to This Mac?"),
            informativeText: enabling
                ? MoaL10n.text("If iCloud Drive/Moa-Lite already has Moa-Lite data, Moa-Lite will use that existing iCloud folder and will not overwrite it. If it is empty, Moa-Lite will copy the current ~/.moa-lite contents there. Provider API keys, auth.json, config.toml, and profile databases may be stored in iCloud.")
                : MoaL10n.text("Moa-Lite will copy iCloud Drive/Moa-Lite back to ~/.moa-lite, then use the local folder as its data folder."),
            primaryButtonTitle: enabling ? MoaL10n.text("Use iCloud") : MoaL10n.text("Use This Mac"),
            tone: .warning
        )
    }

    @objc func openMoaFolderAction() {
        profileController.openMoaFolder()
    }

    @objc func openCodexFolderAction() {
        profileController.openCodexFolder()
    }

    @objc func reopenCodexAction() {
        statusItemText.title = Self.statusTitle("Reopening Codex...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.controller.reopenCodex()

            DispatchQueue.main.async {
                self.refreshStatus()
            }
        }
    }

    @objc func quitAction() {
        NSApp.terminate(nil)
    }
}
