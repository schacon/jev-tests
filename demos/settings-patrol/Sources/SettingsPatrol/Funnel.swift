import FluidUse
import Foundation

/// One option shown in a funnel column.
struct StageOption: Identifiable {
    let id: String
    let label: String
    /// The branch this option was asked under, e.g. "Personal account › Access".
    let parent: String
    /// P(option) within its own question.
    let local: Double
    /// Product of probabilities along the path to this option.
    var path: Double
    var kept = false
    var winner = false
}

struct Stage: Identifiable {
    let title: String
    var options: [StageOption] = []
    var callsMs: [Double] = []
    var id: String { title }
    var totalMs: Double { callsMs.reduce(0, +) }
}

/// A settings control the funnel ended on.
struct Match: Identifiable {
    let scope: String
    let page: Catalog.Page
    let control: Catalog.Control
    let score: Double
    var id: String { control.id }
}

struct FunnelResult {
    var stages: [Stage] = []
    var matches: [Match] = []
    /// Control probabilities per page, for the halos drawn on the page when a match is opened.
    var controlScores: [String: Double] = [:]
    var pageScores: [String: Double] = [:]
    /// Engine-specific footnote (tokens, model version).
    var note = ""
    var totalMs: Double { stages.reduce(0) { $0 + $1.totalMs } }
    var calls: Int { stages.reduce(0) { $0 + $1.callsMs.count } }
}

/// Narrows a request to one setting with laya `choice` questions: which account (a soft prior), then
/// every setting in small heats, then a final among the survivors.
struct Funnel {
    let laya: LayaManager
    let catalogs: [Catalog]

    private static let scopeOptions: [String: LayaQuestion.Choice] = [
        "user": .init(
            "My personal account",
            description: "my own profile, email, password, 2FA, SSH keys, sessions, notifications, appearance, my tokens"),
        "org": .init(
            "An organization I administer",
            description: "organization-wide: members, roles, teams, policies, Actions, runners, org secrets, SSO, audit log"),
    ]

    func run(_ query: String) async throws -> FunnelResult {
        var result = FunnelResult()

        // Stage 1: which account.
        var scopes = Stage(title: "Account")
        let scopeKeys = catalogs.map(\.scope)
        let scopeAnswer = try await ask(
            query, "Which GitHub account's settings does this request change?", scopeKeys.map { Self.scopeOptions[$0]! },
            into: &scopes)
        for (index, key) in scopeKeys.enumerated() {
            let p = scopeAnswer[index]
            scopes.options.append(
                StageOption(id: key, label: Self.scopeOptions[key]!.label, parent: "", local: p, path: p, kept: true))
        }
        result.stages.append(scopes)

        // laya's question and options share a 256-token head, so a 30-option question leaves each option
        // a handful of tokens. Instead every setting competes in small heats, described with its page and
        // section; the best of each heat advance until one final question remains. Going straight to
        // settings avoids a wrong page decision hiding the right setting.
        var heats = Stage(title: "Settings · heats")
        var final = Stage(title: "Settings · final")
        var entries: [SettingEntry] = []
        for (catalog, scopeOption) in zip(catalogs, scopes.options) {
            for page in catalog.groups.flatMap(\.pages) {
                entries += page.controls.filter { $0.type != "info" }.map {
                    SettingEntry(catalog: catalog, page: page, control: $0, scopePath: scopeOption.path)
                }
            }
        }
        let finalists = try await tournament(
            query, entries, instructions: Self.settingInstructions, choice: { Self.settingChoice($0) },
            id: \.control.id, label: \.control.label, parent: \.page.title, into: &heats)
        let probabilities = try await ask(
            query, Self.settingInstructions, uniqued(finalists.map { Self.settingChoice($0) }), into: &final)

        var matches: [Match] = []
        for (index, entry) in finalists.enumerated() {
            // The account answer is a soft prior (square root) so a misjudged account can't bury the answer.
            let score = probabilities[index] * entry.scopePath.squareRoot()
            final.options.append(
                StageOption(
                    id: entry.control.id, label: entry.control.label, parent: entry.page.title,
                    local: probabilities[index], path: score))
            result.controlScores[entry.control.id] = probabilities[index]
            result.pageScores[entry.page.id, default: 0] += score
            matches.append(Match(scope: entry.catalog.scope, page: entry.page, control: entry.control, score: score))
        }
        let total = matches.reduce(0) { $0 + $1.score }
        matches = matches.sorted { $0.score > $1.score }.map {
            Match(scope: $0.scope, page: $0.page, control: $0.control, score: total > 0 ? $0.score / total : 0)
        }
        result.matches = Array(matches.prefix(5))
        keepTop(&final, count: 1)

        // Where the finalists live: their scores summed per page.
        var pages = Stage(title: "Pages")
        let pageTotal = result.pageScores.values.reduce(0, +)
        for (id, score) in result.pageScores {
            let (catalog, page) = find(page: id)
            let share = pageTotal > 0 ? score / pageTotal : 0
            pages.options.append(
                StageOption(
                    id: id, label: page.title, parent: catalog.scope == "org" ? "Organization" : "Personal",
                    local: share, path: share))
        }
        keepTop(&pages, count: 1)
        result.stages += [heats, final, pages]
        markWinner(&result)
        return result
    }

