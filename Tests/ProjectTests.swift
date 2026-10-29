import Foundation

@main
struct ProjectTests {
    static func check(_ condition: Bool, _ message: String = "assertion failed") { precondition(condition, message) }
    static func main() throws {
        let circuit = HydroCircuit(name: "Living room", group: "Ground floor", powerKW: 11.63, deltaT: 10)
        check(abs(circuit.flowLh! - 1000) < 0.000001, "water factor golden case")
        for bad in [0.0, -1, .infinity, .nan] {
            check(HydroCircuit(name: "X", group: "", powerKW: bad, deltaT: 10).flowLh == nil)
            check(HydroCircuit(name: "X", group: "", powerKW: 1, deltaT: bad).flowLh == nil)
        }
        var project = HydroProject(name: "Commissioning")
        project.circuits = [circuit]
        project.captureBaseline()
        project.circuits[0].deltaT = 20
        project.circuits.append(HydroCircuit(name: "Bath", group: "Upper floor", powerKW: 5.815, deltaT: 10))
        check(project.baseline!.circuits.count == 1, "snapshot must be independent")
        check(abs(project.baseline!.totals.flowLh - 1000) < 0.000001)
        check(abs(project.totals.flowLh - 1000) < 0.000001)
        check(abs(project.totals.powerKW - 17.445) < 0.000001)
        check(project.groupTotals.count == 2)
        project.circuits.append(HydroCircuit(name: "Invalid", group: "", powerKW: 0, deltaT: 0))
        check(project.totals.invalidCount == 1)
        check(abs(project.totals.flowLh - 1000) < 0.000001, "invalid circuit excluded explicitly")
        let en = project.worksheet(language: "en")
        let de = project.worksheet(language: "de")
        check(en.contains("Living room") && en.contains("Baseline") && en.contains("1.163"))
        check(de.contains("Ausgangsstand") && de.contains("Invalid"))
        check(en.contains("NOT A CERTIFICATE"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("projects.json")
        let storage = HydroProjectStorage(url: file)
        check(try storage.load().isEmpty)
        try storage.save([project])
        let loaded = try storage.load()
        check(loaded == [project], "cold reload preserves all fields and baseline")
        let before = try Data(contentsOf: file)
        var invalid = project
        invalid.circuits[0].powerKW = .nan
        do { try storage.save([invalid]); fatalError("nonfinite save must fail") } catch {}
        check(try Data(contentsOf: file) == before, "failed save cannot destroy saved projects")
        try Data("{\"schemaVersion\":99,\"projects\":[]}".utf8).write(to: file)
        do { _ = try storage.load(); fatalError("future schema must be rejected") } catch {}
        check(String(data: try Data(contentsOf: file), encoding: .utf8)!.contains("99"))
        try Data("broken".utf8).write(to: file)
        do { _ = try storage.load(); fatalError("corruption must be visible") } catch {}
        // Legacy v0 is a bare array. Loading is non-destructive and next successful save upgrades it.
        try JSONEncoder().encode([project]).write(to: file)
        check(try storage.load() == [project])
        try storage.save(try storage.load())
        check(String(data: try Data(contentsOf: file), encoding: .utf8)!.contains("schemaVersion"))
        // Peer review: an archive can be externally replaced after a successful load.
        for replacement in ["broken", "{\"schemaVersion\":99,\"projects\":[]}"] {
            try replacement.data(using: .utf8)!.write(to: file)
            do { try storage.save([project]); fatalError("must reject externally replaced corrupt/future archive") } catch {}
            check(try Data(contentsOf: file) == replacement.data(using: .utf8)!, "replacement preserved")
        }
        try JSONEncoder().encode([project, project]).write(to: file)
        do { _ = try storage.load(); fatalError("duplicate project IDs rejected") } catch {}
        var duplicateCircuits = project
        duplicateCircuits.circuits = [circuit, circuit]
        try JSONEncoder().encode([duplicateCircuits]).write(to: file)
        do { _ = try storage.load(); fatalError("duplicate circuit IDs rejected") } catch {}
        var duplicateBaseline = project
        duplicateBaseline.baseline = HydroBaseline(circuits: [circuit, circuit])
        try JSONEncoder().encode([duplicateBaseline]).write(to: file)
        do { _ = try storage.load(); fatalError("duplicate baseline circuit IDs rejected") } catch {}
        var visitProject = HydroProject(name: "Measured circuit")
        visitProject.circuits = [circuit]
        let targetJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(circuit))
        var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(visitProject)) as! [String: Any]
        legacyObject["commissioningVisits"] = [["id": UUID().uuidString, "date": 800000000.0, "modelRevision": 1, "tolerancePercent": 10.0, "note": "Commissioning check", "rows": [["target": targetJSON, "targetFlowLh": circuit.flowLh!, "measuredFlowLh": 0.0]]]]
        let snapshotProject = try JSONDecoder().decode(HydroProject.self, from: JSONSerialization.data(withJSONObject: legacyObject))
        let snapshotJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshotProject)) as! [String: Any]
        check(snapshotJSON["commissioningVisits"] != nil, "Commissioning target and measured snapshot must survive save")
        let visit = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [circuit.id: 0], tolerancePercent: 10, note: "Meter A")
        check(visit.rows[0].deviationPercent == -100, "Measured zero gives a real negative deviation")
        let missing = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [:], tolerancePercent: 10, note: "Pending")
        check(missing.missingCount == 1 && missing.rows[0].deviationPercent == nil, "Missing never becomes zero")
        var commissioned = HydroProject(name: "Frozen target", circuits: [circuit])
        try commissioned.recordCommissioning(visit); try commissioned.recordCommissioning(missing)
        commissioned.circuits[0].deltaT = 20
        commissioned.circuits.removeAll()
        check(commissioned.commissioningVisits![0].rows[0].target.deltaT == 10 && abs(commissioned.commissioningVisits![0].rows[0].targetFlowLh - 1000) < 1e-6, "Plan edits/removal cannot rewrite captured targets")
        let measured = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [circuit.id: 1100], tolerancePercent: 10, note: "Boundary")
        check(measured.rows[0].isWithinTolerance(10) == true && measured.rows[0].isWithinTolerance(9) == false, "User tolerance boundary")
        for bad in [-1.0, Double.nan, Double.infinity] {
            do { _ = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [circuit.id: bad], tolerancePercent: 10, note: ""); fatalError("Invalid measured flow rejects") } catch {}
        }
        do { _ = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [UUID(): 1], tolerancePercent: 10, note: ""); fatalError("Foreign measurement rejects") } catch {}
        do { _ = try HydroCommissioningVisit(circuits: [], measuredFlows: [:], tolerancePercent: 10, note: ""); fatalError("Empty visit rejects") } catch {}
        do { _ = try HydroCommissioningVisit(circuits: [circuit, circuit], measuredFlows: [:], tolerancePercent: 10, note: ""); fatalError("Duplicate circuit rejects") } catch {}
        do { try commissioned.recordCommissioning(visit); fatalError("Duplicate visit rejects") } catch {}
        for tolerance in [-1.0, 101, Double.nan] {
            do { _ = try HydroCommissioningVisit(circuits: [circuit], measuredFlows: [:], tolerancePercent: tolerance, note: ""); fatalError("Invalid tolerance rejects") } catch {}
        }
        try FileManager.default.removeItem(at: file)
        try storage.save([commissioned]); check(try storage.load() == [commissioned], "Visits and target snapshots cold reload")
        var tampered = try JSONSerialization.jsonObject(with: JSONEncoder().encode([commissioned])) as! [[String: Any]]
        var visitsJSON = tampered[0]["commissioningVisits"] as! [[String: Any]]
        visitsJSON[0]["modelRevision"] = 999
        tampered[0]["commissioningVisits"] = visitsJSON
        let unsupportedVisit = try JSONSerialization.data(withJSONObject: tampered)
        try unsupportedVisit.write(to: file)
        do { _ = try storage.load(); fatalError("Future visit model rejects") } catch {}
        do { try storage.save([commissioned]); fatalError("Unsupported visit cannot be overwritten") } catch {}
        check(try Data(contentsOf: file) == unsupportedVisit, "Unsupported visit bytes preserved")
        try FileManager.default.removeItem(at: file)
        let visitSheet = commissioned.worksheet(language: "en")
        check(visitSheet.contains("Commissioning visit") && visitSheet.contains("Unmeasured") && visitSheet.contains("-100") && visitSheet.contains("Meter A"), "Worksheet includes actual, missing and frozen target context")
        check(commissioned.worksheet(language: "de").contains("Inbetriebnahme"), "German commissioning report")
        let old = HydroProject(name: "Old", circuits: [circuit])
        let oldBytes = try JSONEncoder().encode([old]); try oldBytes.write(to: file)
        check(try storage.load()[0].commissioningVisits == nil, "Legacy project receives no fabricated visits")
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "projects": try JSONSerialization.jsonObject(with: oldBytes)]).write(to: file)
        check(try storage.load() == [old], "v1 envelope remains readable")
        print("PASS HydroCalc commissioning: frozen targets, nil/zero, tolerance, validation, persistence, legacy reads, DE/EN report")
        print("PASS HydroCalc: formula, validation, totals, grouping, baseline, DE/EN worksheet, cold reload, atomic failure, future/corrupt preservation, legacy migration")
    }
}
