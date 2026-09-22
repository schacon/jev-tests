import AppKit
import SwiftUI

/// Shows exactly what went to the model and what came back for one piece.
/// Click a tile to focus that landing's call.
struct CallInspector: View {
    @EnvironmentObject var arena: Arena
    @Environment(\.dismiss) private var dismiss
    let game: GameModel
    let snapshot: DecisionSnapshot
    @State private var selected: Int = 0

    init(game: GameModel, snapshot: DecisionSnapshot) {
        self.game = game
        self.snapshot = snapshot
        // Start on the chosen landing.
        let chosen = snapshot.tiles.firstIndex {
            $0.rotation == snapshot.chosen.rotation && $0.column == snapshot.chosen.column
        }
        _selected = State(initialValue: chosen ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    matrix
                    landingList
                }
                .frame(width: 250)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch snapshot.trace {
                        case .laya(let calls): LayaDetail(game: game, calls: calls, tile: tile)
                        case .jev(let exchange): JevDetail(exchange: exchange, index: selected)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(width: 1080, height: 740)
        .preferredColorScheme(.dark)
    }

    private var tile: DecisionSnapshot.Tile { snapshot.tiles[selected] }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(game.policy.rawValue) · piece #\(snapshot.id) · \(snapshot.piece)").font(.title2.bold())
                .foregroundStyle(policyTint(game.policy))
            Text(summary).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
    }

    private var summary: String {
        switch snapshot.trace {
        case .laya(let calls):
            return String(
                format: "%d on-device calls · %.0f ms total · picked rot %d col %d at %.1f%%", calls.count,
                snapshot.wallMs, snapshot.chosen.rotation, snapshot.chosen.column, snapshot.chosenProbability * 100)
        case .jev(let exchange):
            return String(
                format: "1 HTTP request · %.0f ms · %d in / %d out tokens · %@ · picked rot %d col %d at %.1f%%",
                exchange.roundTripMs, exchange.inputTokens, exchange.outputTokens, exchange.model,
                snapshot.chosen.rotation, snapshot.chosen.column, snapshot.chosenProbability * 100)
        }
    }

    private var matrix: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LANDINGS · click one").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<snapshot.rotations, id: \.self) { rotation in
                    GridRow {
                        ForEach(0..<TetrisGame.width, id: \.self) { column in
                            let index = snapshot.tiles.firstIndex { $0.rotation == rotation && $0.column == column }
                            cell(index)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ index: Int?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        if let index {
            let tile = snapshot.tiles[index]
            let isChosen = tile.rotation == snapshot.chosen.rotation && tile.column == snapshot.chosen.column
            ZStack {
                shape.fill(heat(arena.absoluteColor ? tile.probability : tile.relative))
                if isChosen { shape.stroke(.green, lineWidth: 2) }
                if index == selected { shape.stroke(.white, lineWidth: 2.5).padding(-1) }
            }
            .frame(width: 22, height: 22)
            .onTapGesture { selected = index }
        } else {
            shape.fill(Color(white: 0.1)).frame(width: 22, height: 22)
        }
    }

    private var landingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(snapshot.tiles.enumerated()), id: \.offset) { index, tile in
                    HStack {
                        Circle().fill(heat(tile.relative)).frame(width: 7, height: 7)
                        Text("rot \(tile.rotation) col \(tile.column)").font(.caption.monospaced())
                        Spacer()
                        Text(String(format: "%.1f%%", tile.probability * 100)).font(.caption.monospacedDigit())
                    }
                    .padding(.vertical, 2).padding(.horizontal, 4)
                    .background(index == selected ? Color.white.opacity(0.1) : .clear, in: .rect(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { selected = index }
                }
            }
        }
    }
}

// MARK: laya

struct LayaDetail: View {
    let game: GameModel
    let calls: [LayaCall]
    let tile: DecisionSnapshot.Tile
    @State private var tokenIds: [Int]?

