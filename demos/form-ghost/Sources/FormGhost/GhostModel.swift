import FluidAudio
import FluidUse
import AppKit
import Foundation
import SwiftUI
import WebKit

/// A bundled sample form and the profile the ghost fills it from.
struct SampleForm: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String

    var htmlURL: URL { Self.directory.appendingPathComponent("\(id).html") }
    var profileURL: URL { Self.directory.appendingPathComponent("\(id).txt") }

    static let directory = Bundle.module.url(forResource: "forms", withExtension: nil, subdirectory: "Resources")!
    static let all = [
        SampleForm(id: "checkout", name: "Checkout · billing", symbol: "cart"),
        SampleForm(id: "passport", name: "Passport renewal", symbol: "building.columns"),
        SampleForm(id: "tax", name: "W-4 withholding", symbol: "doc.text"),
        SampleForm(id: "clinic", name: "Clinic intake", symbol: "cross.case"),
    ]
}

/// One scored control: what the model would do and how sure it is.
struct Ghost: Identifiable {
    let element: FormElement
    let action: FormAction
    let entity: Entity?
    let confidence: Float
    let runnerUp: String
    let latency: Duration
    /// How many profile values the model was offered for this control.
    var offered = 0
    var status: Status = .planned

    enum Status: String { case planned, applied, skipped, failed }

    var id: String { element.token }
    var label: String { element.label.isEmpty ? element.role : element.label }
    var summary: String {
        switch action {
        case .fill, .answer: return entity?.value ?? ""
        case .check: return "☑︎ check"
        case .click: return "click"
        default: return "skip"
        }
    }
    var isApplicable: Bool { action == .fill || action == .check || action == .answer }
    var latencyMs: Double { latency.milliseconds }
}

struct RunStats {
    var modelLoad: Duration?
    var snapshot: Duration = .zero
    var scoringWall: Duration = .zero
    var fillWall: Duration?
    var latencies: [Double] = []

    var count: Int { latencies.count }
    var total: Double { latencies.reduce(0, +) }
    var mean: Double { count == 0 ? 0 : total / Double(count) }
    var minimum: Double { latencies.min() ?? 0 }
    var maximum: Double { latencies.max() ?? 0 }
    func percentile(_ p: Double) -> Double {
        guard count > 0 else { return 0 }
        let sorted = latencies.sorted()
        return sorted[min(count - 1, Int((Double(count - 1) * p).rounded()))]
    }
    var decisionsPerSecond: Double { total == 0 ? 0 : Double(count) / (total / 1000) }
}

extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000 + Double(attoseconds) / 1e15
    }
}

