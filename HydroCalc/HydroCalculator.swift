import Foundation

struct HydroCalculator {
    static let waterFactor = 1.163 // Wh/(l·K), practical approximation for heating water

    static func flowLitersPerHour(powerKW: Double, deltaT: Double) -> Double? {
        guard powerKW > 0, deltaT > 0 else { return nil }
        return powerKW * 1000 / (waterFactor * deltaT)
    }

    static func powerKW(flowLh: Double, deltaT: Double) -> Double? {
        guard flowLh > 0, deltaT > 0 else { return nil }
        return flowLh * waterFactor * deltaT / 1000
    }

    static func deltaT(powerKW: Double, flowLh: Double) -> Double? {
        guard powerKW > 0, flowLh > 0 else { return nil }
        return powerKW * 1000 / (flowLh * waterFactor)
    }

    static func velocity(flowLh: Double, innerDiameterMM: Double) -> Double? {
        guard flowLh > 0, innerDiameterMM > 0 else { return nil }
        let flowM3s = flowLh / 3_600_000
        let diameterM = innerDiameterMM / 1000
        let area = Double.pi * pow(diameterM, 2) / 4
        return flowM3s / area
    }

    static func innerDiameterMM(flowLh: Double, targetVelocity: Double) -> Double? {
        guard flowLh > 0, targetVelocity > 0 else { return nil }
        let flowM3s = flowLh / 3_600_000
        let diameterM = sqrt(4 * flowM3s / (Double.pi * targetVelocity))
        return diameterM * 1000
    }

    static func kv(flowM3h: Double, differentialPressureBar: Double) -> Double? {
        guard flowM3h > 0, differentialPressureBar > 0 else { return nil }
        return flowM3h / sqrt(differentialPressureBar)
    }

    static func differentialPressureBar(flowM3h: Double, kv: Double) -> Double? {
        guard flowM3h > 0, kv > 0 else { return nil }
        return pow(flowM3h / kv, 2)
    }
}

extension Double {
    var hydroInputString: String {
        formatted(.number.precision(.fractionLength(0...3)))
    }
}

extension String {
    var hydroDouble: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
    }
}
