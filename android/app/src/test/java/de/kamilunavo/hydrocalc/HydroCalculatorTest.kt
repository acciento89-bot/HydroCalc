package de.kamilunavo.hydrocalc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HydroCalculatorTest {
    private fun assertClose(expected: Double, actual: Double?, tolerance: Double = 0.0001) {
        requireNotNull(actual)
        assertEquals(expected, actual, tolerance)
    }

    @Test
    fun flowAndPowerRoundTrip() {
        val flow = HydroCalculator.flowLitersPerHour(20.0, 20.0)
        assertClose(859.8452278589854, flow)
        assertClose(20.0, HydroCalculator.powerKW(flow!!, 20.0))
    }

    @Test
    fun deltaTRoundTrip() {
        val flow = 1000.0
        val power = HydroCalculator.powerKW(flow, 15.0)!!
        assertClose(15.0, HydroCalculator.deltaT(power, flow))
    }

    @Test
    fun velocityAndDiameterRoundTrip() {
        val flow = 1200.0
        val diameter = 28.0
        val velocity = HydroCalculator.velocity(flow, diameter)!!
        assertClose(diameter, HydroCalculator.innerDiameterMM(flow, velocity))
    }

    @Test
    fun kvAndPressureRoundTrip() {
        val flow = 2.5
        val dp = 0.2
        val kv = HydroCalculator.kv(flow, dp)!!
        assertClose(dp, HydroCalculator.differentialPressureBar(flow, kv))
    }

    @Test
    fun invalidInputsReturnNull() {
        assertNull(HydroCalculator.flowLitersPerHour(0.0, 20.0))
        assertNull(HydroCalculator.velocity(1000.0, 0.0))
        assertNull(HydroCalculator.kv(2.0, 0.0))
    }
}
