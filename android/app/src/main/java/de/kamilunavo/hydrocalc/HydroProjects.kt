package de.kamilunavo.hydrocalc

import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

internal data class HydroCircuit(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val group: String,
    val powerKW: Double,
    val deltaT: Double,
) {
    val flowLh: Double? get() = if (!powerKW.isFinite() || !deltaT.isFinite()) null
        else HydroCalculator.flowLitersPerHour(powerKW, deltaT)?.takeIf { it.isFinite() }
}

internal data class HydroTotals(val powerKW: Double, val flowLh: Double, val invalidCount: Int) {
    companion object {
        fun from(circuits: List<HydroCircuit>): HydroTotals {
            var power = 0.0
            var flow = 0.0
            var invalid = 0
            circuits.forEach {
                val value = it.flowLh
                if (value == null || !(power + it.powerKW).isFinite() || !(flow + value).isFinite()) invalid++
                else { power += it.powerKW; flow += value }
            }
            return HydroTotals(power, flow, invalid)
        }
    }
}

internal data class HydroBaseline(val dateMillis: Long = System.currentTimeMillis(), val circuits: List<HydroCircuit>) {
    val totals: HydroTotals get() = HydroTotals.from(circuits)
}

internal data class HydroProject(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val circuits: List<HydroCircuit> = emptyList(),
    val baseline: HydroBaseline? = null,
) {
    val totals: HydroTotals get() = HydroTotals.from(circuits)
    val groupTotals: Map<String, HydroTotals> get() = circuits.groupBy { it.group.trim() }.mapValues { HydroTotals.from(it.value) }
    fun captureBaseline(): HydroProject = copy(baseline = HydroBaseline(circuits = circuits.map { it.copy() }))

    fun worksheet(language: String): String {
        val de = language.startsWith("de")
        val locale = if (de) Locale.GERMANY else Locale.US
        val format = NumberFormat.getNumberInstance(locale).apply { maximumFractionDigits = 3 }
        fun n(value: Double) = format.format(value)
        fun total(t: HydroTotals) = "${n(t.powerKW)} kW · ${n(t.flowLh)} l/h · ${if (de) "Ausgeschlossen" else "Excluded"}: ${t.invalidCount}"
        fun rows(items: List<HydroCircuit>) = items.map {
            val flow = it.flowLh?.let { value -> "${n(value)} l/h" } ?: if (de) "Ungültig / ausgeschlossen" else "Invalid / excluded"
            "• ${it.name} [${it.group}]: ${n(it.powerKW)} kW; ΔT ${n(it.deltaT)} K; $flow"
        }
        val lines = mutableListOf("HydroCalc — $name", if (de) "Berechnungsblatt / KEIN ZERTIFIKAT" else "Calculation worksheet / NOT A CERTIFICATE", "", if (de) "Vorschlag" else "Proposal")
        lines += rows(circuits)
        lines += listOf(total(totals), "", if (de) "Gruppen" else "Groups")
        groupTotals.toSortedMap().forEach { (group, totals) -> lines += "${group.ifEmpty { if (de) "Ohne Gruppe" else "Ungrouped" }}: ${total(totals)}" }
        baseline?.let {
            lines += listOf("", if (de) "Ausgangsstand" else "Baseline", SimpleDateFormat("yyyy-MM-dd HH:mm", locale).format(Date(it.dateMillis)))
            lines += rows(it.circuits)
            lines += listOf(total(it.totals), "Δ: ${n(totals.powerKW - it.totals.powerKW)} kW; ${n(totals.flowLh - it.totals.flowLh)} l/h")
        }
        lines += listOf("", if (de)
            "Heizungswasser: Näherung 1.163 Wh/(l·K), Volumenstrom = kW × 1000 / (1.163 × ΔT). Stoffwerte für Glykol/andere Medien gesondert prüfen. Rechnerische Sollwerte, keine Messwerte. Keine Pumpenauslegung oder Bestätigung eines hydraulischen Abgleichs."
        else "Heating water: approximation 1.163 Wh/(l·K), flow = kW × 1000 / (1.163 × ΔT). Check fluid properties separately for glycol/other fluids. Calculated target values, not measurements. No pump sizing or certification of hydraulic balancing.")
        return lines.joinToString("\n")
    }
}

