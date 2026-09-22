import AppKit
import FluidUse
import Foundation
import SwiftUI
import WebKit

struct Example: Identifiable {
    let query: String
    /// Where a person would expect to land: page id and a fragment of the control label.
    let page: String
    let control: String
    var id: String { query }

    func matches(_ match: Match) -> Bool {
        match.page.id == page && match.control.label.localizedCaseInsensitiveContains(control)
    }

    static let all = [
        Example(query: "stop emails when my CI breaks", page: "u-notifications", control: "Actions"),
        Example(query: "hide my email in commits", page: "u-emails", control: "Keep my email addresses private"),
        Example(query: "who can make repos public in my org", page: "o-member-privileges", control: "change repository visibilities"),
        Example(query: "kick someone off my laptop session", page: "u-sessions", control: "Revoke session"),
        Example(query: "make unsigned commits look suspicious", page: "u-keys", control: "Flag unsigned commits"),
        Example(query: "turn off the annoying g n shortcuts", page: "u-accessibility", control: "Character keys"),
        Example(query: "stop strangers commenting for a week", page: "u-moderation", control: "Enable interaction limits for"),
        Example(query: "require 2FA for everyone", page: "o-auth-security", control: "Require two-factor authentication"),
        Example(query: "delete old workflow artifacts sooner", page: "o-actions-general", control: "Artifact and log retention"),
        Example(query: "let forks run actions", page: "o-actions-general", control: "Run workflows from fork pull requests"),
        Example(query: "dark mode but dimmer", page: "u-appearance", control: "Night theme"),
        Example(query: "passkey", page: "u-security", control: "passkey"),
        Example(query: "rename the org", page: "o-general", control: "Rename organization"),
        Example(query: "where do deploy keys go", page: "o-deploy-keys", control: "deploy keys"),
        Example(query: "Copilot matching public code", page: "u-copilot", control: "matching public code"),
    ]
}

