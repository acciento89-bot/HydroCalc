import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var name = ""
    @State private var adding = false
    @State private var deleting: HydroProject?

    var body: some View {
        List {
            if store.loadBlocked {
                Section {
                    Text("projects.loadError")
                    Button("projects.retry") { store.reload() }
                }
            } else {
                if store.projects.isEmpty {
                    ContentUnavailableView("projects.empty", systemImage: "folder", description: Text("projects.intro"))
                }
                ForEach(store.projects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.name).font(.headline)
                            Text("\(project.circuits.count)") + Text("projects.circuitCount")
                            Text("\(project.totals.flowLh.formatted(.number.precision(.fractionLength(0...1)))) l/h")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("projects.delete", role: .destructive) { deleting = project }
                    }
                }
            }
        }
        .navigationTitle("projects.title")
        .toolbar {
            Button { name = ""; adding = true } label: { Label("projects.new", systemImage: "plus") }
                .disabled(store.loadBlocked)
        }
        .alert("projects.new", isPresented: $adding) {
            TextField("projects.name", text: $name)
            Button("common.cancel", role: .cancel) {}
            Button("projects.save") { store.update(HydroProject(name: name.trimmingCharacters(in: .whitespacesAndNewlines))) }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog("projects.deleteConfirm", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("projects.delete", role: .destructive) {
                if let deleting { store.delete(deleting.id) }
                deleting = nil
            }
        } message: { Text(deleting?.name ?? "") }
        .projectError(store)
    }
}

private struct ProjectErrorModifier: ViewModifier {
    @ObservedObject var store: ProjectStore
    func body(content: Content) -> some View {
        content.alert("projects.error", isPresented: Binding(get: { store.errorKey != nil }, set: { if !$0 { store.errorKey = nil } })) {
            Button("common.done") { store.errorKey = nil }
        } message: { Text(LocalizedStringKey(store.errorKey ?? "projects.saveError")) }
    }
}
private extension View {
    func projectError(_ store: ProjectStore) -> some View { modifier(ProjectErrorModifier(store: store)) }
}

struct ProjectDetailView: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.locale) private var locale
    @State var project: HydroProject
    @State private var editing: HydroCircuit?
    @State private var deleting: HydroCircuit?
    @State private var capture = false
    @State private var renaming = false
    @State private var name = ""

    var body: some View {
        List {
            Section("projects.proposal") {
                totals(project.totals)
                if let baseline = project.baseline {
                    Text("projects.baseline").font(.headline)
                    Text(baseline.date, format: .dateTime.day().month().year().hour().minute()).font(.caption)
                    totals(baseline.totals)
                    Text("projects.change").font(.headline)
                    Text("\((project.totals.powerKW - baseline.totals.powerKW).formatted(.number.precision(.fractionLength(0...3)).sign(strategy: .always()))) kW")
                    Text("\((project.totals.flowLh - baseline.totals.flowLh).formatted(.number.precision(.fractionLength(0...1)).sign(strategy: .always()))) l/h")
                }
                Button("projects.capture") { capture = true }.disabled(project.circuits.isEmpty)
            }
            if !project.groupTotals.isEmpty {
                Section("projects.groups") {
                    ForEach(project.groupTotals.keys.sorted(), id: \.self) { group in
                        VStack(alignment: .leading, spacing: 5) {
                            if group.isEmpty { Text("projects.ungrouped").font(.headline) }
                            else { Text(group).font(.headline) }
                            totals(project.groupTotals[group]!)
                        }
                    }
                }
            }
            Section("projects.circuits") {
                ForEach(project.circuits) { circuit in
                    Button { editing = circuit } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(circuit.name).font(.headline)
                            if !circuit.group.isEmpty { Text(circuit.group).font(.subheadline) }
                            Text("\(circuit.powerKW.formatted()) kW · ΔT \(circuit.deltaT.formatted()) K")
                            if let flow = circuit.flowLh { Text("\(flow.formatted(.number.precision(.fractionLength(0...1)))) l/h") }
                            else { Text("common.invalid").foregroundStyle(.red) }
                        }.foregroundStyle(.primary)
                    }
                    .swipeActions {
                        Button("projects.delete", role: .destructive) { deleting = circuit }
                    }
                }
                Button { editing = HydroCircuit(name: "", group: "", powerKW: 1, deltaT: 10) } label: {
                    Label("projects.addCircuit", systemImage: "plus.circle")
                }
            }
            Section {
                Text("flow.note")
                Text("projects.disclaimer")
            }.font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { name = project.name; renaming = true } label: { Label("projects.rename", systemImage: "pencil") }
                ShareLink(item: project.worksheet(language: locale.language.languageCode?.identifier ?? "en")) {
                    Label("projects.share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $editing) { circuit in
            CircuitEditor(circuit: circuit) { changed in
                var proposed = project
                if let index = proposed.circuits.firstIndex(where: { $0.id == changed.id }) { proposed.circuits[index] = changed }
                else { proposed.circuits.append(changed) }
                return save(proposed)
            }
        }
        .alert("projects.rename", isPresented: $renaming) {
            TextField("projects.name", text: $name)
            Button("common.cancel", role: .cancel) {}
            Button("projects.save") { var changed = project; changed.name = name.trimmingCharacters(in: .whitespacesAndNewlines); _ = save(changed) }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog("projects.captureConfirm", isPresented: $capture) {
            Button("projects.capture") { var proposed = project; proposed.captureBaseline(); _ = save(proposed) }
        } message: { Text("projects.captureMessage") }
        .confirmationDialog("projects.deleteCircuitConfirm", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("projects.delete", role: .destructive) {
                var proposed = project
                proposed.circuits.removeAll { $0.id == deleting?.id }
                _ = save(proposed)
                deleting = nil
            }
        } message: { Text(deleting?.name ?? "") }
        .projectError(store)
    }

    private func save(_ proposed: HydroProject) -> Bool {
        guard store.update(proposed) else { return false }
        project = proposed
        return true
    }

    @ViewBuilder private func totals(_ totals: HydroTotals) -> some View {
        Text("\(totals.powerKW.formatted(.number.precision(.fractionLength(0...3)))) kW · \(totals.flowLh.formatted(.number.precision(.fractionLength(0...1)))) l/h")
            .monospacedDigit()
        if totals.invalidCount > 0 {
            (Text("projects.excluded") + Text(" \(totals.invalidCount)"))
                .foregroundStyle(.red)
        }
    }
}

