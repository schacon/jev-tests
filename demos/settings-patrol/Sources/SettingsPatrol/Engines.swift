import Foundation

/// Which model narrows the request down.
enum Engine: String, CaseIterable, Identifiable {
    case laya = "laya (on-device)"
    case jev = "Jev API"
    case claude = "Claude"
    var id: String { rawValue }
}

/// One setting as a flat catalog row, shared by the API engines.
struct SettingRow {
    let scope: String
    let page: Catalog.Page
    let control: Catalog.Control

    var place: String { scope == "org" ? "Organization settings" : "Personal settings" }
    /// Human-readable, unique-enough label: "Notifications › Actions".
    var title: String { "\(page.title) › \(control.label)" }
    var detail: String {
        let description = control.description.isEmpty ? "" : " — \(control.description)"
        return "\(control.section)\(description)"
    }

    static func all(_ catalogs: [Catalog]) -> [SettingRow] {
        catalogs.flatMap { catalog in
            catalog.groups.flatMap(\.pages).flatMap { page in
                page.controls.filter { $0.type != "info" }.map { SettingRow(scope: catalog.scope, page: page, control: $0) }
            }
        }
    }
}

enum Keys {
    /// Environment first, then the nearest `.env` walking up from the working directory.
    static func value(_ name: String) -> String {
        if let value = ProcessInfo.processInfo.environment[name], !value.isEmpty { return value }
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while true {
            if let text = try? String(contentsOf: directory.appendingPathComponent(".env"), encoding: .utf8) {
                for raw in text.components(separatedBy: .newlines) {
                    var line = raw.trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("export ") { line.removeFirst(7) }
                    guard !line.hasPrefix("#"), let split = line.firstIndex(of: "="),
                        line[..<split].trimmingCharacters(in: .whitespaces) == name
                    else { continue }
                    return line[line.index(after: split)...].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                }
                return ""
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { return "" }
            directory = parent
        }
    }
}

private func post(_ url: URL, headers: [String: String], body: [String: Any]) async throws -> ([String: Any], Double) {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    var delay = Duration.milliseconds(500)
    for attempt in 0..<4 {
        let clock = ContinuousClock()
        let start = clock.now
        let (data, response) = try await URLSession.shared.data(for: request)
        let (s, a) = (clock.now - start).components
        let ms = Double(s) * 1000 + Double(a) / 1e15
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if [429, 529, 503].contains(status), attempt < 3 {
            try await Task.sleep(for: delay)
            delay *= 2
            continue
        }
        guard status == 200, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EngineError.http(status, String(decoding: data.prefix(300), as: UTF8.self))
        }
        return (object, ms)
    }
    throw EngineError.http(429, "rate limited")
}

enum EngineError: Error, LocalizedError {
    case missingKey(String)
    case http(Int, String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let name): return "Set \(name) in the environment or .env"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .malformed(let detail): return "Unexpected response: \(detail)"
        }
    }
}

/// Collapses scored rows into the shared result shape the funnel view draws.
private func finish(_ scored: [(SettingRow, Double)], into result: inout FunnelResult) {
    let total = scored.reduce(0) { $0 + $1.1 }
    let ranked = scored.sorted { $0.1 > $1.1 }
    result.matches = ranked.prefix(5).map {
        Match(scope: $0.0.scope, page: $0.0.page, control: $0.0.control, score: total > 0 ? $0.1 / total : 0)
    }
    for (row, score) in scored {
        result.controlScores[row.control.id] = score
        result.pageScores[row.page.id, default: 0] += score
    }
}

// MARK: Jev

/// One request, three Choice questions answered in parallel: which account, which personal setting
/// (all ~220 as options), which org setting (all ~240). Final score = P(account) × P(setting | account).
/// Jev takes up to 255 options per Choice, so no heats or shortlists are needed.
struct JevEngine {
    let catalogs: [Catalog]
    static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!

