import AppKit
import Foundation

final class MoaUsageCoordinator {
    let codexScanner: CodexUsageScanner
    let claudeScanner: ClaudeUsageScanner
    let codexSummaryItem = NSMenuItem()
    let codexRefreshItem = NSMenuItem()
    let claudeSummaryItem = NSMenuItem()
    let claudeRefreshItem = NSMenuItem()

    var onCodexSummaryLoaded: ((CodexUsageSummary) -> Void)?
    var onClaudeSummaryLoaded: ((CodexUsageSummary) -> Void)?

    private let codexSummaryView = CodexUsageSummaryMenuView()
    private let codexRefreshView = CodexUsageRefreshMenuView()
    private let claudeSummaryView = CodexUsageSummaryMenuView()
    private let claudeRefreshView = CodexUsageRefreshMenuView()
    private let codexQueue = DispatchQueue(label: "com.moarliu.moa-lite.codex-usage", qos: .utility)
    private let claudeQueue = DispatchQueue(label: "com.moarliu.moa-lite.claude-usage", qos: .utility)

    private var codexTimer: Timer?
    private var claudeTimer: Timer?
    private var codexSummary: CodexUsageSummary?
    private var claudeSummary: CodexUsageSummary?
    private var codexRefreshInFlight = false
    private var claudeRefreshInFlight = false

    private static let refreshMinimumDisplayDuration: TimeInterval = 0.6

    init(
        codexScanner: CodexUsageScanner = CodexUsageScanner(),
        claudeScanner: ClaudeUsageScanner = ClaudeUsageScanner()
    ) {
        self.codexScanner = codexScanner
        self.claudeScanner = claudeScanner
    }

    func start() {
        startCodex()
        startClaude()
    }

    func stop() {
        codexTimer?.invalidate()
        codexTimer = nil
        claudeTimer?.invalidate()
        claudeTimer = nil
        codexRefreshView.onRefresh = nil
        claudeRefreshView.onRefresh = nil
    }

    func refreshCodex(forceRefresh: Bool) {
        guard !codexRefreshInFlight else { return }
        let startedAt = Date()
        codexRefreshInFlight = true
        codexRefreshView.setRefreshing(true)
        codexSummaryView.apply(.loading(codexSummary))

        codexQueue.async {
            let result = Result {
                try self.codexScanner.loadSummary(forceRefresh: forceRefresh)
            }

            DispatchQueue.main.async {
                let completeRefresh = {
                    self.codexRefreshInFlight = false
                    self.codexRefreshView.setRefreshing(false)

                    switch result {
                    case .success(let summary):
                        self.codexSummary = summary
                        self.codexSummaryView.apply(.loaded(summary))
                        self.onCodexSummaryLoaded?(summary)
                    case .failure(let error):
                        self.codexSummaryView.apply(.failed(self.codexSummary, error.localizedDescription))
                    }
                }
                let minimumDuration = forceRefresh ? Self.refreshMinimumDisplayDuration : 0
                let delay = max(0, minimumDuration - Date().timeIntervalSince(startedAt))
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        completeRefresh()
                    }
                } else {
                    completeRefresh()
                }
            }
        }
    }

    func refreshClaude(forceRefresh: Bool) {
        guard !claudeRefreshInFlight else { return }
        let startedAt = Date()
        claudeRefreshInFlight = true
        claudeRefreshView.setRefreshing(true)
        claudeSummaryView.apply(.loading(claudeSummary))

        claudeQueue.async {
            let result = Result {
                try self.claudeScanner.loadSummary(forceRefresh: forceRefresh)
            }

            DispatchQueue.main.async {
                let completeRefresh = {
                    self.claudeRefreshInFlight = false
                    self.claudeRefreshView.setRefreshing(false)

                    switch result {
                    case .success(let summary):
                        self.claudeSummary = summary
                        self.claudeSummaryView.apply(.loaded(summary))
                        self.onClaudeSummaryLoaded?(summary)
                    case .failure(let error):
                        self.claudeSummaryView.apply(.failed(self.claudeSummary, error.localizedDescription))
                    }
                }
                let minimumDuration = forceRefresh ? Self.refreshMinimumDisplayDuration : 0
                let delay = max(0, minimumDuration - Date().timeIntervalSince(startedAt))
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        completeRefresh()
                    }
                } else {
                    completeRefresh()
                }
            }
        }
    }

    private func startCodex() {
        codexSummaryItem.view = codexSummaryView
        codexRefreshItem.view = codexRefreshView
        codexRefreshView.onRefresh = { [weak self] in
            self?.refreshCodex(forceRefresh: true)
        }
        codexSummaryView.apply(.idle)
        refreshCodex(forceRefresh: false)
        codexTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshCodex(forceRefresh: false)
        }
        if let codexTimer {
            RunLoop.main.add(codexTimer, forMode: .common)
        }
    }

    private func startClaude() {
        claudeSummaryItem.view = claudeSummaryView
        claudeRefreshItem.view = claudeRefreshView
        claudeRefreshView.onRefresh = { [weak self] in
            self?.refreshClaude(forceRefresh: true)
        }
        claudeSummaryView.apply(.idle)
        refreshClaude(forceRefresh: false)
        claudeTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshClaude(forceRefresh: false)
        }
        if let claudeTimer {
            RunLoop.main.add(claudeTimer, forMode: .common)
        }
    }
}
