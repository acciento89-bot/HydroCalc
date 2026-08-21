package de.kamilunavo.hydrocalc

import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.sqrt

object HydroCalculator {
    const val WATER_FACTOR = 1.163

    fun flowLitersPerHour(powerKW: Double, deltaT: Double): Double? {
        if (powerKW <= 0 || deltaT <= 0) return null
        return powerKW * 1000.0 / (WATER_FACTOR * deltaT)
    }

    fun powerKW(flowLh: Double, deltaT: Double): Double? {
        if (flowLh <= 0 || deltaT <= 0) return null
        return flowLh * WATER_FACTOR * deltaT / 1000.0
    }

    fun deltaT(powerKW: Double, flowLh: Double): Double? {
        if (powerKW <= 0 || flowLh <= 0) return null
        return powerKW * 1000.0 / (flowLh * WATER_FACTOR)
    }

    fun velocity(flowLh: Double, innerDiameterMM: Double): Double? {
        if (flowLh <= 0 || innerDiameterMM <= 0) return null
        val flowM3s = flowLh / 3_600_000.0
        val diameterM = innerDiameterMM / 1000.0
        val area = PI * diameterM.pow(2) / 4.0
        return flowM3s / area
    }

    fun innerDiameterMM(flowLh: Double, targetVelocity: Double): Double? {
        if (flowLh <= 0 || targetVelocity <= 0) return null
        val flowM3s = flowLh / 3_600_000.0
        val diameterM = sqrt(4.0 * flowM3s / (PI * targetVelocity))
        return diameterM * 1000.0
    }

    fun kv(flowM3h: Double, differentialPressureBar: Double): Double? {
        if (flowM3h <= 0 || differentialPressureBar <= 0) return null
        return flowM3h / sqrt(differentialPressureBar)
    }

    fun differentialPressureBar(flowM3h: Double, kv: Double): Double? {
        if (flowM3h <= 0 || kv <= 0) return null
        return (flowM3h / kv).pow(2)
    }
}
