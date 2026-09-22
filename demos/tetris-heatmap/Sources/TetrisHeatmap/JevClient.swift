import Foundation

/// Minimal client for the System One HTTP API (https://docs.typesafe.ai/api): one request per piece,
/// one Noul question per landing, all answered in parallel server-side. The same wire format is
/// served by TypeSafe's hosted Jev and by a local Kev server (github.com/jaredpalmer/kev).
struct JevClient: Sendable {
    let endpoint: URL
    let model: String
    /// Nil for a local Kev server, which has no authentication.
    let apiKey: String?

    static func jev(apiKey: String) -> JevClient {
        JevClient(endpoint: URL(string: "https://api.typesafe.ai/v1/systemone")!, model: "jev-latest", apiKey: apiKey)
    }

    /// `KEV_URL` overrides the default `http://127.0.0.1:8009` from `scripts/kev-server.sh`.
    static let kevBase = URL(string: ProcessInfo.processInfo.environment["KEV_URL"] ?? "http://127.0.0.1:8009")!
    static var kev: JevClient {
        JevClient(endpoint: kevBase.appendingPathComponent("v1/systemone"), model: "kev-latest", apiKey: nil)
    }

    /// Whether a Kev server answers `GET /v1/models`, and what it has loaded.
    static func kevStatus() async -> String? {
        var request = URLRequest(url: kevBase.appendingPathComponent("v1/models"))
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        if let range = text.range(of: #""(run|checkpoint|id)"\s*:\s*"[^"]+""#, options: .regularExpression) {
            return String(text[range]).components(separatedBy: "\"").dropLast().last
        }
        return "kev"
    }

    struct Result: Sendable {
        /// P(clean) per landing, in the order the sentences were given.
        let probabilities: [Double]
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        /// Exact bytes sent and received, for the call inspector. The API key is only in the
        /// Authorization header, never in the body.
        let requestBody: Data
        let responseBody: Data
        let httpStatus: Int
        let attempts: Int
    }

    enum Failure: Error, LocalizedError {
        case http(Int, String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .http(401, _): return "Rejected the API key (401)"
            case .http(let code, let body): return "HTTP \(code): \(body.prefix(160))"
            case .malformed(let detail): return "Unexpected Jev response: \(detail)"
            }
        }
    }

    /// Asks "is this a clean placement?" about every landing in one request. The state carries
    /// all landings so each judgment can be made in the context of the alternatives.
    func scoreLandings(piece: String, sentences: [String]) async throws -> Result {
        var questions: [String: Any] = [:]
        for index in sentences.indices {
            questions["landing_\(index)"] = [
                "type": "noul",
                "instructions": "Is `landings[\(index)]` a clean placement for the \(piece) piece in Tetris?",
                "criteria": [
                    "true": "Clean: leaves no holes, keeps the surface flat and the stack low, or clears lines.",
                    "false": "Messy: creates holes, makes the surface bumpier, builds the stack up, or leaves a deep well.",
                ],
            ]
        }
        let body: [String: Any] = [
            "model": model,
            "state": ["piece": piece, "landings": sentences],
            "questions": questions,
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // A local Kev on Apple Silicon can take several seconds for a full piece.
        request.timeoutInterval = 120

        // 429 / 529 are retryable per the docs; back off exponentially.
        var delay = Duration.milliseconds(400)
        for attempt in 0..<4 {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (status == 429 || status == 529), attempt < 3 {
                try await Task.sleep(for: delay)
                delay *= 2
                continue
            }
            guard status == 200 else {
                throw Failure.http(status, String(data: data, encoding: .utf8) ?? "")
            }
            return try decode(
                data, count: sentences.count, request: request.httpBody ?? Data(), status: status, attempts: attempt + 1)
        }
        throw Failure.http(429, "rate limited")
    }

    private func decode(_ data: Data, count: Int, request: Data, status: Int, attempts: Int) throws -> Result {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let answers = object["answers"] as? [String: Any]
        else { throw Failure.malformed("no answers") }
        let probabilities = try (0..<count).map { index -> Double in
            guard let answer = answers["landing_\(index)"] as? [String: Any],
                let noul = (answer["noul"] as? NSNumber)?.doubleValue
            else { throw Failure.malformed("missing landing_\(index)") }
            return noul
        }
        let usage = object["usage"] as? [String: Any]
        return Result(
            probabilities: probabilities, model: object["model"] as? String ?? model,
            inputTokens: (usage?["input_tokens"] as? NSNumber)?.intValue ?? 0,
            outputTokens: (usage?["output_tokens"] as? NSNumber)?.intValue ?? 0,
            requestBody: request, responseBody: data, httpStatus: status, attempts: attempts)
    }
}

enum JevKey {
    /// `JEV_API_KEY` from the process environment, else from the nearest `.env` walking up from
    /// the working directory (the repo root's `.env` when run with `swift run`), else `TYPESAFE_API_KEY`.
    static func resolve() -> String {
        let environment = ProcessInfo.processInfo.environment
        if let key = environment["JEV_API_KEY"], !key.isEmpty { return key }
        if let key = dotenv()["JEV_API_KEY"], !key.isEmpty { return key }
        return environment["TYPESAFE_API_KEY"] ?? ""
    }

    private static func dotenv() -> [String: String] {
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while true {
            let file = directory.appendingPathComponent(".env")
            if let text = try? String(contentsOf: file, encoding: .utf8) { return parse(text) }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { return [:] }
            directory = parent
        }
    }

    /// `KEY=value` lines; ignores comments and blank lines, strips `export ` and surrounding quotes.
    static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") { line.removeFirst(7) }
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = line[..<split].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: split)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }
        return values
    }
}
