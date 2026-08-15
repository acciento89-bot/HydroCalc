import SwiftUI

struct PipeSizingView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case velocity, diameter
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .velocity: return "pipe.mode.velocity"
            case .diameter: return "pipe.mode.diameter"
            }
        }
    }

    @State private var mode: Mode = .velocity
    @State private var flow = "1200"
    @State private var diameter = "22"
    @State private var targetVelocity = "0.5"
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("pipe.mode.title")
                        .font(.headline)
                    Picker("pipe.mode.title", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .hydroCard()

                VStack(spacing: 14) {
                    NumberField(title: "pipe.flow", unit: "l/h", text: $flow)
                        .focused($focused)
                    if mode == .velocity {
                        NumberField(title: "pipe.innerDiameter", unit: "mm", text: $diameter)
                            .focused($focused)
                    } else {
                        NumberField(title: "pipe.targetVelocity", unit: "m/s", text: $targetVelocity)
                            .focused($focused)
                    }
                }
                .hydroCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("common.result")
                        .font(.headline)

                    if mode == .velocity {
                        velocityResult
                    } else {
                        diameterResult
                    }
                }
                .hydroCard()

                Text("pipe.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("pipe.title")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { focused = false }
            }
        }
    }

    @ViewBuilder
    private var velocityResult: some View {
        if let q = flow.hydroDouble,
           let d = diameter.hydroDouble,
           let value = HydroCalculator.velocity(flowLh: q, innerDiameterMM: d) {
            MetricTile(title: "pipe.velocity", value: value.formatted(.number.precision(.fractionLength(0...3))), unit: "m/s")
            HStack(spacing: 10) {
                MetricTile(title: "flow.m3h", value: (q / 1000).formatted(.number.precision(.fractionLength(0...3))), unit: "m³/h")
                MetricTile(title: "pipe.area", value: (Double.pi * pow(d / 2, 2)).formatted(.number.precision(.fractionLength(0...1))), unit: "mm²")
            }
        } else {
            Text("common.invalid").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var diameterResult: some View {
        if let q = flow.hydroDouble,
           let v = targetVelocity.hydroDouble,
           let value = HydroCalculator.innerDiameterMM(flowLh: q, targetVelocity: v) {
            MetricTile(title: "pipe.requiredDiameter", value: value.formatted(.number.precision(.fractionLength(0...1))), unit: "mm")
        } else {
            Text("common.invalid").foregroundStyle(.secondary)
        }
    }
}
