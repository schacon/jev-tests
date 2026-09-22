import AppKit
import FluidUse
import Foundation
import SwiftUI

/// One legal landing of the current piece and what the policy thought of it.
struct ScoredLanding: Identifiable {
    let candidate: TetrisGame.Candidate
    let sentence: String
    /// P(clean) from laya, or nil while it has not been scored yet.
    var probability: Double?
    var latencyMs: Double?

    var id: Int { candidate.id }
    var rotation: Int { candidate.rotation }
    var column: Int { candidate.column }
    var heuristic: Double { candidate.features.heuristic }
}

struct GameStats {
    var modelLoad: Double?
    var pieces = 0
    var decisions = 0
    var latencies: [Double] = []
    var heuristicAgreements = 0
    var holesCreated = 0
    var perPieceWall: [Double] = []
    /// Jev: one HTTPS round trip per piece.
    var jevRequests: [Double] = []
    var jevTokens = 0
    var jevInputTokens = 0

    /// jev-1.13.0 list price: $0.042 per million input tokens; output is free (docs.typesafe.ai/models).
    static let jevDollarsPerInputToken = 0.042 / 1_000_000
    var jevCost: Double { Double(jevInputTokens) * Self.jevDollarsPerInputToken }
    var jevCostPerPiece: Double { jevRequests.isEmpty ? 0 : jevCost / Double(jevRequests.count) }
    var jevModel = ""

    var jevMean: Double { jevRequests.isEmpty ? 0 : jevRequests.reduce(0, +) / Double(jevRequests.count) }
    func jevPercentile(_ p: Double) -> Double {
        guard !jevRequests.isEmpty else { return 0 }
        let sorted = jevRequests.sorted()
        return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
    }

    var mean: Double { latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count) }
    func percentile(_ p: Double) -> Double {
        guard !latencies.isEmpty else { return 0 }
        let sorted = latencies.sorted()
        return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
    }
    var decisionsPerSecond: Double { mean == 0 ? 0 : 1000 / mean }
    var agreement: Double { pieces == 0 ? 0 : Double(heuristicAgreements) / Double(pieces) }
    /// Scoring time spread over every landing judged; same formula for laya and Jev.
    var msPerDecision: Double { decisions == 0 ? 0 : perPieceWall.reduce(0, +) / Double(decisions) }
    func piecePercentile(_ p: Double) -> Double {
        guard !perPieceWall.isEmpty else { return 0 }
        let sorted = perPieceWall.sorted()
        return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
    }
    var meanPieceWall: Double { perPieceWall.isEmpty ? 0 : perPieceWall.reduce(0, +) / Double(perPieceWall.count) }
}


/// One laya call exactly as made: the sequence laya sees and everything it returned.
struct LayaCall {
    let rotation: Int
    let column: Int
    let state: String
    let instructions: String
    let optionTexts: [String]
    let labels: [String]
    let probabilities: [Float]
    let rawProbabilities: [Float]
    let logits: [Float]
    let confidence: Float
    let tokenCount: Int
    let bucketLength: Int
    let truncated: Bool
    let latencyMs: Double

    /// laya's `build_sequence` layout: `[CLS] <type> question: <instructions> [SEP] ([MASK] option)* [SEP] state [SEP]`.
    var sequenceText: String {
        "[CLS] noul question: \(instructions) [SEP] "
            + optionTexts.map { "[MASK] \($0)" }.joined(separator: " ") + " [SEP] \(state) [SEP]"
    }
}

/// One Jev HTTPS exchange for a whole piece.
struct JevExchange {
    let endpoint: String
    /// Pretty-printed for reading; number noise from re-serialization is trimmed.
    let request: String
    let response: String
    /// Exactly the bytes on the wire.
    let rawRequest: String
    let rawResponse: String
    let httpStatus: Int
    let attempts: Int
    let roundTripMs: Double
    let inputTokens: Int
    let outputTokens: Int
    let model: String
}

enum CallTrace {
    case laya([LayaCall])
    case jev(JevExchange)
}

/// One finished decision, frozen for the history sidebar.
struct DecisionSnapshot: Identifiable {
    struct Tile {
        let rotation: Int
        let column: Int
        let probability: Double
        /// Position within this piece's own min–max range, 0…1.
        let relative: Double
        let sentence: String
    }

    let id: Int
    let piece: String
    let tiles: [Tile]
    let chosen: (rotation: Int, column: Int)
    let chosenProbability: Double
    let low: Double
    let high: Double
    let wallMs: Double
    let agreesWithHeuristic: Bool
    let trace: CallTrace

    var rotations: Int { (tiles.map(\.rotation).max() ?? 0) + 1 }
}

