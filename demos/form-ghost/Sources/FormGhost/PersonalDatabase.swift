import AppKit
import FluidUse
import Foundation

/// The user's own details: one record per fact, with the other captions forms use for it.
/// Lives outside the repo (`~/Library/Application Support/FormGhost/me.json`, or `FORM_GHOST_DB`)
/// so personal data never lands in version control.
struct PersonalDatabase: Codable {
    struct Record: Codable, Identifiable {
        /// Stable name other records can reference as `{key}` in their value.
        let key: String
        let label: String
        let value: String
        var aliases: [String]?
        /// `date` values are stored ISO (`yyyy-mm-dd`) and reformatted to the field's hint.
        var type: String?

        var id: String { key }
        var captions: [String] { [label] + (aliases ?? []) }
    }

    var records: [Record]

    /// A record chosen for one field: which caption matched and how well.
    struct Match {
        let record: Record
        let caption: String
        let relevance: Double
        let entity: Entity
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["FORM_GHOST_DB"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FormGhost/me.json")
    }

    static let exampleURL = Bundle.module.url(forResource: "me.example", withExtension: "json", subdirectory: "Resources")!

    /// Loads the database, seeding it from the bundled example on first use.
    static func load() throws -> (PersonalDatabase, seeded: Bool) {
        var seeded = false
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: exampleURL, to: url)
            seeded = true
        }
        let database = try JSONDecoder().decode(PersonalDatabase.self, from: Data(contentsOf: url))
        return (database, seeded)
    }

    /// Records worth offering for `element`, best first, each labeled with its closest caption.
    /// With `relevantOnly`, records sharing no meaningful words with the field are withheld, so the
    /// model cannot put a ZIP code into "Promo code" just because it is the least-bad option.
    func matches(for element: FormElement, limit: Int, relevantOnly: Bool) -> [Match] {
        let fieldWords = Self.words(element.label + " " + element.placeholder)
        let hint = (element.label + " " + element.placeholder).lowercased()
        let scored = records.map { record -> Match in
            // Ties go to the longer caption: "City or town, state, and ZIP code" beats "ZIP code".
            let best = record.captions.map { ($0, Self.relevance(field: fieldWords, caption: Self.words($0))) }
                .max { ($0.1, Self.words($0.0).count) < ($1.1, Self.words($1.0).count) }!
            let value = format(resolve(record.value), type: record.type, hint: hint)
            return Match(
                record: record, caption: best.0, relevance: best.1, entity: Entity(label: best.0, value: value))
        }
        let kept = relevantOnly ? scored.filter { $0.relevance >= 0.5 } : scored
        return Array(
            kept.sorted {
                ($0.relevance, Self.words($0.caption).count) > ($1.relevance, Self.words($1.caption).count)
            }.prefix(limit))
    }

    // MARK: Values

    /// Expands `{key}` references so compound fields ("City, state, and ZIP") can be composed.
    private func resolve(_ value: String, depth: Int = 0) -> String {
        guard depth < 4, value.contains("{") else { return value }
        var output = value
        for record in records where output.contains("{\(record.key)}") {
            output = output.replacingOccurrences(of: "{\(record.key)}", with: resolve(record.value, depth: depth + 1))
        }
        return output
    }

    private func format(_ value: String, type: String?, hint: String) -> String {
        guard type == "date" else { return value }
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        let (y, m, d) = (parts[0], parts[1], parts[2])
        if hint.contains("mm/dd/yyyy") { return "\(m)/\(d)/\(y)" }
        if hint.contains("dd/mm/yyyy") { return "\(d)/\(m)/\(y)" }
        return value
    }

    // MARK: Matching

    /// Words that appear in many captions carry little signal on their own.
    private static let weak: Set<String> = [
        "name", "number", "code", "address", "date", "of", "the", "and", "or", "your", "a", "b", "c", "no", "id",
        "optional", "etc", "per", "only", "here", "if", "in", "on", "for", "to",
    ]

    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Weighted share of the caption's words found in the field: 1 when the caption is fully
    /// present, near 0 when only filler like "code" or "number" overlaps.
    static func relevance(field: [String], caption: [String]) -> Double {
        let fieldSet = Set(field)
        let weight = { (word: String) in weak.contains(word) ? 0.25 : 1.0 }
        let total = caption.map(weight).reduce(0, +)
        guard total > 0 else { return 0 }
        let hit = caption.filter(fieldSet.contains).map(weight).reduce(0, +)
        return hit / total
    }
}