    var body: some View {
        if let call = calls.first(where: { $0.rotation == tile.rotation && $0.column == tile.column }) {
            content(call)
                .onChange(of: tile.column) { tokenIds = nil }
                .onChange(of: tile.rotation) { tokenIds = nil }
        } else {
            Text("No call recorded for this landing.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func content(_ call: LayaCall) -> some View {
        Block(title: "CALL", note: "LayaManager.answer(state:question:) · on-device, no network") {
            Code(
                """
                let question = LayaQuestion.noul("\(call.instructions)")
                let answer = try await laya.answer(
                    state: "\(call.state)",
                    question: question)
                """)
        }
        Block(title: "SEQUENCE THE ENCODER SEES", note: "laya build_sequence; each [MASK] is read out as one option") {
            Code(call.sequenceText)
            HStack(spacing: 16) {
                fact("tokens", "\(call.tokenCount)")
                fact("bucket", "\(call.bucketLength)")
                fact("truncated", call.truncated ? "yes" : "no")
                fact("latency", String(format: "%.2f ms", call.latencyMs))
                fact("compute", "CPU + Neural Engine")
            }
            if let tokenIds {
                Code(tokenIds.prefix(call.tokenCount).map(String.init).joined(separator: " "))
            } else {
                Button("Show token ids") {
                    Task { tokenIds = await game.tokenIds(for: call) }
                }
                .controlSize(.small)
            }
        }
        Block(title: "RESPONSE", note: "one encoder pass; the head scores each [MASK], then temperature calibration") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("option").foregroundStyle(.secondary)
                    Text("logit").foregroundStyle(.secondary)
                    Text("raw P").foregroundStyle(.secondary)
                    Text("calibrated P").foregroundStyle(.secondary)
                }
                ForEach(call.labels.indices, id: \.self) { index in
                    GridRow {
                        Text(call.optionTexts[index]).font(.callout.monospaced())
                        Text(String(format: "%.3f", call.logits[index])).monospacedDigit()
                        Text(String(format: "%.1f%%", call.rawProbabilities[index] * 100)).monospacedDigit()
                        HStack {
                            Capsule().fill(index == 1 ? Color.green : Color.red)
                                .frame(width: max(2, 160 * CGFloat(call.probabilities[index])), height: 8)
                            Text(String(format: "%.1f%%", call.probabilities[index] * 100)).monospacedDigit()
                        }
                    }
                }
            }
            .font(.callout)
            Text(
                String(
                    format: "noul = P(true) = %.3f → this landing's heat. confidence %.3f.",
                    call.probabilities.last ?? 0, call.confidence)
            )
            .font(.callout).foregroundStyle(.secondary)
        }
        Block(title: "PER PIECE", note: "") {
            Text("laya answers one landing per call: \(calls.count) calls for this piece, run back to back, so the matrix fills in tile by tile.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit())
        }
    }
}

// MARK: Jev

struct JevDetail: View {
    let exchange: JevExchange
    let index: Int
    @State private var showFull = false

    var body: some View {
        Block(title: "THIS LANDING'S QUESTION", note: "questions.landing_\(index) in the request") {
            Code(excerpt(from: exchange.request, path: ["questions", "landing_\(index)"]))
            Code("state.landings[\(index)] = " + excerpt(from: exchange.request, path: ["state", "landings", "\(index)"]))
        }
        Block(title: "THIS LANDING'S ANSWER", note: "answers.landing_\(index) in the response") {
            Code(excerpt(from: exchange.response, path: ["answers", "landing_\(index)"]))
        }
        Block(
            title: "HTTP",
            note: String(
                format: "POST %@ · HTTP %d · %d attempt%@ · %.0f ms", exchange.endpoint,
                exchange.httpStatus, exchange.attempts, exchange.attempts == 1 ? "" : "s", exchange.roundTripMs)
        ) {
            Code(headers)
            Text("All \(countQuestions) questions travel in one request and are answered in parallel; each sees the whole `landings` array, so the matrix lands at once.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Show full request and response", isOn: $showFull).toggleStyle(.switch).controlSize(.small)
        }
        if showFull {
            HStack(alignment: .top, spacing: 12) {
                Block(title: "REQUEST BODY", note: "\(exchange.rawRequest.utf8.count) bytes, exactly as sent") {
                    Code(exchange.rawRequest)
                    copy(exchange.rawRequest)
                }
                Block(title: "RESPONSE BODY", note: "\(exchange.rawResponse.utf8.count) bytes, exactly as received") {
                    Code(exchange.rawResponse)
                    copy(exchange.rawResponse)
                }
            }
        }
    }

    private var headers: String {
        let url = URL(string: exchange.endpoint)
        let host = [url?.host, url?.port.map(String.init)].compactMap { $0 }.joined(separator: ":")
        let local = url?.host == "127.0.0.1" || url?.host == "localhost"
        let lines =
            ["POST \(url?.path ?? "/v1/systemone") HTTP/1.1", "Host: \(host)"]
            + (local ? [] : ["Authorization: Bearer ••••••••"]) + ["Content-Type: application/json"]
        return lines.joined(separator: "\n")
    }

    private var countQuestions: Int {
        guard let data = exchange.request.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let questions = object["questions"] as? [String: Any]
        else { return 0 }
        return questions.count
    }

    private func copy(_ text: String) -> some View {
        Button("Copy", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        .controlSize(.small)
    }

    /// Pretty-printed value at `path` in a JSON document (array indices as strings).
    private func excerpt(from json: String, path: [String]) -> String {
        guard let data = json.data(using: .utf8), var node = try? JSONSerialization.jsonObject(with: data) else {
            return "—"
        }
        for key in path {
            if let dictionary = node as? [String: Any], let next = dictionary[key] {
                node = next
            } else if let array = node as? [Any], let index = Int(key), array.indices.contains(index) {
                node = array[index]
            } else {
                return "—"
            }
        }
        if let string = node as? String { return "\"\(string)\"" }
        guard let formatted = try? JSONSerialization.data(
            withJSONObject: node, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
        else { return "\(node)" }
        return GameModel.tidyNumbers(String(data: formatted, encoding: .utf8) ?? "—")
    }
}

// MARK: Pieces

struct Block<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(note).font(.caption2).foregroundStyle(.tertiary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Code: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(white: 0.12), in: .rect(cornerRadius: 6))
    }
}
