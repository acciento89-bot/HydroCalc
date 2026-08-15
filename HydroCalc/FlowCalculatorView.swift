import SwiftUI

struct FlowCalculatorView: View {
    private enum SolveFor: String, CaseIterable, Identifiable {
        case flow, power, deltaT
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .flow: return "flow.solve.flow"
            case .power: return "flow.solve.power"
            case .deltaT: return "flow.solve.deltaT"
            }
        }
    }

    @State private var solveFor: SolveFor = .flow
    @State private var power = "20"
    @State private var deltaT = "10"
    @State private var flow = "1720"
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("flow.solve.title")
                        .font(.headline)

                    Picker("flow.solve.title", selection: $solveFor) {
                        ForEach(SolveFor.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .hydroCard()

                VStack(spacing: 14) {
                    if solveFor != .power {
                        NumberField(title: "flow.power", unit: "kW", text: $power)
                            .focused($focused)
                    }
                    if solveFor != .flow {
                        NumberField(title: "flow.flow", unit: "l/h", text: $flow)
                            .focused($focused)
                    }
                    if solveFor != .deltaT {
                        NumberField(title: "flow.deltaT", unit: "K", text: $deltaT)
                            .focused($focused)
                    }

                    if solveFor != .deltaT {
                        HStack {
                            Text("flow.presets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            ForEach([5, 10, 15, 20], id: \.self) { preset in
                                Button("\(preset) K") { deltaT = String(preset) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                .hydroCard()

                resultCard

                Text("flow.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("flow.title")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { focused = false }
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("common.result")
                .font(.headline)

            switch solveFor {
            case .flow:
                if let p = power.hydroDouble,
                   let dt = deltaT.hydroDouble,
                   let value = HydroCalculator.flowLitersPerHour(powerKW: p, deltaT: dt) {
                    MetricTile(title: "flow.flow", value: value.formatted(.number.precision(.fractionLength(0...0))), unit: "l/h")
                    HStack(spacing: 10) {
                        MetricTile(title: "flow.m3h", value: (value / 1000).formatted(.number.precision(.fractionLength(0...3))), unit: "m³/h")
                        MetricTile(title: "flow.lmin", value: (value / 60).formatted(.number.precision(.fractionLength(0...2))), unit: "l/min")
                    }
                } else { invalidResult }

            case .power:
                if let q = flow.hydroDouble,
                   let dt = deltaT.hydroDouble,
                   let value = HydroCalculator.powerKW(flowLh: q, deltaT: dt) {
                    MetricTile(title: "flow.power", value: value.formatted(.number.precision(.fractionLength(0...2))), unit: "kW")
                } else { invalidResult }

            case .deltaT:
                if let p = power.hydroDouble,
                   let q = flow.hydroDouble,
                   let value = HydroCalculator.deltaT(powerKW: p, flowLh: q) {
                    MetricTile(title: "flow.deltaT", value: value.formatted(.number.precision(.fractionLength(0...2))), unit: "K")
                } else { invalidResult }
            }
        }
        .hydroCard()
    }

    private var invalidResult: some View {
        Text("common.invalid")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
