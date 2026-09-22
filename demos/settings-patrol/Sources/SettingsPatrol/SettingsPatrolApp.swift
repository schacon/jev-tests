import AppKit
import SwiftUI
import WebKit

@main
struct SettingsPatrolApp: App {
    @StateObject private var model = PatrolModel()

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)
        // Bare SwiftPM executables start as background processes.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Settings Patrol · laya on-device") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1320, minHeight: 820)
        }
    }
}

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var model: PatrolModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                searchBar
                ExampleChips()
                Divider()
                if let result = model.result {
                    FunnelView(result: result)
                    MatchList(result: result)
                } else {
                    Spacer()
                    Text("Ask for a setting in your own words. laya narrows it down: account → sidebar group → page → setting.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(14)
            .frame(width: 600)
            .background(.background.secondary)
            Divider()
            WebView(webView: model.webView)
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("e.g. stop emails when my CI breaks", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit { Task { await model.search() } }
                if model.busy { ProgressView().controlSize(.small) }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            .disabled(!model.ready && model.engine == .laya)
            Picker("Engine", selection: $model.engine) {
                ForEach(Engine.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.busy)
            Text(model.status).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ExampleChips: View {
    @EnvironmentObject var model: PatrolModel

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Example.all) { example in
                Button(example.query) { Task { await model.search(example.query) } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!model.ready || model.busy)
            }
        }
    }
}

/// One column per stage: every option asked, its probability within its own question, the kept beam
/// branches in blue, pruned ones faded, and the winning path in green.
struct FunnelView: View {
    let result: FunnelResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(result.stages.enumerated()), id: \.offset) { index, stage in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(index + 1). \(stage.title)").font(.caption.weight(.bold))
                        Spacer()
                        Text(String(format: "%.1f ms", stage.totalMs)).font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("\(stage.callsMs.count) call\(stage.callsMs.count == 1 ? "" : "s") · \(stage.options.count) options")
                        .font(.caption2).foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(ranked(stage)) { option in OptionBar(option: option) }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                if index < result.stages.count - 1 {
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).padding(.top, 30)
                }
            }
        }
        .frame(height: 330)
    }

    private func ranked(_ stage: Stage) -> [StageOption] {
        Array(stage.options.sorted { $0.path > $1.path }.prefix(12))
    }
}

struct OptionBar: View {
    let option: StageOption

    var body: some View {
        let color: Color = option.winner ? .green : option.kept ? .blue : .gray
        VStack(alignment: .leading, spacing: 1) {
            Text(option.label).font(.caption2.weight(option.winner ? .bold : .regular)).lineLimit(1)
            if !option.parent.isEmpty {
                Text(option.parent).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(color.gradient).frame(width: max(2, geo.size.width * option.local))
                }
            }
            .frame(height: 5)
            Text(String(format: "%.0f%% · path %.1f%%", option.local * 100, option.path * 100))
                .font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 5).fill(option.winner ? Color.green.opacity(0.12) : .clear))
        .opacity(option.kept ? 1 : 0.4)
    }
}

struct MatchList: View {
    @EnvironmentObject var model: PatrolModel
    let result: FunnelResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BEST MATCHES").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            ForEach(Array(result.matches.enumerated()), id: \.element.id) { rank, match in
                Button {
                    model.open(match)
                } label: {
                    HStack(alignment: .top) {
                        Text("#\(rank + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.control.label).font(.callout.weight(.semibold)).lineLimit(1)
                            Text("\(match.scope == "org" ? "Organization" : "Personal") › \(match.page.title) › \(match.control.section)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", match.score * 100)).font(.callout.monospacedDigit())
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(
                            model.selected?.id == match.id ? Color.accentColor.opacity(0.15) : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wrapping row layout for the example chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            for (index, x) in row.items {
                subviews[index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private struct Row { var items: [(Int, CGFloat)] = []; var y: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        var x: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, !rows[rows.count - 1].items.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index, x))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
        }
        return rows
    }
}
