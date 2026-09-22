import AppKit
import SwiftUI

@main
struct TetrisHeatmapApp: App {
    @StateObject private var arena = Arena()

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)
        // Bare SwiftPM executables start as background processes.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Tetris Heatmap · laya vs Jev") {
            ContentView()
                .environmentObject(arena)
                .frame(minWidth: 1560, minHeight: 820)
                .preferredColorScheme(.dark)
        }
    }
}

/// Cold-to-hot ramp for P(clean): deep blue → magenta → amber → white.
func heat(_ p: Double) -> Color {
    let stops: [(Double, (Double, Double, Double))] = [
        (0.0, (0.10, 0.12, 0.35)), (0.4, (0.55, 0.15, 0.55)), (0.75, (0.95, 0.45, 0.15)), (1.0, (1.0, 0.95, 0.75)),
    ]
    let p = min(max(p, 0), 1)
    for (a, b) in zip(stops, stops.dropFirst()) where p <= b.0 {
        let t = (p - a.0) / (b.0 - a.0)
        return Color(
            red: a.1.0 + (b.1.0 - a.1.0) * t, green: a.1.1 + (b.1.1 - a.1.1) * t, blue: a.1.2 + (b.1.2 - a.1.2) * t)
    }
    return .white
}

let layaTint = Color(red: 0.35, green: 0.75, blue: 1.0)
let jevTint = Color(red: 0.75, green: 0.55, blue: 1.0)
let kevTint = Color(red: 0.45, green: 0.85, blue: 0.55)

func policyTint(_ policy: GameModel.Policy) -> Color {
    switch policy {
    case .laya: return layaTint
    case .kev: return kevTint
    case .jev: return jevTint
    }
}

struct ContentView: View {
    @EnvironmentObject var arena: Arena

    var body: some View {
        VStack(spacing: 0) {
            Toolbar()
            Divider()
            HStack(spacing: 0) {
                HistorySidebar(game: arena.laya, tint: layaTint)
                Divider()
                GamePanel(game: arena.laya, tint: layaTint)
                Divider()
                GamePanel(game: arena.kev, tint: kevTint)
                Divider()
                HistorySidebar(game: arena.kev, tint: kevTint)
                Divider()
                GamePanel(game: arena.jev, tint: jevTint)
                Divider()
                HistorySidebar(game: arena.jev, tint: jevTint)
            }
        }
        .background(Color(white: 0.08))
        .sheet(item: $arena.inspecting) { inspection in
            CallInspector(game: inspection.game, snapshot: inspection.snapshot)
        }
    }
}

struct Toolbar: View {
    @EnvironmentObject var arena: Arena

    var body: some View {
        HStack(spacing: 12) {
            Button(arena.running ? "Pause" : "Play", systemImage: arena.running ? "pause.fill" : "play.fill") {
                arena.running ? arena.stop() : arena.play()
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
            .disabled(!arena.canPlay)
            Button("Step", systemImage: "forward.frame") { Task { await arena.step() } }
                .keyboardShortcut("s", modifiers: [])
                .disabled(arena.running || !arena.canPlay)
            Button("New game", systemImage: "arrow.counterclockwise") { arena.newGame() }
            Toggle("Absolute color", isOn: $arena.absoluteColor)
                .toggleStyle(.switch).controlSize(.small)
                .help("Off: each piece's own P range spans the ramp. On: raw P(clean), 0–100%.")
            Spacer()
            labeled("laya pace", value: "\(Int(arena.scanPaceMs)) ms") {
                Slider(value: $arena.scanPaceMs, in: 0...80).frame(width: 110)
            }
            labeled("hold", value: "\(Int(arena.dropPauseMs)) ms") {
                Slider(value: $arena.dropPauseMs, in: 0...2000).frame(width: 110)
            }
            SecureField("JEV_API_KEY", text: $arena.jevKey)
                .textFieldStyle(.roundedBorder).frame(width: 160)
        }
        .padding(10)
    }

    private func labeled<C: View>(_ title: String, value: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
            Text(value).font(.caption.monospacedDigit()).frame(width: 52, alignment: .leading)
        }
    }
}

// MARK: Game panel

struct GamePanel: View {
    @EnvironmentObject var arena: Arena
    @ObservedObject var game: GameModel
    let tint: Color