/// One game driven by one policy. Two of these run side by side in `Arena`.
@MainActor
final class GameModel: ObservableObject, Identifiable {
    enum Policy: String {
        case laya = "laya"
        case kev = "Kev (local)"
        case jev = "Jev API"
    }

    let policy: Policy
    @Published private(set) var game: TetrisGame
    @Published private(set) var piece: TetrisGame.Piece?
    @Published private(set) var landings: [ScoredLanding] = []
    @Published private(set) var scanning: Int?
    @Published private(set) var chosen: Int?
    @Published private(set) var stats = GameStats()
    @Published private(set) var history: [DecisionSnapshot] = []
    @Published var status = ""
    @Published private(set) var failed = false

    var manager: LayaManager?
    var jevKey = ""
    /// Pause after each laya answer so the matrix fills in visibly (not counted in timings).
    var scanPaceMs = 12.0

    nonisolated var id: String { policy.rawValue }

    init(policy: Policy, seed: UInt64) {
        self.policy = policy
        game = TetrisGame(seed: seed)
    }

    /// P(clean) mapped onto this piece's own min–max range, so a narrow band of raw values still
    /// spreads across the color ramp.
    func relativeHeat(_ landing: ScoredLanding) -> Double? {
        guard let p = landing.probability else { return nil }
        let scored = landings.compactMap(\.probability)
        guard let low = scored.min(), let high = scored.max(), high > low else { return 1 }
        return (p - low) / (high - low)
    }

    func reset(seed: UInt64) {
        game = TetrisGame(seed: seed)
        piece = nil
        landings = []
        scanning = nil
        chosen = nil
        history = []
        failed = false
        stats = GameStats(modelLoad: stats.modelLoad)
    }

    func recordModelLoad(_ ms: Double) { stats.modelLoad = ms }

    /// Scores every landing of the next piece and picks one. The drop is separate (`drop()`) so the
    /// arena can hold both finished heatmaps on screen together before either piece falls.
    func decide() async {
        guard !game.isOver, !failed, let next = game.spawn() else { return }
        piece = next
        chosen = nil
        let candidates = game.candidates(for: next)
        guard !candidates.isEmpty else { return }
        landings = candidates.map { ScoredLanding(candidate: $0, sentence: game.describe($0, piece: next)) }
        let clock = ContinuousClock()
        var scoringWall: Duration = .zero
        var layaCalls: [LayaCall] = []
        var exchange: JevExchange?

        switch policy {
        case .laya:
            guard let manager else { return }
            // One call per landing: the matrix fills in tile by tile.
            for index in landings.indices {
                if Task.isCancelled { return }
                scanning = landings[index].id
                let sentence = landings[index].sentence
                let start = clock.now
                // Timed off the main actor so SwiftUI work does not inflate the number.
                let (answer, latency) = await Task.detached(priority: .userInitiated) {
                    let clock = ContinuousClock()
                    let start = clock.now
                    let answer = try? await manager.answer(state: sentence, question: LayaTetris.question)
                    return (answer, clock.now - start)
                }.value
                scoringWall += clock.now - start
                if let answer {
                    // Default Noul option texts, as laya renders them (`render_options`).
                    layaCalls.append(
                        LayaCall(
                            rotation: landings[index].rotation, column: landings[index].column, state: sentence,
                            instructions: answer.question.instructions,
                            optionTexts: ["false: no, the statement does not hold", "true: yes, the statement holds"],
                            labels: answer.question.labels, probabilities: answer.probabilities,
                            rawProbabilities: answer.rawProbabilities, logits: answer.logits,
                            confidence: answer.confidence, tokenCount: answer.tokenCount,
                            bucketLength: answer.bucketLength, truncated: answer.stateWasTruncated,
                            latencyMs: latency.ms))
                }
                landings[index].probability = Double(answer?.noul ?? 0)
                landings[index].latencyMs = latency.ms
                stats.latencies.append(latency.ms)
                stats.decisions += 1
                if scanPaceMs > 0 { try? await Task.sleep(for: .milliseconds(scanPaceMs)) }
            }
        case .jev, .kev:
            // One request for every landing: the whole matrix lands at once.
            scanning = nil
            let start = clock.now
            do {
                let result = try await (policy == .jev ? JevClient.jev(apiKey: jevKey) : JevClient.kev)
                    .scoreLandings(piece: next.name, sentences: landings.map(\.sentence))
                scoringWall = clock.now - start
                stats.jevRequests.append(scoringWall.ms)
                stats.jevTokens += result.inputTokens + result.outputTokens
                stats.jevInputTokens += result.inputTokens
                if policy == .kev { stats.jevModel = "kev · " + result.model }
                stats.jevModel = result.model
                stats.decisions += landings.count
                exchange = JevExchange(
                    endpoint: (policy == .jev ? JevClient.jev(apiKey: "") : JevClient.kev).endpoint.absoluteString,
                    request: Self.pretty(result.requestBody), response: Self.pretty(result.responseBody),
                    rawRequest: String(decoding: result.requestBody, as: UTF8.self),
                    rawResponse: String(decoding: result.responseBody, as: UTF8.self),
                    httpStatus: result.httpStatus, attempts: result.attempts, roundTripMs: scoringWall.ms,
                    inputTokens: result.inputTokens, outputTokens: result.outputTokens, model: result.model)
                for index in landings.indices {
                    landings[index].probability = result.probabilities[index]
                    landings[index].latencyMs = scoringWall.ms
                }
            } catch {
                status = error.localizedDescription
                failed = true
                return
            }
        }
        scanning = nil

        let heuristicBest = landings.max { $0.heuristic < $1.heuristic }!
        // Exact ties break toward the heuristic so play stays sensible.
        let pick = landings.max { ($0.probability ?? 0, $0.heuristic) < ($1.probability ?? 0, $1.heuristic) }!
        chosen = pick.id
        stats.pieces += 1
        stats.perPieceWall.append(scoringWall.ms)
        if pick.id == heuristicBest.id { stats.heuristicAgreements += 1 }
        stats.holesCreated += pick.candidate.features.newHoles
        status = "\(next.name) · picked rot \(pick.rotation), col \(pick.column)"

        let scored = landings.compactMap(\.probability)
        let low = scored.min() ?? 0
        let high = scored.max() ?? 1
        history.insert(
            DecisionSnapshot(
                id: stats.pieces, piece: next.name,
                tiles: landings.map {
                    let p = $0.probability ?? 0
                    return .init(
                        rotation: $0.rotation, column: $0.column, probability: p,
                        relative: high > low ? (p - low) / (high - low) : 1, sentence: $0.sentence)
                },
                chosen: (pick.rotation, pick.column), chosenProbability: pick.probability ?? 0, low: low, high: high,
                wallMs: scoringWall.ms, agreesWithHeuristic: pick.id == heuristicBest.id,
                trace: exchange.map(CallTrace.jev) ?? .laya(layaCalls)),
            at: 0)
        if history.count > 40 { history.removeLast() }
    }