    struct SettingEntry {
        let catalog: Catalog
        let page: Catalog.Page
        let control: Catalog.Control
        let scopePath: Double
    }

    /// Runs heats of `heatSize` until at most `heatSize` items remain; each heat's top `advance` go on.
    /// Every heat option is recorded in `stage`, with eliminated ones marked not kept.
    private func tournament<Item>(
        _ query: String, _ items: [Item], instructions: String, choice: (Item) -> LayaQuestion.Choice,
        id: KeyPath<Item, String>, label: KeyPath<Item, String>, parent: KeyPath<Item, String>, into stage: inout Stage
    ) async throws -> [Item] {
        var field = items
        var round = 1
        while field.count > Self.heatSize {
            let heatCount = (field.count + Self.heatSize - 1) / Self.heatSize
            let size = (field.count + heatCount - 1) / heatCount
            var next: [Item] = []
            for start in stride(from: 0, to: field.count, by: size) {
                let heat = Array(field[start..<min(start + size, field.count)])
                let probabilities = try await ask(query, instructions, uniqued(heat.map(choice)), into: &stage)
                let ranked = heat.indices.sorted { probabilities[$0] > probabilities[$1] }
                for (rank, index) in ranked.enumerated() {
                    let advances = rank < Self.advance
                    stage.options.append(
                        StageOption(
                            id: "heat\(round)-" + heat[index][keyPath: id], label: heat[index][keyPath: label],
                            parent: "\(heat[index][keyPath: parent]) · round \(round)",
                            local: probabilities[index], path: probabilities[index], kept: advances))
                    if advances { next.append(heat[index]) }
                }
            }
            field = next
            round += 1
        }
        return field
    }

    /// laya keys choices by label; repeated labels ("Delete", "Revoke all") get a numbered suffix.
    private func uniqued(_ choices: [LayaQuestion.Choice]) -> [LayaQuestion.Choice] {
        var seen: [String: Int] = [:]
        return choices.map { choice in
            let count = seen[choice.label, default: 0]
            seen[choice.label] = count + 1
            return count == 0 ? choice : LayaQuestion.Choice("\(choice.label) (\(count + 1))", description: choice.description)
        }
    }

    // MARK: Helpers

    static let heatSize = 7
    static let advance = 2
    static let settingInstructions = "Which GitHub setting does what the user asked?"

    /// A page as an option: its title plus a sentence on what it is for.
    static func settingChoice(_ entry: SettingEntry) -> LayaQuestion.Choice {
        let description = entry.control.description.isEmpty ? entry.control.section : entry.control.description
        let place = entry.catalog.scope == "org" ? "Organization settings" : "Personal settings"
        return LayaQuestion.Choice(
            controlLabel(entry.control), description: "\(place) › \(entry.page.title): \(description)".clipped(110))
    }

    /// Short labels like "Disable all" or "Restore" say nothing on their own; lead with their section.
    static func controlLabel(_ control: Catalog.Control) -> String {
        let words = control.label.split(separator: " ").count
        return (words <= 2 && control.section != control.label ? "\(control.section): \(control.label)" : control.label)
            .clipped(80)
    }

    private func ask(
        _ query: String, _ instructions: String, _ options: [LayaQuestion.Choice], into stage: inout Stage
    ) async throws -> [Double] {
        let question = LayaQuestion.choice(instructions, options: options)
        let laya = laya
        let (answer, ms) = try await Task.detached(priority: .userInitiated) {
            let clock = ContinuousClock()
            let start = clock.now
            let answer = try await laya.answer(state: "User request: \(query)", question: question)
            let (s, a) = (clock.now - start).components
            return (answer, Double(s) * 1000 + Double(a) / 1e15)
        }.value
        stage.callsMs.append(ms)
        return answer.probabilities.prefix(options.count).map(Double.init)
    }

    private func keepTop(_ stage: inout Stage, count: Int? = nil) {
        let limit = count ?? 1
        let ranked = stage.options.indices.sorted { stage.options[$0].path > stage.options[$1].path }
        for index in ranked.prefix(limit) { stage.options[index].kept = true }
    }

    private func markWinner(_ result: inout FunnelResult) {
        guard let best = result.matches.first else { return }
        let winners: Set<String> = [best.scope, best.page.id, best.control.id]
        for s in result.stages.indices {
            for o in result.stages[s].options.indices {
                let id = result.stages[s].options[o].id
                let bare = id.hasPrefix("heat") ? String(id.drop { $0 != "-" }.dropFirst()) : id
                guard winners.contains(bare) else { continue }
                result.stages[s].options[o].winner = true
            }
        }
    }

    private func find(page id: String) -> (Catalog, Catalog.Page) {
        for catalog in catalogs {
            for group in catalog.groups { if let page = group.pages.first(where: { $0.id == id }) { return (catalog, page) } }
        }
        fatalError("unknown page \(id)")
    }
}