    private var title: String {
        switch game.policy {
        case .laya: return "laya · on-device"
        case .kev: return "Kev · local server"
        case .jev: return "Jev · API"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.title3.bold()).foregroundStyle(tint)
                Spacer()
                Text(game.policy == .laya ? "one call per landing" : "one request per piece")
                    .font(.caption).foregroundStyle(.secondary)
            }
            StatHeader(game: game, tint: tint)
            BoardView(game: game)
            LiveMatrix(game: game)
            StatsStrip(game: game)
            Text(game.status).font(.caption).foregroundStyle(game.failed ? .red : .secondary).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minWidth: 300)
    }
}

struct BoardView: View {
    @EnvironmentObject var arena: Arena
    @ObservedObject var game: GameModel
    private let cell: CGFloat = 24

    var body: some View {
        let width = TetrisGame.width
        let height = TetrisGame.height
        // Hottest landing covering each cell.
        var hot = [[Double?]](repeating: [Double?](repeating: nil, count: width), count: height)
        for landing in game.landings {
            guard let p = arena.absoluteColor ? landing.probability : game.relativeHeat(landing) else { continue }
            for (x, y) in landing.candidate.cells { hot[y][x] = max(hot[y][x] ?? 0, p) }
        }
        let scanningCells = game.landings.first { $0.id == game.scanning }?.candidate.cells ?? []
        let chosenCells = game.landings.first { $0.id == game.chosen }?.candidate.cells ?? []

        return Canvas { context, _ in
            for y in 0..<height {
                for x in 0..<width {
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                        .insetBy(dx: 1, dy: 1)
                    let color: Color =
                        game.game.board[y][x]
                        ? Color(white: 0.55) : hot[y][x].map { heat($0).opacity(0.85) } ?? Color(white: 0.13)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                }
            }
            for (cells, color) in [(scanningCells, Color.orange), (chosenCells, Color.green)] {
                for (x, y) in cells {
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                        .insetBy(dx: 2, dy: 2)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(color), lineWidth: 2.5)
                }
            }
        }
        .frame(width: cell * CGFloat(width), height: cell * CGFloat(height))
        .overlay(alignment: .topLeading) {
            if let piece = game.piece {
                Text(piece.name).font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.12)).padding(6)
            }
        }
    }
}

/// The current piece's rotation × column matrix, filling in live.
struct LiveMatrix: View {
    @EnvironmentObject var arena: Arena
    @ObservedObject var game: GameModel

    var body: some View {
        let rotations = (game.landings.map(\.rotation).max() ?? 0) + 1
        let scored = game.landings.compactMap(\.probability)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DECISION MATRIX").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                if let low = scored.min(), let high = scored.max() {
                    Text(String(format: "P %.0f–%.0f%%", low * 100, high * 100))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<max(rotations, 1), id: \.self) { rotation in
                    GridRow {
                        ForEach(0..<TetrisGame.width, id: \.self) { column in
                            tile(game.landings.first { $0.rotation == rotation && $0.column == column })
                        }
                    }
                }
            }
        }
        .frame(width: 24 * CGFloat(TetrisGame.width))
        .contentShape(Rectangle())
        .onTapGesture {
            // Only a finished decision has a complete trace.
            if game.chosen != nil, let latest = game.history.first {
                arena.inspecting = .init(game: game, snapshot: latest)
            }
        }
        .help("Click to inspect the model calls for this piece")
    }

    @ViewBuilder private func tile(_ landing: ScoredLanding?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        ZStack {
            if let landing {
                let value = arena.absoluteColor ? landing.probability : game.relativeHeat(landing)
                shape.fill(value.map(heat) ?? Color(white: 0.2))
                if landing.id == game.scanning { shape.stroke(.orange, lineWidth: 2) }
                if landing.id == game.chosen { shape.stroke(.green, lineWidth: 2.5) }
            } else {
                shape.fill(Color(white: 0.1))
            }
        }
        .frame(width: 21, height: 21)
    }
}

/// Headline numbers pinned above each board, computed identically on both sides.
struct StatHeader: View {
    @ObservedObject var game: GameModel
    let tint: Color

