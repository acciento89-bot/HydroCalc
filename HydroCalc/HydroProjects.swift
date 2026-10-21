import Foundation

struct HydroCircuit: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var group: String
    var powerKW: Double
    var deltaT: Double

    var flowLh: Double? {
        guard powerKW.isFinite, deltaT.isFinite,
              let value = HydroCalculator.flowLitersPerHour(powerKW: powerKW, deltaT: deltaT),
              value.isFinite else { return nil }
        return value
    }
}

struct HydroTotals: Equatable {
    var powerKW = 0.0
    var flowLh = 0.0
    var invalidCount = 0

    init(circuits: [HydroCircuit]) {
        for circuit in circuits {
            guard let flow = circuit.flowLh,
                  (powerKW + circuit.powerKW).isFinite, (flowLh + flow).isFinite else {
                invalidCount += 1
                continue
            }
            powerKW += circuit.powerKW
            flowLh += flow
        }
    }
}

struct HydroBaseline: Codable, Equatable {
    var date = Date()
    var circuits: [HydroCircuit]
    var totals: HydroTotals { HydroTotals(circuits: circuits) }
}

struct HydroProject: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var circuits: [HydroCircuit] = []
    var baseline: HydroBaseline?
    var totals: HydroTotals { HydroTotals(circuits: circuits) }
    var groupTotals: [String: HydroTotals] {
        Dictionary(grouping: circuits, by: { $0.group.trimmingCharacters(in: .whitespacesAndNewlines) })
            .mapValues { HydroTotals(circuits: $0) }
    }

    mutating func captureBaseline() { baseline = HydroBaseline(circuits: circuits) }

    func worksheet(language: String) -> String {
        let de = language.hasPrefix("de")
        let locale = Locale(identifier: de ? "de_DE" : "en_US")
        func number(_ value: Double) -> String {
            value.formatted(.number.locale(locale).precision(.fractionLength(0...3)))
        }
        func rows(_ circuits: [HydroCircuit]) -> [String] {
            circuits.map { circuit in
                let flow = circuit.flowLh.map { "\(number($0)) l/h" } ?? (de ? "Ungültig / ausgeschlossen" : "Invalid / excluded")
                return "• \(circuit.name) [\(circuit.group)]: \(number(circuit.powerKW)) kW; ΔT \(number(circuit.deltaT)) K; \(flow)"
            }
        }
        func total(_ totals: HydroTotals) -> String {
            "\(number(totals.powerKW)) kW · \(number(totals.flowLh)) l/h · \(de ? "Ausgeschlossen" : "Excluded"): \(totals.invalidCount)"
        }
        var lines = ["HydroCalc — \(name)", de ? "Berechnungsblatt / KEIN ZERTIFIKAT" : "Calculation worksheet / NOT A CERTIFICATE", "", de ? "Vorschlag" : "Proposal"]
        lines += rows(circuits)
        lines += [total(totals), "", de ? "Gruppen" : "Groups"]
        for key in groupTotals.keys.sorted() {
            lines.append("\(key.isEmpty ? (de ? "Ohne Gruppe" : "Ungrouped") : key): \(total(groupTotals[key]!))")
        }
        if let baseline {
            lines += ["", de ? "Ausgangsstand" : "Baseline", baseline.date.formatted(date: .numeric, time: .shortened)]
            lines += rows(baseline.circuits)
            lines += [total(baseline.totals), "Δ: \(number(totals.powerKW - baseline.totals.powerKW)) kW; \(number(totals.flowLh - baseline.totals.flowLh)) l/h"]
        }
        lines += ["", de
            ? "Heizungswasser: Näherung 1.163 Wh/(l·K), Volumenstrom = kW × 1000 / (1.163 × ΔT). Stoffwerte für Glykol/andere Medien gesondert prüfen. Rechnerische Sollwerte, keine Messwerte. Keine Pumpenauslegung oder Bestätigung eines hydraulischen Abgleichs."
            : "Heating water: approximation 1.163 Wh/(l·K), flow = kW × 1000 / (1.163 × ΔT). Check fluid properties separately for glycol/other fluids. Calculated target values, not measurements. No pump sizing or certification of hydraulic balancing."]
        return lines.joined(separator: "\n")
    }
}

struct HydroProjectStorage {
    let url: URL
    private struct Envelope: Codable {
        var schemaVersion = 1
        var projects: [HydroProject]
    }
    enum StorageError: Error { case unsupportedVersion, invalidArchive }

    func load() throws -> [HydroProject] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        // v0 was a bare array. Decoding does not rewrite existing bytes.
        if data.first(where: { ![9, 10, 13, 32].contains($0) }) == 91 {
            let projects = try decoder.decode([HydroProject].self, from: data)
            try validate(projects)
            return projects
        }
        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw StorageError.unsupportedVersion }
        try validate(envelope.projects)
        return envelope.projects
    }

    private func validate(_ projects: [HydroProject]) throws {
        guard Set(projects.map(\.id)).count == projects.count else { throw StorageError.invalidArchive }
        for project in projects {
            guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StorageError.invalidArchive }
            for circuits in [project.circuits, project.baseline?.circuits].compactMap({ $0 }) {
                guard Set(circuits.map(\.id)).count == circuits.count,
                      circuits.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw StorageError.invalidArchive }
            }
        }
    }

    func save(_ projects: [HydroProject]) throws {
        // A restore or another process may have replaced the archive after the UI loaded.
        _ = try load()
        try validate(projects)
        // Encode before touching the destination; nonfinite inputs fail safely.
        let data = try JSONEncoder().encode(Envelope(projects: projects))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