    func run(_ query: String) async throws -> FunnelResult {
        let key = Keys.value("JEV_API_KEY")
        guard !key.isEmpty else { throw EngineError.missingKey("JEV_API_KEY") }
        let rows = SettingRow.all(catalogs)
        var labelToRow: [String: [String: SettingRow]] = [:]
        var questions: [String: Any] = [
            "account": [
                "type": "choice",
                "instructions": "Whose GitHub settings would the user change to do `request`?",
                "criteria": [
                    "personal": "The user's own personal account: their profile, emails, password, 2FA, SSH/GPG keys, sessions, notifications, appearance, accessibility, their own tokens and apps.",
                    "organization": "An organization the user administers: members, roles, member privileges, teams, org-wide policies, Actions and runners, org secrets, SSO, audit log, billing for the org.",
                ],
            ]
        ]
        for scope in ["user", "org"] {
            var criteria: [String: String] = [:]
            var map: [String: SettingRow] = [:]
            for row in rows where row.scope == scope {
                var label = row.title
                var n = 2
                while map[label] != nil {
                    label = "\(row.title) (\(n))"
                    n += 1
                }
                map[label] = row
                criteria[label] = row.detail.clipped(220)
            }
            labelToRow[scope] = map
            questions["\(scope)_setting"] = [
                "type": "choice",
                "instructions": scope == "user"
                    ? "If this is about the user's personal GitHub account, which setting does `request`?"
                    : "If this is about a GitHub organization, which organization setting does `request`?",
                "criteria": criteria,
            ]
        }
        let (response, ms) = try await post(
            Self.endpoint, headers: ["Authorization": "Bearer \(key)"],
            body: ["model": "jev-latest", "state": ["request": query], "questions": questions])
        guard let answers = response["answers"] as? [String: Any] else { throw EngineError.malformed("no answers") }
        func probabilities(_ id: String) -> [String: Double] {
            let answer = answers[id] as? [String: Any]
            let map = answer?["probabilities"] as? [String: Any] ?? [:]
            return map.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        }

        var result = FunnelResult()
        let account = probabilities("account")
        let pUser = account["personal"] ?? 0.5
        let pOrg = account["organization"] ?? 0.5
        var accountStage = Stage(title: "Account", callsMs: [ms])
        accountStage.options = [
            StageOption(id: "user", label: "Personal account", parent: "", local: pUser, path: pUser, kept: true),
            StageOption(id: "org", label: "Organization", parent: "", local: pOrg, path: pOrg, kept: true),
        ]
        result.stages.append(accountStage)

        var scored: [(SettingRow, Double)] = []
        for (scope, prior, title) in [("user", pUser, "Personal settings"), ("org", pOrg, "Org settings")] {
            var stage = Stage(title: "\(title) · \(labelToRow[scope]?.count ?? 0) options")
            let probs = probabilities("\(scope)_setting")
            for (label, p) in probs.sorted(by: { $0.value > $1.value }).prefix(12) {
                guard let row = labelToRow[scope]?[label] else { continue }
                stage.options.append(
                    StageOption(id: row.control.id, label: row.control.label, parent: row.page.title, local: p, path: p * prior, kept: true))
            }
            for (label, p) in probs { if let row = labelToRow[scope]?[label] { scored.append((row, p * prior)) } }
            result.stages.append(stage)
        }
        finish(scored, into: &result)
        var final = Stage(title: "Combined")
        final.options = result.matches.map {
            StageOption(id: $0.control.id, label: $0.control.label, parent: $0.page.title, local: $0.score, path: $0.score, kept: true)
        }
        result.stages.append(final)
        if let usage = response["usage"] as? [String: Any] {
            result.note = "\((usage["input_tokens"] as? NSNumber)?.intValue ?? 0) input tokens · \(response["model"] as? String ?? "jev")"
        }
        return result
    }
}

// MARK: Claude

/// Claude reads the whole settings catalog (cached system prompt) and returns its top five setting
/// ids with a confidence and a one-line reason, via structured outputs.
struct ClaudeEngine {
    let catalogs: [Catalog]
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model = "claude-opus-5"

    func run(_ query: String) async throws -> FunnelResult {
        let key = Keys.value("ANTHROPIC_API_KEY")
        guard !key.isEmpty else { throw EngineError.missingKey("ANTHROPIC_API_KEY") }
        let rows = SettingRow.all(catalogs)
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.control.id, $0) })
        // Stable, deterministic catalog so the cached prefix is byte-identical across queries.
        let catalogText = rows.map { "\($0.control.id) | \($0.place) › \($0.title) | \($0.detail.clipped(220))" }
            .joined(separator: "\n")
        let system = """
            You map a user's request to the GitHub settings control that does it. The catalog below lists \
            every control as `id | account › page › control | section — help text`. Pick up to five \
            controls, best first. Confidence is your probability that each is the one the user needs; \
            they may sum to less than 1. Use only ids from the catalog.

            CATALOG
            \(catalogText)
            """
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "matches": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string"],
                            "confidence": ["type": "number"],
                            "reason": ["type": "string"],
                        ],
                        "required": ["id", "confidence", "reason"],
                        "additionalProperties": false,
                    ],
                ]
            ],
            "required": ["matches"],
            "additionalProperties": false,
        ]
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 2048,
            "fallbacks": "default",
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
            "messages": [["role": "user", "content": "Request: \(query)"]],
        ]
        let (response, ms) = try await post(
            Self.endpoint,
            headers: [
                "x-api-key": key, "anthropic-version": "2023-06-01",
                "anthropic-beta": "server-side-fallback-2026-07-01",
            ],
            body: body)
        if (response["stop_reason"] as? String) == "refusal" { throw EngineError.malformed("refused") }
        let text = (response["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
        guard let data = text.data(using: .utf8),
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let matches = parsed["matches"] as? [[String: Any]]
        else { throw EngineError.malformed(text.clipped(200)) }

        var result = FunnelResult()
        var stage = Stage(title: "Claude · \(rows.count) settings in context", callsMs: [ms])
        var scored: [(SettingRow, Double)] = []
        for match in matches {
            guard let id = match["id"] as? String, let row = byId[id] else { continue }
            let confidence = (match["confidence"] as? NSNumber)?.doubleValue ?? 0
            let reason = match["reason"] as? String ?? ""
            scored.append((row, confidence))
            stage.options.append(
                StageOption(
                    id: id, label: row.control.label, parent: "\(row.page.title) — \(reason)", local: confidence,
                    path: confidence, kept: true))
        }
        result.stages.append(stage)
        finish(scored, into: &result)
        if let usage = response["usage"] as? [String: Any] {
            let int = { (key: String) in (usage[key] as? NSNumber)?.intValue ?? 0 }
            result.note = "\(int("input_tokens")) in (\(int("cache_read_input_tokens")) cached) / \(int("output_tokens")) out · \(response["model"] as? String ?? Self.model)"
        }
        return result
    }
}