    /// Exact token ids laya received for one call (computed on demand, outside the timings).
    func tokenIds(for call: LayaCall) async -> [Int]? {
        guard let manager else { return nil }
        return try? await manager.tokenSequence(
            state: call.state, question: LayaTetris.question, length: call.bucketLength
        ).ids
    }

    static func pretty(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
            let formatted = try? JSONSerialization.data(
                withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { return String(data: data, encoding: .utf8) ?? "" }
        return tidyNumbers(String(data: formatted, encoding: .utf8) ?? "")
    }

    /// `0.040000000000000001` → `0.04`: undo binary-float noise that re-serializing adds.
    static func tidyNumbers(_ text: String) -> String {
        guard let pattern = try? NSRegularExpression(pattern: #"-?\d+\.\d{10,}"#) else { return text }
        var output = text
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: output), let value = Double(output[range]) else { continue }
            output.replaceSubrange(range, with: String(format: "%.6g", value))
        }
        return output
    }

    func drop() {
        guard let chosen, let pick = landings.first(where: { $0.id == chosen }), !game.isOver else { return }
        game.apply(pick.candidate)
    }

    var summary: String {
        let s = stats
        var line = String(
            format: "%@: pieces %d, lines %d, holes %d, agreement with heuristic %.0f%%", policy.rawValue, s.pieces,
            game.linesCleared, s.holesCreated, s.agreement * 100)
        switch policy {
        case .laya:
            line += String(format: ", %d calls, mean %.2f ms, p95 %.2f ms", s.latencies.count, s.mean, s.percentile(0.95))
        case .jev, .kev:
            line += String(
                format: ", %d requests, round trip mean %.0f ms, p95 %.0f ms, %d input tokens ≈ $%.5f ($%.2f per 1,000 games of this length) (%@)",
                s.jevRequests.count, s.jevMean, s.jevPercentile(0.95), s.jevInputTokens, s.jevCost, s.jevCost * 1000, s.jevModel)
        }
        return line
    }
}

/// Runs laya and Jev on the same seed in lockstep: both decide the same piece, the finished
/// matrices are held together, then both pieces drop.
@MainActor
final class Arena: ObservableObject {
    let laya: GameModel
    let kev: GameModel
    let jev: GameModel
    @Published var seed: UInt64 = 7
    @Published private(set) var running = false
    @Published private(set) var layaReady = false
    @Published var jevKey = JevKey.resolve() {
        didSet { jev.jevKey = jevKey }
    }
    /// Color tiles by raw P(clean) instead of stretching each piece's own range.
    @Published var absoluteColor = false
    /// Hold both finished heatmaps before the pieces drop.
    @Published var dropPauseMs = 500.0
    @Published var scanPaceMs = 12.0 {
        didSet { laya.scanPaceMs = scanPaceMs }
    }

