import SwiftUI

struct KvCalculatorView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case kv, pressure
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .kv: return "kv.mode.kv"
            case .pressure: return "kv.mode.pressure"
            }
        }
    }

    @State private var mode: Mode = .kv
    @State private var flow = "1.5"
    @State private var pressure = "0.1"
    @State private var kv = "4.74"
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("kv.mode.title")
                        .font(.headline)
                    Picker("kv.mode.title", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .hydroCard()

                VStack(spacing: 14) {
                    NumberField(title: "kv.flow", unit: "m³/h", text: $flow)
                        .focused($focused)
                    if mode == .kv {
                        NumberField(title: "kv.pressure", unit: "bar", text: $pressure)
                            .focused($focused)
                    } else {
                        NumberField(title: "kv.value", unit: "Kv", text: $kv)
                            .focused($focused)
                    }
                }
                .hydroCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("common.result")
                        .font(.headline)

                    if mode == .kv {
                        kvResult
                    } else {
                        pressureResult
                    }
                }
                .hydroCard()

                Text("kv.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("kv.title")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { focused = false }
            }
        }
    }

    @ViewBuilder
    private var kvResult: some View {
        if let q = flow.hydroDouble,
           let dp = pressure.hydroDouble,
           let value = HydroCalculator.kv(flowM3h: q, differentialPressureBar: dp) {
            MetricTile(title: "kv.value", value: value.formatted(.number.precision(.fractionLength(0...2))), unit: "Kv")
        } else {
            Text("common.invalid").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var pressureResult: some View {
        if let q = flow.hydroDouble,
           let kvValue = kv.hydroDouble,
           let value = HydroCalculator.differentialPressureBar(flowM3h: q, kv: kvValue) {
            MetricTile(title: "kv.pressure", value: value.formatted(.number.precision(.fractionLength(0...3))), unit: "bar")
            HStack(spacing: 10) {
                MetricTile(title: "pressure.kpa", value: (value * 100).formatted(.number.precision(.fractionLength(0...1))), unit: "kPa")
                MetricTile(title: "pressure.mbar", value: (value * 1000).formatted(.number.precision(.fractionLength(0...0))), unit: "mbar")
            }
        } else {
            Text("common.invalid").foregroundStyle(.secondary)
        }
    }
}