    var body: some View {
        let s = game.stats
        let empty = s.pieces == 0
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            tile("pieces", "\(s.pieces)")
            tile("lines", "\(game.game.linesCleared)")
            tile("holes", "\(s.holesCreated)")
            tile("= heuristic", empty ? "—" : String(format: "%.0f%%", s.agreement * 100))
            tile("ms / piece", empty ? "—" : String(format: "%.0f", s.meanPieceWall))
            tile("p95 / piece", empty ? "—" : String(format: "%.0f", s.piecePercentile(0.95)))
            tile("ms / decision", empty ? "—" : String(format: s.msPerDecision < 10 ? "%.2f" : "%.1f", s.msPerDecision))
            tile("decisions", "\(s.decisions)")
            if game.policy != .laya {
                tile("input tokens", s.jevInputTokens >= 10_000 ? String(format: "%.1fk", Double(s.jevInputTokens) / 1000) : "\(s.jevInputTokens)")
                if game.policy == .jev {
                    tile("est. cost", empty ? "—" : dollars(s.jevCost))
                    tile("$ / piece", empty ? "—" : dollars(s.jevCostPerPiece))
                    tile("$ / 1k pieces", empty ? "—" : dollars(s.jevCostPerPiece * 1000))
                } else {
                    // Kev runs on this Mac: tokens are counted but nothing is billed.
                    tile("est. cost", "$0")
                    tile("tokens / piece", empty ? "—" : String(format: "%.0f", Double(s.jevInputTokens) / Double(s.pieces)))
                    tile("round trip p95", empty ? "—" : String(format: "%.0f", s.jevPercentile(0.95)))
                }
            } else {
                tile("input tokens", "local")
                tile("est. cost", "$0")
                tile("$ / piece", "$0")
                tile("model call", empty ? "—" : String(format: "%.2f ms", s.mean))
            }
        }
        .frame(width: 24 * CGFloat(TetrisGame.width))
    }

    /// Sub-cent amounts need more digits to mean anything.
    private func dollars(_ value: Double) -> String {
        value >= 1 ? String(format: "$%.2f", value) : value >= 0.01 ? String(format: "$%.3f", value) : String(format: "$%.5f", value)
    }

    private func tile(_ name: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: .rect(cornerRadius: 6))
    }
}

struct StatsStrip: View {
    @ObservedObject var game: GameModel

    var body: some View {
        let s = game.stats
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
            switch game.policy {
            case .laya:
                row("Per call mean · p95", String(format: "%.2f · %.2f ms", s.mean, s.percentile(0.95)))
                row("Model load", s.modelLoad.map { String(format: "%.1f s", $0 / 1000) } ?? "—")
            case .jev, .kev:
                row("Round trip mean · p95", String(format: "%.0f · %.0f ms", s.jevMean, s.jevPercentile(0.95)))
                row("Tokens", "\(s.jevTokens)")
                row("Model", s.jevModel.isEmpty ? "jev-latest" : s.jevModel)
            }
        }
        .font(.caption)
        .frame(width: 24 * CGFloat(TetrisGame.width), alignment: .leading)
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }
}

// MARK: History

/// Every past decision matrix, newest first. Lockstep play keeps piece #n on the same row on both sides.
struct HistorySidebar: View {
    @EnvironmentObject var arena: Arena
    @ObservedObject var game: GameModel
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(game.policy.rawValue.uppercased()) · PAST DECISIONS")
                .font(.caption2.weight(.bold)).foregroundStyle(tint)
                .padding(.horizontal, 12).padding(.vertical, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(game.history) { snapshot in
                        SnapshotRow(snapshot: snapshot, absolute: arena.absoluteColor)
                            .contentShape(Rectangle())
                            .onTapGesture { arena.inspecting = .init(game: game, snapshot: snapshot) }
                            .help("Click to inspect the model calls for this piece")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 210)
        .background(Color(white: 0.11))
    }
}

struct SnapshotRow: View {
    let snapshot: DecisionSnapshot
    let absolute: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("#\(snapshot.id) \(snapshot.piece)").font(.caption.bold().monospaced())
                Spacer()
                Text(String(format: "%.0f%%", snapshot.chosenProbability * 100)).font(.caption2.monospacedDigit())
                Image(systemName: snapshot.agreesWithHeuristic ? "equal.circle" : "notequal.circle")
                    .font(.caption2).foregroundStyle(snapshot.agreesWithHeuristic ? .green : .secondary)
                    .help(snapshot.agreesWithHeuristic ? "Same pick as the heuristic" : "Differs from the heuristic")
            }
            Canvas { context, _ in
                let size: CGFloat = 17
                for tile in snapshot.tiles {
                    let rect = CGRect(
                        x: CGFloat(tile.column) * (size + 1), y: CGFloat(tile.rotation) * (size + 1), width: size,
                        height: size)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(heat(absolute ? tile.probability : tile.relative)))
                    if tile.rotation == snapshot.chosen.rotation, tile.column == snapshot.chosen.column {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 2), with: .color(.green), lineWidth: 2)
                    }
                }
            }
            .frame(width: 18 * CGFloat(TetrisGame.width), height: 18 * CGFloat(snapshot.rotations))
            Text(String(format: "range %.0f–%.0f%% · %.0f ms", snapshot.low * 100, snapshot.high * 100, snapshot.wallMs))
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}