    /// The decision whose model calls are open in the inspector.
    @Published var inspecting: Inspection?

    struct Inspection: Identifiable {
        let id = UUID()
        let game: GameModel
        let snapshot: DecisionSnapshot
    }

    private var loop: Task<Void, Never>?

    var games: [GameModel] { [laya, kev, jev] }
    /// Any game that can still move; a game whose backend fails drops out without stopping the others.
    var canPlay: Bool { layaReady }
    private var anyActive: Bool { games.contains { !$0.game.isOver && !$0.failed } }

    init() {
        laya = GameModel(policy: .laya, seed: 7)
        kev = GameModel(policy: .kev, seed: 7)
        jev = GameModel(policy: .jev, seed: 7)
        jev.jevKey = jevKey
        laya.status = "Loading laya…"
        jev.status = jevKey.isEmpty ? "Set JEV_API_KEY in .env" : "Jev ready"
        kev.status = "Looking for a Kev server at \(JevClient.kevBase.absoluteString)…"
        Task { await checkKev() }
        Task { await loadLaya() }
    }

    func checkKev() async {
        if let loaded = await JevClient.kevStatus() {
            kev.status = "Kev ready · \(loaded)"
        } else {
            kev.status = "No Kev server at \(JevClient.kevBase.absoluteString) · run scripts/kev-server.sh"
        }
    }

    private func loadLaya() async {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            // The 128-token bucket fits every landing sentence and is the fastest on the Neural Engine.
            let loaded = try await LayaManager.load(configuration: LayaManager.Configuration(lengths: [128]))
            // First call pays the Core ML warm-up; keep it out of the stats.
            _ = try await loaded.answer(state: "The piece leaves no holes.", question: LayaTetris.question)
            laya.manager = loaded
            laya.recordModelLoad((clock.now - start).ms)
            layaReady = true
            laya.status = "laya ready"
            if ProcessInfo.processInfo.environment["TETRIS_AUTORUN"] == "1" { await autorun() }
        } catch {
            laya.status = "laya failed to load: \(error.localizedDescription)"
        }
    }

    /// `TETRIS_AUTORUN=1`: 30 lockstep pieces with no pacing, print both summaries, quit.
    private func autorun() async {
        scanPaceMs = 0
        dropPauseMs = 0
        newGame()
        await checkKev()
        for _ in 0..<30 where anyActive {
            await step()
            for game in games {
                if let last = game.history.first {
                    print(
                        String(
                            format: "%-7@ #%-2d %@ → rot %d col %d  P %.2f  range %.2f–%.2f  %.0f ms",
                            game.policy.rawValue, last.id, last.piece, last.chosen.rotation, last.chosen.column,
                            last.chosenProbability, last.low, last.high, last.wallMs))
                }
            }
        }
        games.forEach { print($0.summary + ($0.failed ? " · \($0.status)" : "")) }
        // Trace sample: what the inspector shows for the last piece.
        for game in games {
            guard let last = game.history.first else { continue }
            switch last.trace {
            case .laya(let calls):
                if let call = calls.first {
                    print("laya trace: \(calls.count) calls; first: \(call.sequenceText)")
                    print("  logits \(call.logits) → P \(call.probabilities), \(call.tokenCount) tokens / bucket \(call.bucketLength)")
                    if let ids = await game.tokenIds(for: call) { print("  ids: \(ids.prefix(call.tokenCount).map(String.init).joined(separator: " "))") }
                }
            case .jev(let exchange):
                print("jev trace: HTTP \(exchange.httpStatus), request \(exchange.request.utf8.count) B, response \(exchange.response.utf8.count) B")
                print(exchange.request.split(separator: "\n").prefix(14).joined(separator: "\n"))
                print(exchange.response.split(separator: "\n").prefix(8).joined(separator: "\n"))
            }
        }
        NSApplication.shared.terminate(nil)
    }

    func newGame() {
        stop()
        games.forEach { $0.reset(seed: seed) }
    }

    func play() {
        guard loop == nil else { return }
        running = true
        loop = Task {
            while !Task.isCancelled, anyActive {
                await step()
            }
            running = false
            loop = nil
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        running = false
    }

    /// Both games decide the same piece concurrently; drops wait for the slower one.
    func step() async {
        async let a: Void = laya.decide()
        async let b: Void = kev.decide()
        async let c: Void = jev.decide()
        _ = await (a, b, c)
        if dropPauseMs > 0 { try? await Task.sleep(for: .milliseconds(dropPauseMs)) }
        if Task.isCancelled { return }
        games.forEach { $0.drop() }
    }
}

extension Duration {
    var ms: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000 + Double(attoseconds) / 1e15
    }
}
