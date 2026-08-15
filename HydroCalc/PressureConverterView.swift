import SwiftUI

struct PressureConverterView: View {
    private enum UnitType: String, CaseIterable, Identifiable {
        case bar, kPa, mbar, mWS, psi
        var id: String { rawValue }
        var label: String { rawValue }

        func toBar(_ value: Double) -> Double {
            switch self {
            case .bar: return value
            case .kPa: return value / 100
            case .mbar: return value / 1000
            case .mWS: return value / 10.19716213
            case .psi: return value / 14.5037738
            }
        }
    }

    @State private var unit: UnitType = .bar
    @State private var input = "1"
    @FocusState private var focused: Bool

    private var bar: Double? {
        guard let value = input.hydroDouble, value >= 0 else { return nil }
        return unit.toBar(value)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("pressure.source")
                        .font(.headline)
                    Picker("pressure.source", selection: $unit) {
                        ForEach(UnitType.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    NumberField(title: "pressure.value", unit: unit.label, text: $input)
                        .focused($focused)
                }
                .hydroCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("common.result")
                        .font(.headline)
                    if let bar {
                        MetricTile(title: "pressure.bar", value: bar.formatted(.number.precision(.fractionLength(0...4))), unit: "bar")
                        HStack(spacing: 10) {
                            MetricTile(title: "pressure.kpa", value: (bar * 100).formatted(.number.precision(.fractionLength(0...2))), unit: "kPa")
                            MetricTile(title: "pressure.mbar", value: (bar * 1000).formatted(.number.precision(.fractionLength(0...1))), unit: "mbar")
                        }
                        HStack(spacing: 10) {
                            MetricTile(title: "pressure.mws", value: (bar * 10.19716213).formatted(.number.precision(.fractionLength(0...3))), unit: "mWS")
                            MetricTile(title: "pressure.psi", value: (bar * 14.5037738).formatted(.number.precision(.fractionLength(0...2))), unit: "psi")
                        }
                    } else {
                        Text("common.invalid").foregroundStyle(.secondary)
                    }
                }
                .hydroCard()

                Text("pressure.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("pressure.title")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { focused = false }
            }
        }
    }
}
