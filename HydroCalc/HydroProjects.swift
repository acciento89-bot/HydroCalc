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

enum HydroCommissioningError: Error { case invalidVisit }

struct HydroCommissioningRow: Codable, Equatable, Identifiable {
    let target: HydroCircuit
    let targetFlowLh: Double
    let measuredFlowLh: Double?
    var id: UUID { target.id }
    init(target: HydroCircuit, measuredFlowLh: Double?) throws {
        guard let flow = target.flowLh else { throw HydroCommissioningError.invalidVisit }
        self.target = target; targetFlowLh = flow; self.measuredFlowLh = measuredFlowLh
        guard isValid else { throw HydroCommissioningError.invalidVisit }
    }
    var deviationPercent: Double? {
        guard let measuredFlowLh, targetFlowLh > 0 else { return nil }
        let value = (measuredFlowLh - targetFlowLh) / targetFlowLh * 100
        return value.isFinite ? value : nil
    }
    func isWithinTolerance(_ tolerance: Double) -> Bool? { deviationPercent.map { abs($0) <= tolerance + 1e-9 } }
    var isValid: Bool {
        !target.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        targetFlowLh.isFinite && targetFlowLh > 0 && target.flowLh == targetFlowLh &&
        (measuredFlowLh.map { $0.isFinite && $0 >= 0 && deviationPercent != nil } ?? true)
    }
}

struct HydroCommissioningVisit: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let modelRevision: Int
    let tolerancePercent: Double
    let note: String
    let rows: [HydroCommissioningRow]
    init(circuits: [HydroCircuit], measuredFlows: [UUID: Double], tolerancePercent: Double,
         note: String, date: Date = Date()) throws {
        guard Set(measuredFlows.keys).isSubset(of: Set(circuits.map(\.id))) else { throw HydroCommissioningError.invalidVisit }
        id = UUID(); self.date = date; modelRevision = 1; self.tolerancePercent = tolerancePercent; self.note = note
        rows = try circuits.map { try HydroCommissioningRow(target: $0, measuredFlowLh: measuredFlows[$0.id]) }
        guard isValid else { throw HydroCommissioningError.invalidVisit }
    }
    var missingCount: Int { rows.filter { $0.measuredFlowLh == nil }.count }
    var isValid: Bool {
        modelRevision == 1 && date.timeIntervalSince1970.isFinite && tolerancePercent.isFinite &&
        (0...100).contains(tolerancePercent) && !rows.isEmpty && rows.allSatisfy(\.isValid) &&
        Set(rows.map(\.id)).count == rows.count
    }
}

struct HydroProject: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var circuits: [HydroCircuit] = []
    var baseline: HydroBaseline?
    var commissioningVisits: [HydroCommissioningVisit]? = nil
    var totals: HydroTotals { HydroTotals(circuits: circuits) }
    var groupTotals: [String: HydroTotals] {
        Dictionary(grouping: circuits, by: { $0.group.trimmingCharacters(in: .whitespacesAndNewlines) })
            .mapValues { HydroTotals(circuits: $0) }
    }

    mutating func captureBaseline() { baseline = HydroBaseline(circuits: circuits) }
    mutating func recordCommissioning(_ visit: HydroCommissioningVisit) throws {
        guard visit.isValid, !(commissioningVisits ?? []).contains(where: { $0.id == visit.id }) else { throw HydroCommissioningError.invalidVisit }
        commissioningVisits = (commissioningVisits ?? []) + [visit]
    }

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
        for visit in commissioningVisits ?? [] {
            lines += ["", de ? "Inbetriebnahme · eingefrorene Sollwerte" : "Commissioning visit · frozen targets",
                      ISO8601DateFormatter().string(from: visit.date), visit.note,
                      "\(de ? "Projekttoleranz" : "Project tolerance"): \(number(visit.tolerancePercent)) %; \(de ? "Messpunkte offen" : "Unmeasured"): \(visit.missingCount)",
                      "\(de ? "Rechenmodell" : "Model revision"): \(visit.modelRevision) · 1.163 Wh/(l·K)"]
            for row in visit.rows {
                let measured = row.measuredFlowLh.map { "\(number($0)) l/h" } ?? (de ? "Nicht gemessen" : "Unmeasured")
                let deviation = row.deviationPercent.map { "\(number($0)) %" } ?? "—"
                lines += ["\(row.target.name) [\(row.target.group)] · \(number(row.target.powerKW)) kW; ΔT \(number(row.target.deltaT)) K",
                          "\(de ? "Soll / Ist / Abweichung" : "Target / Measured / Deviation"): \(number(row.targetFlowLh)) l/h / \(measured) / \(deviation)"]
            }
        }
        lines += ["", de
            ? "Heizungswasser: Näherung 1.163 Wh/(l·K), Volumenstrom = kW × 1000 / (1.163 × ΔT). Stoffwerte für Glykol/andere Medien gesondert prüfen. Vorschlag und Ausgangsstand sind rechnerische Sollwerte. Messungen werden in den Inbetriebnahmebesuchen separat erfasst. Keine Pumpenauslegung oder Bestätigung eines hydraulischen Abgleichs."
            : "Heating water: approximation 1.163 Wh/(l·K), flow = kW × 1000 / (1.163 × ΔT). Check fluid properties separately for glycol/other fluids. Proposal and baseline are calculated targets; measurements are entered separately in commissioning visits. No pump sizing or certification of hydraulic balancing."]
        return lines.joined(separator: "\n")
    }
}

struct HydroProjectStorage {
    let url: URL
    private struct Envelope: Codable {
        var schemaVersion = 2
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
        guard (1...2).contains(envelope.schemaVersion) else { throw StorageError.unsupportedVersion }
        try validate(envelope.projects)
        return envelope.projects
    }

    private func validate(_ projects: [HydroProject]) throws {
        guard Set(projects.map(\.id)).count == projects.count else { throw StorageError.invalidArchive }
        for project in projects {
            guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StorageError.invalidArchive }
            let visits = project.commissioningVisits ?? []
            guard visits.allSatisfy(\.isValid), Set(visits.map(\.id)).count == visits.count else { throw StorageError.invalidArchive }
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