private struct CircuitEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ProjectStore
    let circuit: HydroCircuit
    let onSave: (HydroCircuit) -> Bool
    @State private var name: String
    @State private var group: String
    @State private var power: String
    @State private var deltaT: String
    @FocusState private var numericFocus: Bool

    init(circuit: HydroCircuit, onSave: @escaping (HydroCircuit) -> Bool) {
        self.circuit = circuit
        self.onSave = onSave
        _name = State(initialValue: circuit.name)
        _group = State(initialValue: circuit.group)
        // Preserve stored precision if the user edits only a name or group.
        _power = State(initialValue: String(circuit.powerKW))
        _deltaT = State(initialValue: String(circuit.deltaT))
    }

    private var edited: HydroCircuit {
        var result = circuit
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.group = group.trimmingCharacters(in: .whitespacesAndNewlines)
        result.powerKW = power.hydroDouble ?? .nan
        result.deltaT = deltaT.hydroDouble ?? .nan
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("projects.circuit") {
                    TextField("projects.circuitName", text: $name)
                    TextField("projects.group", text: $group)
                }
                Section("projects.inputs") {
                    input("flow.power", unit: "kW", text: $power)
                    input("flow.deltaT", unit: "K", text: $deltaT)
                }
                Section("common.result") {
                    if let flow = edited.flowLh {
                        Text("\(flow.formatted(.number.precision(.fractionLength(0...1)))) l/h")
                        Text("\((flow / 60).formatted(.number.precision(.fractionLength(0...2)))) l/min")
                    } else { Text("common.invalid") }
                }
                Section { Text("flow.note") }.font(.footnote)
            }
            .navigationTitle("projects.circuit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("projects.save") { if onSave(edited) { dismiss() } }
                        .disabled(edited.name.isEmpty || edited.flowLh == nil)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("common.done") { numericFocus = false } }
            }
            .projectError(store)
        }
    }

    private func input(_ key: LocalizedStringKey, unit: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key).font(.subheadline)
            HStack {
                TextField("0", text: text).keyboardType(.decimalPad).focused($numericFocus)
                    .accessibilityLabel(Text(key))
                Text(unit).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
