import AppKit
import Charts
import FluidUse
import SwiftUI
import WebKit

@main
struct FormGhostApp: App {
    @StateObject private var model = GhostModel()

    init() {
        // Bare SwiftPM executables start as background processes.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Form Ghost") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1100, minHeight: 720)
        }
    }
}

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var model: GhostModel
    @State private var scan: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                Divider()
                WebView(webView: model.driver.webView)
            }
            Divider()
            Sidebar()
                .frame(width: 340)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Form", selection: Binding(get: { model.selected }, set: { model.load($0) })) {
                ForEach(SampleForm.all) { form in
                    Label(form.name, systemImage: form.symbol).tag(form)
                }
            }
            .labelsHidden()
            .frame(width: 200)
            .disabled(model.busy)

            Button {
                scan = Task { await model.runGhost() }
            } label: {
                Label("Run ghost", systemImage: "wand.and.rays")
            }
            .keyboardShortcut("r")
            .buttonStyle(.borderedProminent)
            .disabled(!model.modelReady || model.busy)

            Button {
                Task { await model.fillAll() }
            } label: {
                Label("Fill all", systemImage: "text.cursor")
            }
            .keyboardShortcut("f")
            .disabled(model.ghosts.isEmpty || model.busy)

            Button("Reset", systemImage: "arrow.counterclockwise") { model.reset() }
                .disabled(model.busy)
            if model.busy {
                Button("Stop", systemImage: "stop.fill") { scan?.cancel() }
            }
            Spacer()
            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
    }
}

struct Sidebar: View {
    @EnvironmentObject var model: GhostModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                timing
                chart
                breakdown
                settings
                sourcePanel
                decisions
                profile
            }
            .padding(16)
        }
        .background(.background.secondary)
    }

    private var timing: some View {
        section("Timing") {
            let s = model.stats
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                stat("Model load", s.modelLoad.map(GhostModel.format) ?? "—")
                stat("Page snapshot", s.count == 0 ? "—" : GhostModel.format(s.snapshot))
                stat("Decisions", "\(s.count)")
                stat("Mean / decision", ms(s.mean))
                stat("p50 · p95", "\(ms(s.percentile(0.5))) · \(ms(s.percentile(0.95)))")
                stat("Min · max", "\(ms(s.minimum)) · \(ms(s.maximum))")
                stat("Model time total", ms(s.total))
                stat("Scan wall (no pacing)", s.count == 0 ? "—" : GhostModel.format(s.scoringWall))
                stat("Throughput", s.count == 0 ? "—" : String(format: "%.0f decisions/s", s.decisionsPerSecond))
                stat("Fill all", s.fillWall.map(GhostModel.format) ?? "—")
            }
        }
    }

    private var chart: some View {
        section("Latency per control") {
            Chart(Array(model.ghosts.enumerated()), id: \.element.id) { index, ghost in
                BarMark(x: .value("Control", index), y: .value("ms", ghost.latencyMs))
                    .foregroundStyle(GhostModel.tier(ghost).color)
            }
            .chartXAxis(.hidden)
            .chartYAxisLabel("ms")
            .frame(height: 110)
        }
    }

    private var breakdown: some View {
        section("Decisions") {
            let ghosts = model.ghosts
            let count = { (action: FormAction) in ghosts.filter { $0.action == action }.count }
            let applicable = ghosts.filter(\.isApplicable)
            let confident = applicable.filter { $0.confidence >= 0.85 }.count
            let meanConfidence =
                applicable.isEmpty ? 0 : applicable.map { Double($0.confidence) }.reduce(0, +) / Double(applicable.count)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                stat("fill · check", "\(count(.fill)) · \(count(.check))")
                stat("skip · click", "\(count(.skip)) · \(count(.click))")
                stat("Exact-match rule", "\(count(.answer))")
                stat("Mean confidence", applicable.isEmpty ? "—" : String(format: "%.1f%%", meanConfidence * 100))
                stat("≥ 85% confident", applicable.isEmpty ? "—" : "\(confident) of \(applicable.count)")
                stat("Applied", "\(ghosts.filter { $0.status == .applied }.count)")
                stat("Below threshold", "\(ghosts.filter { $0.status == .skipped }.count)")
            }
        }
    }

    private var settings: some View {
        section("Settings") {
            VStack(alignment: .leading) {
                Text("Fill threshold: \(Int(model.threshold * 100))%").font(.caption)
                Slider(value: $model.threshold, in: 0...1)
                Text("Scan pacing: \(Int(model.paceMilliseconds)) ms (excluded from timings)").font(.caption)
                Slider(value: $model.paceMilliseconds, in: 0...400)
            }
        }
    }

    private var sourcePanel: some View {
        section("Your information") {
            Picker("Source", selection: $model.source) {
                ForEach(GhostModel.Source.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.busy)
            if model.source == .database {
                Toggle("Only offer relevant records", isOn: $model.relevantOnly)
                    .font(.caption)
                Toggle("Fill exact label matches the model skips (blue, “answer”)", isOn: $model.exactMatchRule)
                    .font(.caption)
                Text(PersonalDatabase.url.path(percentEncoded: false))
                    .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                Text(model.databaseNote).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Open", systemImage: "square.and.pencil") { model.revealDatabase() }
                    Button("Reload", systemImage: "arrow.clockwise") { model.reloadDatabase() }
                }
                .controlSize(.small)
            }
        }
    }

    private var decisions: some View {
        section("Controls") {
            if model.ghosts.isEmpty {
                Text("Run the ghost to score each control.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(model.ghosts) { ghost in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(GhostModel.tier(ghost).color).frame(width: 8, height: 8).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ghost.label).font(.caption.weight(.semibold)).lineLimit(1)
                        Text("\(ghost.action.rawValue) \(ghost.action == .fill ? ghost.summary : "")")
                            .font(.caption).lineLimit(1)
                        if model.source == .database {
                            Text(
                                ghost.entity.map { "as “\($0.label)” · \(ghost.offered) offered" }
                                    ?? "\(ghost.offered) offered"
                            )
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Text("runner-up: \(ghost.runnerUp)")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f%%", ghost.confidence * 100)).font(.caption.monospacedDigit())
                        Text(ms(ghost.latencyMs)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        if ghost.status != .planned {
                            Text(ghost.status.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { Task { await model.apply(token: ghost.id) } }
            }
        }
    }

    @ViewBuilder private var profile: some View {
        if model.source == .database, let database = model.database {
            section("Database (\(database.records.count) records)") {
                ForEach(database.records) { record in
                    HStack {
                        Text(record.label).foregroundStyle(.secondary)
                        Spacer()
                        Text(record.value).lineLimit(1)
                    }
                    .font(.caption)
                }
            }
        } else {
            sampleProfile
        }
    }

    private var sampleProfile: some View {
        section("Sample profile (\(model.entities.count) values)") {
            ForEach(model.entities) { entity in
                HStack {
                    Text(entity.label).foregroundStyle(.secondary)
                    Spacer()
                    Text(entity.value).lineLimit(1)
                }
                .font(.caption)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value).monospacedDigit().gridColumnAlignment(.trailing)
        }
        .font(.callout)
    }

    private func ms(_ value: Double) -> String { String(format: "%.2f ms", value) }
}
