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
        print("PASS HydroCalc: formula, validation, totals, grouping, baseline, DE/EN worksheet, cold reload, atomic failure, future/corrupt preservation, legacy migration")
    }
}
