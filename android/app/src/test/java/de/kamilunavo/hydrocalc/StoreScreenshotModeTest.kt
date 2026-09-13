package de.kamilunavo.hydrocalc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StoreScreenshotModeTest {
    @Test
    fun hidesBillingStatusOnlyForStoreScreenshots() {
        assertFalse(shouldShowBillingStatus(storeScreenshots = true))
        assertTrue(shouldShowBillingStatus(storeScreenshots = false))
    }
}