@MainActor
final class PatrolModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var query = ""
    @Published private(set) var result: FunnelResult?
    @Published private(set) var status = "Loading laya (128/512/1024 buckets)…"
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var selected: Match?
    @Published private(set) var loadSeconds: Double?
    @Published var engine: Engine = .laya

    let webView = WKWebView(frame: .zero)
    private let catalogs: [(Catalog, String)] = [Catalog.load("github-user"), Catalog.load("github-org")]
    private var laya: LayaManager?
    private var pageLoaded = false
    private var shownScope = "user"

    override init() {
        super.init()
        webView.navigationDelegate = self
        let url = Bundle.module.url(forResource: "settings", withExtension: "html", subdirectory: "Resources")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        Task { await loadModel() }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            pageLoaded = true
            show(scope: "user", page: nil)
        }
    }

    private func loadModel() async {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let loaded = try await LayaManager.load(configuration: .init(lengths: [128, 512, 1024]))
            // Warm every bucket so first-query timings are honest.
            let long = LayaQuestion.choice("warm up", options: (0..<32).map { "option \($0) with a longer description" })
            _ = try await loaded.answer(state: "warm", question: .noul("warm?"))
            _ = try await loaded.answer(state: String(repeating: "warm ", count: 60), question: long)
            laya = loaded
            let (s, a) = (clock.now - start).components
            loadSeconds = Double(s) + Double(a) / 1e18
            ready = true
            status = "laya ready · type a request or pick an example"
            if ProcessInfo.processInfo.environment["PATROL_AUTORUN"] == "1" {
                let wanted = ProcessInfo.processInfo.environment["PATROL_ENGINE"] ?? "laya"
                let engines = wanted == "all" ? Engine.allCases : Engine.allCases.filter { "\($0)" == wanted }
                var summaries: [String] = []
                for engine in engines {
                    self.engine = engine
                    summaries.append(await autorun())
                }
                print("\n=== comparison ===")
                summaries.forEach { print($0) }
                NSApplication.shared.terminate(nil)
            }
        } catch {
            status = "laya failed to load: \(error.localizedDescription)"
        }
    }

    func search(_ text: String? = nil) async {
        if let text { query = text }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        busy = true
        defer { busy = false }
        status = "Searching with \(engine.rawValue)…"
        do {
            let found: FunnelResult
            switch engine {
            case .laya:
                guard let laya else { status = "laya is still loading"; return }
                found = try await Funnel(laya: laya, catalogs: catalogs.map(\.0)).run(q)
                status = String(format: "%d laya calls · %.1f ms total", found.calls, found.totalMs)
            case .jev:
                found = try await JevEngine(catalogs: catalogs.map(\.0)).run(q)
                status = String(format: "1 Jev request · %.0f ms · %@", found.totalMs, found.note)
            case .claude:
                found = try await ClaudeEngine(catalogs: catalogs.map(\.0)).run(q)
                status = String(format: "1 Claude request · %.0f ms · %@", found.totalMs, found.note)
            }
            result = found
            if let best = found.matches.first { open(best) }
        } catch {
            status = "Search failed: \(error.localizedDescription)"
        }
    }

    /// Shows the match's page with halos on every scored control there and pulses the match.
    func open(_ match: Match) {
        selected = match
        show(scope: match.scope, page: match.page.id)
        let controls = match.page.controls.compactMap { control in
            result?.controlScores[control.id].map { ["id": control.id, "p": $0] as [String: Any] }
        }
        let pages = (result?.pageScores ?? [:]).map { ["id": $0.key, "p": $0.value] as [String: Any] }
        js("Patrol.halos(\(json(controls)), \(json(pages))); Patrol.focus(\(json(match.control.id)))")
    }

    private func show(scope: String, page: String?) {
        guard pageLoaded, let (_, raw) = catalogs.first(where: { $0.0.scope == scope }) else { return }
        if scope != shownScope || page == nil {
            js("Patrol.load(\(raw), \(page.map { json($0) } ?? "null"))")
            shownScope = scope
        } else if let page {
            js("Patrol.show(\(json(page)))")
        }
    }

    private func js(_ script: String) {
        webView.evaluateJavaScript(script + "; true", completionHandler: nil)
    }

    private func json(_ value: Any) -> String {
        let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    }

    // MARK: Autorun

    /// `PATROL_AUTORUN=1`: run every example, print each stage, score against the expected setting, quit.
    private func autorun() async -> String {
        print(String(format: "laya loaded + warmed in %.1f s · head budget %d tokens", loadSeconds ?? 0, laya?.headMaxLength ?? 0))
        var top1 = 0, top3 = 0, page1 = 0
        var totals: [Double] = []
        for example in Example.all {
            result = nil
            await search(example.query)
            guard let result else {
                print("\n▶ \(example.query)\n  ✗ \(status)")
                continue
            }
            print("\n▶ [\(engine.rawValue)] \(example.query)")
            for stage in result.stages {
                let shown = stage.options.sorted { $0.path > $1.path }.prefix(4).map {
                    String(format: "%@%@ %.0f%%", $0.kept ? "" : "·", $0.label.clipped(38), $0.local * 100)
                }
                print(String(format: "  %-13@ %5.1f ms  ", stage.title, stage.totalMs) + shown.joined(separator: " | "))
            }
            for (rank, match) in result.matches.prefix(3).enumerated() {
                print(String(format: "  #%d %5.1f%%  %@ › %@", rank + 1, match.score * 100, match.page.title, match.control.label.clipped(60))
                    + (example.matches(match) ? "  ✓" : ""))
            }
            if let first = result.matches.first, example.matches(first) { top1 += 1 }
            if result.matches.first?.page.id == example.page { page1 += 1 }
            if result.matches.prefix(3).contains(where: example.matches) { top3 += 1 } else {
                print("  ✗ expected \(example.page) › \(example.control)")
            }
            totals.append(result.totalMs)
        }
        let mean = totals.reduce(0, +) / Double(max(totals.count, 1))
        let n = Example.all.count
        return String(format: "%-18@ setting #1: %2d/%d · setting top 3: %2d/%d · page #1: %2d/%d · mean %.0f ms/query", engine.rawValue, top1, n, top3, n, page1, n, mean)
    }
}