internal object HydroProjectCodec {
    private fun circuit(c: HydroCircuit) = JSONObject().put("id", c.id).put("name", c.name).put("group", c.group).put("powerKW", c.powerKW).put("deltaT", c.deltaT)
    private fun circuits(items: List<HydroCircuit>) = JSONArray().apply { items.forEach { put(circuit(it)) } }
    private fun project(p: HydroProject) = JSONObject().put("id", p.id).put("name", p.name).put("circuits", circuits(p.circuits)).apply {
        p.baseline?.let { put("baseline", JSONObject().put("dateMillis", it.dateMillis).put("circuits", circuits(it.circuits))) }
    }
    private fun projects(items: List<HydroProject>) = JSONArray().apply { items.forEach { put(project(it)) } }
    fun encodeLegacy(items: List<HydroProject>): String = projects(items).toString()
    fun encode(items: List<HydroProject>): String {
        validate(items)
        return JSONObject().put("schemaVersion", 1).put("projects", projects(items)).toString()
    }
    private fun readCircuits(array: JSONArray) = (0 until array.length()).map {
        val item = array.getJSONObject(it)
        HydroCircuit(item.getString("id"), item.getString("name"), item.getString("group"), item.getDouble("powerKW"), item.getDouble("deltaT"))
    }
    fun decode(text: String): List<HydroProject> {
        val tokener = JSONTokener(text)
        val root = tokener.nextValue()
        require(tokener.nextClean() == 0.toChar()) { "Trailing data in project archive" }
        val array = when (root) {
            is JSONArray -> root
            is JSONObject -> {
                require(root.getInt("schemaVersion") == 1) { "Unsupported project schema" }
                root.getJSONArray("projects")
            }
            else -> error("Project archive must be an array or object")
        }
        val result = (0 until array.length()).map {
            val item = array.getJSONObject(it)
            val baseline = if (item.has("baseline") && !item.isNull("baseline")) {
                // A present wrong-type baseline is corruption, not an absent optional value.
                val base = item.getJSONObject("baseline")
                HydroBaseline(base.getLong("dateMillis"), readCircuits(base.getJSONArray("circuits")))
            } else null
            HydroProject(item.getString("id"), item.getString("name"), readCircuits(item.getJSONArray("circuits")), baseline)
        }
        validate(result)
        return result
    }
    private fun validate(items: List<HydroProject>) {
        require(items.map { it.id }.toSet().size == items.size) { "Duplicate project IDs" }
        items.forEach { project ->
            require(project.id.isNotBlank() && project.name.isNotBlank())
            listOfNotNull(project.circuits, project.baseline?.circuits).forEach { circuits ->
                require(circuits.map { it.id }.toSet().size == circuits.size) { "Duplicate circuit IDs" }
                require(circuits.all { it.id.isNotBlank() && it.name.isNotBlank() })
            }
        }
    }
}

internal class HydroProjectStorage(private val file: File) {
    fun load(): List<HydroProject> = if (!file.exists()) emptyList() else HydroProjectCodec.decode(file.readText())
    fun save(projects: List<HydroProject>) {
        // A restore or another process may have replaced the archive since UI initialization.
        load()
        val bytes = HydroProjectCodec.encode(projects).toByteArray(Charsets.UTF_8)
        val parent = requireNotNull(file.parentFile)
        require(parent.isDirectory || parent.mkdirs()) { "Cannot create project directory" }
        val temporary = File.createTempFile("projects-", ".tmp", parent)
        try {
            FileOutputStream(temporary).use { it.write(bytes); it.fd.sync() }
            Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } finally { temporary.delete() }
    }
}
