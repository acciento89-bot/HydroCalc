package de.kamilunavo.hydrocalc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoreScreenshotModeTest {
    @Test
    fun hidesBillingStatusOnlyForStoreScreenshots() {
        assertEquals("de.kamilunavo.hydrocalc.STORE_SCREENSHOTS", storeScreenshotsExtra("de.kamilunavo.hydrocalc"))
        assertFalse(shouldShowBillingStatus(storeScreenshots = true))
        assertTrue(shouldShowBillingStatus(storeScreenshots = false))
    }
}
