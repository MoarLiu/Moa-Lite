import AppKit
import Foundation

func runHeadlessCommandIfNeeded() -> Int32? {
    let environment = ProcessInfo.processInfo.environment
    if let remoteValue = environment["MoaApplyRemoteConnections"], !remoteValue.isEmpty {
        let enabled = remoteValue == "1" || remoteValue.lowercased() == "true"
        let controller = FastStateController(environment: environment)
        do {
            try controller.applyRemoteConnections(enabled)
            return 0
        } catch {
            fputs("Moa: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    guard let profileID = environment["MoaApplyProfileID"], !profileID.isEmpty else {
        return nil
    }

    let controller = ConfigProfileController(environment: environment)
    do {
        _ = try controller.applyProfile(id: profileID)
        return 0
    } catch {
        fputs("Moa: \(error.localizedDescription)\n", stderr)
        return 1
    }
}

#if !MOA_TESTING
@main
private enum MoaApplication {
    static func main() {
        do {
            try MoaDataRoot.migrateLegacyMoaLiteRootsIfNeeded()
        } catch {
            NSLog("Moa legacy Moa-Lite data migration failed: \(error.localizedDescription)")
        }

        if let exitCode = runHeadlessCommandIfNeeded() {
            exit(exitCode)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
#endif