@MainActor
final class GhostModel: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var selected: SampleForm = SampleForm.all[0]
    @Published var entities: [Entity] = []
    @Published var ghosts: [Ghost] = []
    @Published var stats = RunStats()
    @Published var status = "Loading model…"
    @Published var busy = false
    @Published var modelReady = false
    @Published var threshold = 0.5
    /// Slows the scan so the overlay can be watched; excluded from model timings.
    @Published var paceMilliseconds = 60.0
    @Published var source: Source = .database
    /// Withhold database records that share no meaningful words with the field.
    @Published var relevantOnly = true
    /// Host rule: when the model skips a field whose label is exactly a database caption, fill it anyway.
    @Published var exactMatchRule = true
    @Published private(set) var database: PersonalDatabase?
    @Published private(set) var databaseNote = ""

    enum Source: String, CaseIterable, Identifiable {
        case database = "My database"
        case sample = "Sample profile"
        var id: String { rawValue }
    }

    let driver = WebFormDriver()
    private var manager: CuaS1FormsManager?
    private var modelLoad: Duration?
    private var overlayInstalled = false
    private static let overlay: String = {
        let url = Bundle.module.url(forResource: "ghost", withExtension: "js", subdirectory: "Resources")!
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    override init() {
        super.init()
        driver.webView.configuration.userContentController.add(self, name: "ghost")
        driver.onNavigation = { [weak self] in self?.overlayInstalled = false }
        if let env = ProcessInfo.processInfo.environment["FORM_GHOST_SOURCE"], env == "sample" { source = .sample }
        reloadDatabase()
        load(selected)
        Task { await loadModel() }
    }

    private func loadModel() async {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            manager = try await CuaS1FormsManager.load(computeUnits: .cpuAndNeuralEngine)
            modelLoad = clock.now - start
            stats.modelLoad = modelLoad
            modelReady = true
            status = "Model ready · press Run ghost"
            if ProcessInfo.processInfo.environment["FORM_GHOST_AUTORUN"] == "1" { await autorun() }
        } catch {
            status = "Model failed to load: \(error.localizedDescription)"
        }
    }

    /// `FORM_GHOST_AUTORUN=1`: scan and fill every sample form, print stats, quit (smoke test).
    private func autorun() async {
        print("source: \(source.rawValue)")
        for form in SampleForm.all {
            load(form)
            try? await Task.sleep(for: .seconds(1.5))
            paceMilliseconds = 0
            await runGhost(); print("scan: \(status)")
            await fillAll()
            let s = stats
            let actions = Dictionary(grouping: ghosts, by: \.action.rawValue).mapValues(\.count)
            print(
                String(format: "%@: %d controls, mean %.2f ms, p95 %.2f ms, applied %d, ", form.id, s.count, s.mean,
                    s.percentile(0.95), ghosts.filter { $0.status == .applied }.count) + "\(actions) · \(status)")
            for ghost in ghosts {
                print(String(format: "  %-45@ %-6@ %5.1f%% %@", ghost.label, ghost.action.rawValue, ghost.confidence * 100, ghost.summary) + (ghost.entity.map { "  [as \($0.label), \(ghost.offered) offered]" } ?? ""))
            }
        }
        NSApplication.shared.terminate(nil)
    }

    func reloadDatabase() {
        do {
            let (loaded, seeded) = try PersonalDatabase.load()
            database = loaded
            databaseNote =
                seeded
                ? "Created from the example; edit it with your details."
                : "\(loaded.records.count) records"
        } catch {
            database = nil
            databaseNote = "Could not read: \(error.localizedDescription)"
        }
    }

    func revealDatabase() {
        NSWorkspace.shared.open(PersonalDatabase.url)
    }

    /// The options offered for one control: the sample profile as-is, or the database records that
    /// fit this field, each captioned the way this field is.
    private func candidates(for element: FormElement) -> [Entity] {
        let limit = CuaS1FormsManager.maximumOptions - FormSchema.fixedActions.count
        guard source == .database, let database else { return entities }
        return database.matches(for: element, limit: limit, relevantOnly: relevantOnly).map(\.entity)
    }

    /// A database record whose caption is exactly the field's label once parenthesized hints like
    /// "(optional)", "(a)", or "(mm/dd/yyyy)" are dropped. Only text fields; never buttons or checkboxes.
    private func exactMatch(for element: FormElement) -> Entity? {
        guard exactMatchRule, source == .database, let database, ["Edit", "ComboBox"].contains(element.role)
        else { return nil }
        let bare = { (text: String) in
            PersonalDatabase.words(text.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression))
        }
        let field = bare(element.label)
        guard !field.isEmpty else { return nil }
        let limit = CuaS1FormsManager.maximumOptions - FormSchema.fixedActions.count
        return database.matches(for: element, limit: limit, relevantOnly: true)
            .first { bare($0.caption) == field }?.entity
    }

    func load(_ form: SampleForm) {
        selected = form
        ghosts = []
        stats = RunStats(modelLoad: modelLoad)
        driver.load(form.htmlURL)
        do {
            let parsed = try DocumentEntities.extract(from: form.profileURL)
            entities = Array(parsed.prefix(CuaS1FormsManager.maximumOptions - FormSchema.fixedActions.count))
        } catch {
            entities = []
            status = "Profile failed: \(error.localizedDescription)"
        }
    }

    func reset() {
        ghosts = []
        stats = RunStats(modelLoad: modelLoad)
        Task { try? await js("window.__ghost && window.__ghost.reset()") }
    }

    // MARK: Scan

    func runGhost() async {
        guard let manager, !busy else { return }
        busy = true
        defer { busy = false }
        ghosts = []
        stats = RunStats(modelLoad: modelLoad)
        do {
            try await installOverlay()
            try await js("window.__ghost.clear()")
            let clock = ContinuousClock()
            var start = clock.now
            let page = try await driver.snapshot()
            stats.snapshot = clock.now - start

            let title = FormSchema.normalizeTitle(page.title)
            let controls = page.elements.filter(\.isActionable)
            status = "Scoring \(controls.count) controls…"
            start = clock.now
            var paused: Duration = .zero
            for element in controls {
                try Task.checkCancellation()
                try await js("window.__ghost.scanning(\(quoted(element.token)))")
                let context = FormSchema.renderContext(formTitle: title, element: element.forScoring)
                let offered = candidates(for: element)
                let options = FormSchema.renderOptions(entities: offered)
                // Timed off the main actor so SwiftUI work does not inflate the number.
                let (result, latency) = try await Task.detached(priority: .userInitiated) {
                    let clock = ContinuousClock()
                    let start = clock.now
                    let result = try await manager.score(context: context, options: options)
                    return (result, clock.now - start)
                }.value
                let (action, entityIndex) = FormSchema.decode(
                    optionIndex: result.selectedIndex, entityCount: offered.count)
                let ranked = result.probabilities.enumerated().sorted { $0.element > $1.element }
                let second = ranked.dropFirst().first.map { options[$0.offset] } ?? ""
                var ghost = Ghost(
                    element: element, action: action, entity: entityIndex.map { offered[$0] },
                    confidence: result.probabilities[result.selectedIndex], runnerUp: second, latency: latency,
                    offered: offered.count)
                if action == .skip, let exact = exactMatch(for: element) {
                    // Keep the model's timing; the rule's own certainty is shown as 100%.
                    ghost = Ghost(
                        element: element, action: .answer, entity: exact, confidence: 1, runnerUp: "model: skip",
                        latency: latency, offered: offered.count)
                }
                ghosts.append(ghost)
                stats.latencies.append(ghost.latencyMs)
                try await render(ghost)
                if paceMilliseconds > 0 {
                    let pauseStart = clock.now
                    try await Task.sleep(for: .milliseconds(paceMilliseconds))
                    paused += clock.now - pauseStart
                }
            }
            stats.scoringWall = clock.now - start - paused
            status = String(
                format: "Scored %d controls · %.2f ms mean per decision", stats.count, stats.mean)
        } catch is CancellationError {
            status = "Cancelled"
        } catch {
            status = "Scan failed: \(error.localizedDescription)"
        }
    }

    // MARK: Apply

    func fillAll() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let clock = ContinuousClock()
        let start = clock.now
        for index in ghosts.indices where ghosts[index].status == .planned {
            await apply(index)
        }
        stats.fillWall = clock.now - start
        let applied = ghosts.filter { $0.status == .applied }.count
        status = "Applied \(applied) ghosts in \(Self.format(stats.fillWall!))"
    }

    func apply(token: String) async {
        guard let index = ghosts.firstIndex(where: { $0.id == token }) else { return }
        await apply(index)
    }

    private func apply(_ index: Int) async {
        let ghost = ghosts[index]
        guard ghost.isApplicable, ghost.status == .planned else { return }
        guard Double(ghost.confidence) >= threshold else {
            ghosts[index].status = .skipped
            return
        }
        let element = ghost.element
        do {
            switch (ghost.action, element.role) {
            case (.fill, "ComboBox"), (.answer, "ComboBox"):
                try await driver.select(ghost.entity?.value ?? "", in: element.token)
            case (.check, "ComboBox"):
                try await driver.selectAffirmative(in: element.token)
            case (.fill, _), (.answer, _):
                let value = ghost.entity?.value ?? ""
                try await driver.type(value, into: element.token, characterDelay: .milliseconds(12))
            case (.check, _):
                if try await driver.isChecked(element.token) != true { try await driver.click(element.token) }
            default:
                return
            }
            ghosts[index].status = .applied
            try await js("window.__ghost.done(\(quoted(element.token)))")
        } catch {
            ghosts[index].status = .failed
        }
    }

    nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let token = message.body as? String else { return }
        Task { @MainActor in await self.apply(token: token) }
    }

    // MARK: Overlay

    private func render(_ ghost: Ghost) async throws {
        let tag = "\(ghost.action.rawValue) \(Int(ghost.confidence * 100))% · \(String(format: "%.1f", ghost.latencyMs))ms"
        let isCheckbox = ghost.element.role == "CheckBox"
        try await js(
            "window.__ghost.show(\(quoted(ghost.element.token)), \(quoted(ghost.summary)), \(quoted(tag)), "
                + "\(quoted(Self.cssColor(ghost))), \(isCheckbox))")
    }

    private func installOverlay() async throws {
        guard !overlayInstalled else { return }
        // Belt and braces: install the driver's page library if its user script has not run yet.
        try await js("if (!window.__cua) {" + WebFormDriver.library + "}; true")
        try await js(Self.overlay + ";true")
        overlayInstalled = true
    }

    /// Runs overlay script; results are ignored, so use the completion variant that tolerates `undefined`.
    private func js(_ script: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            driver.webView.evaluateJavaScript(script) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func quoted(_ string: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: string, options: .fragmentsAllowed)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    // MARK: Presentation

    static func tier(_ ghost: Ghost) -> (css: String, color: Color) {
        if ghost.action == .skip || ghost.action == .click { return ("#8e8e93", .gray) }
        if ghost.action == .answer { return ("#2f6fed", .blue) }
        if ghost.confidence >= 0.85 { return ("#1f9d55", .green) }
        if ghost.confidence >= 0.5 { return ("#e08a00", .orange) }
        return ("#d93025", .red)
    }
    static func cssColor(_ ghost: Ghost) -> String { tier(ghost).css }

    static func format(_ duration: Duration) -> String {
        let ms = duration.milliseconds
        return ms >= 1000 ? String(format: "%.2f s", ms / 1000) : String(format: "%.1f ms", ms)
    }
}
