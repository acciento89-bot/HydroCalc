package de.kamilunavo.hydrocalc

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class HydroProjectsTest {
    private val circuit = HydroCircuit(name = "Living room", group = "Ground floor", powerKW = 11.63, deltaT = 10.0)

    @Test fun goldenFlowAndInvalidInputs() {
        assertEquals(1000.0, circuit.flowLh!!, 0.000001)
        listOf(0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY).forEach {
            assertNull(circuit.copy(powerKW = it).flowLh)
            assertNull(circuit.copy(deltaT = it).flowLh)
        }
    }

    @Test fun independentBaselineGroupsAndBilingualWorksheet() {
        val saved = HydroProject(name = "Commissioning", circuits = listOf(circuit)).captureBaseline()
        val proposed = saved.copy(circuits = listOf(circuit.copy(deltaT = 20.0), circuit.copy(id = "bath", name = "Bath", group = "Upstairs", powerKW = 5.815)))
        assertEquals(1000.0, proposed.baseline!!.totals.flowLh, 0.000001)
        assertEquals(1000.0, proposed.totals.flowLh, 0.000001)
        assertEquals(17.445, proposed.totals.powerKW, 0.000001)
        assertEquals(2, proposed.groupTotals.size)
        assertEquals(1, proposed.copy(circuits = proposed.circuits + circuit.copy(powerKW = 0.0)).totals.invalidCount)
        assertTrue(proposed.worksheet("en").contains("Baseline"))
        assertTrue(proposed.worksheet("en").contains("NOT A CERTIFICATE"))
        assertTrue(proposed.worksheet("de").contains("Ausgangsstand"))
        assertTrue(proposed.worksheet("en").contains("1.163"))
        assertTrue(proposed.worksheet("en").contains("Living room"))
    }

    @Test fun atomicStorageReloadMigrationAndCorruptPreservation() {
        val dir = Files.createTempDirectory("hydro-projects").toFile()
        try {
            val file = dir.resolve("projects.json")
            val storage = HydroProjectStorage(file)
            val project = HydroProject(name = "Job", circuits = listOf(circuit)).captureBaseline()
            assertTrue(storage.load().isEmpty())
            storage.save(listOf(project))
            assertEquals(listOf(project), storage.load())
            val bytes = file.readBytes()
            try { storage.save(listOf(project.copy(circuits = listOf(circuit.copy(powerKW = Double.NaN))))); fail("nonfinite write") } catch (_: Exception) {}
            assertArrayEquals(bytes, file.readBytes())
            file.writeText("{\"schemaVersion\":99,\"projects\":[]}")
            try { storage.load(); fail("future schema") } catch (_: Exception) {}
            assertTrue(file.readText().contains("99"))
            file.writeText("broken")
            try { storage.load(); fail("corrupt") } catch (_: Exception) {}
            assertEquals("broken", file.readText())
            file.writeText(HydroProjectCodec.encodeLegacy(listOf(project)))
            assertEquals(listOf(project), storage.load())
            storage.save(storage.load())
            assertTrue(file.readText().contains("schemaVersion"))
            listOf("broken", "{\"schemaVersion\":99,\"projects\":[]}").forEach { replacement ->
                file.writeText(replacement)
                try { storage.save(listOf(project)); fail("externally replaced archive") } catch (_: Exception) {}
                assertEquals(replacement, file.readText())
            }
            file.writeText(HydroProjectCodec.encodeLegacy(listOf(project, project)))
            try { storage.load(); fail("duplicate project IDs") } catch (_: Exception) {}
            file.writeText(HydroProjectCodec.encodeLegacy(listOf(project.copy(circuits = listOf(circuit, circuit)))))
            try { storage.load(); fail("duplicate circuit IDs") } catch (_: Exception) {}
            file.writeText(HydroProjectCodec.encodeLegacy(listOf(project.copy(baseline = HydroBaseline(circuits = listOf(circuit, circuit))))))
            try { storage.load(); fail("duplicate baseline circuit IDs") } catch (_: Exception) {}

        } finally { dir.deleteRecursively() }
    }
    @Test fun malformedJsonNeverLoadsOrOverwritesExistingBytes() {
        val dir = Files.createTempDirectory("hydro-strict-json").toFile()
        try {
            val file = dir.resolve("projects.json")
            val storage = HydroProjectStorage(file)
            val project = HydroProject(name = "Job", circuits = listOf(circuit)).captureBaseline()
            val valid = HydroProjectCodec.encode(listOf(project))
            file.writeText(valid + " \n\t")
            assertEquals(listOf(project), storage.load())
            val malformedBaselines = listOf<Any>("broken", org.json.JSONArray(), 42, true).map { bad ->
                org.json.JSONObject(valid).apply { getJSONArray("projects").getJSONObject(0).put("baseline", bad) }.toString()
            }
            val corruptArchives = listOf(valid + " trailing", valid + " {}", HydroProjectCodec.encodeLegacy(listOf(project)) + " trailing") + malformedBaselines
            corruptArchives.forEach { corrupt ->
                file.writeText(corrupt)
                assertThrows(Exception::class.java) { storage.load() }
                assertThrows(Exception::class.java) { storage.save(listOf(project)) }
                assertEquals(corrupt, file.readText())
            }
        } finally { dir.deleteRecursively() }
    }

}
