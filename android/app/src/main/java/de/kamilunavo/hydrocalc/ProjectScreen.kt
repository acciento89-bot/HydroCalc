package de.kamilunavo.hydrocalc

import android.app.Activity
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.io.File
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

@Composable
internal fun ProjectScreen(activity: Activity, language: AppLanguage, onBack: () -> Unit) {
    val de = language == AppLanguage.DE
    fun t(german: String, english: String) = if (de) german else english
    val locale = if (de) Locale.GERMANY else Locale.US
    val format = remember(locale) { NumberFormat.getNumberInstance(locale).apply { maximumFractionDigits = 3 } }
    fun n(value: Double) = format.format(value)
    val storage = remember { HydroProjectStorage(File(activity.filesDir, "HydroCalc/projects.json")) }
    val initial = remember(storage) { runCatching { storage.load() } }
    var projects by remember { mutableStateOf(initial.getOrDefault(emptyList())) }
    var loadBlocked by remember { mutableStateOf(initial.isFailure) }
    var error by rememberSaveable { mutableStateOf(if (initial.isFailure) "load" else "") }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var editingId by rememberSaveable { mutableStateOf<String?>(null) }
    var draftName by rememberSaveable { mutableStateOf("") }
    var draftGroup by rememberSaveable { mutableStateOf("") }
    var draftPower by rememberSaveable { mutableStateOf("") }
    var draftDelta by rememberSaveable { mutableStateOf("") }
    var nameAction by rememberSaveable { mutableStateOf("") }
    var projectName by rememberSaveable { mutableStateOf("") }
    var confirmation by rememberSaveable { mutableStateOf("") }
    var deleteCircuitId by rememberSaveable { mutableStateOf<String?>(null) }
    val project = projects.firstOrNull { it.id == selectedId }
    val keyboard = LocalSoftwareKeyboardController.current

    fun persist(next: List<HydroProject>): Boolean {
        if (loadBlocked) { error = "load"; return false }
        return try { storage.save(next); projects = next; true }
        catch (_: Exception) { error = "save"; false }
    }
    fun update(changed: HydroProject): Boolean = persist(projects.map { if (it.id == changed.id) changed else it })
    fun edit(circuit: HydroCircuit) {
        editingId = circuit.id; draftName = circuit.name; draftGroup = circuit.group
        draftPower = circuit.powerKW.toString(); draftDelta = circuit.deltaT.toString()
    }
    fun back() {
        if (editingId != null) editingId = null
        else if (selectedId != null) selectedId = null
        else onBack()
    }
    BackHandler { back() }

    Column(
        Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        TextButton(onClick = { back() }) { Text(t("← Zurück", "← Back")) }
        Text(t("Heizkreisprojekte", "Circuit projects"), style = MaterialTheme.typography.headlineMedium)
        if (loadBlocked) {
            NoteCard(t("Projekte konnten nicht geladen werden. Die Datei bleibt unverändert. Änderungen sind bis zum erfolgreichen Laden gesperrt.", "Projects could not be loaded. The file is unchanged. Editing is blocked until loading succeeds."))
            PrimaryAction(t("Erneut laden", "Retry loading")) {
                try { projects = storage.load(); loadBlocked = false; error = "" } catch (_: Exception) { error = "load" }
            }
        } else if (project != null && editingId != null) {
            val draft = HydroCircuit(editingId!!, draftName.trim(), draftGroup.trim(), draftPower.replace(',', '.').toDoubleOrNull() ?: Double.NaN, draftDelta.replace(',', '.').toDoubleOrNull() ?: Double.NaN)
            InputCard(t("Heizkreis", "Circuit")) {
                OutlinedTextField(draftName, { draftName = it }, label = { Text(t("Raum / Bezeichnung", "Room / circuit name")) }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(draftGroup, { draftGroup = it }, label = { Text(t("Gruppe / Etage (optional)", "Group / floor (optional)")) }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(draftPower, { draftPower = it }, label = { Text(t("Wärmeleistung (kW)", "Heat output (kW)")) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                OutlinedTextField(draftDelta, { draftDelta = it }, label = { Text(t("Temperaturdifferenz (K)", "Temperature difference (K)")) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                TextButton(onClick = { keyboard?.hide() }) { Text(t("Fertig", "Done")) }
                val flow = draft.flowLh
                if (flow != null) { Text("${n(flow)} l/h"); Text("${n(flow / 60)} l/min") }
                else Text(t("Bitte positive, endliche Eingabewerte prüfen.", "Enter valid positive finite values."), color = MaterialTheme.colorScheme.error)
                PrimaryAction(t("Speichern", "Save"), enabled = draft.name.isNotBlank() && flow != null) {
                    val next = if (project.circuits.any { it.id == draft.id }) project.circuits.map { if (it.id == draft.id) draft else it }
                        else project.circuits + draft
                    if (update(project.copy(circuits = next))) editingId = null
                }
                TextButton(onClick = { editingId = null }) { Text(t("Abbrechen", "Cancel")) }
            }
        } else if (project != null) {
            Text(project.name, style = MaterialTheme.typography.titleLarge)
            TextButton(onClick = { projectName = project.name; nameAction = "rename" }) { Text(t("Umbenennen", "Rename")) }
            TextButton(onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, project.worksheet(if (de) "de" else "en")) }
                try { activity.startActivity(Intent.createChooser(intent, t("Berechnungsblatt teilen", "Share worksheet"))) }
                catch (_: Exception) { error = "share" }
            }) { Text(t("Berechnungsblatt teilen", "Share worksheet")) }
            InputCard(t("Vorschlag / Sollwerte", "Proposal / target values")) {
                ProjectTotals(project.totals, de)
                project.baseline?.let { baseline ->
                    Text(t("Ausgangsstand", "Baseline"), style = MaterialTheme.typography.titleMedium)
                    Text(SimpleDateFormat("yyyy-MM-dd HH:mm", locale).format(Date(baseline.dateMillis)))
                    ProjectTotals(baseline.totals, de)
                    Text(t("Änderung zum Ausgangsstand", "Change from baseline"))
                    Text("Δ ${n(project.totals.powerKW - baseline.totals.powerKW)} kW · ${n(project.totals.flowLh - baseline.totals.flowLh)} l/h")
                }
                PrimaryAction(t("Ausgangsstand sichern", "Capture baseline"), enabled = project.circuits.isNotEmpty()) { confirmation = "baseline" }
            }
            if (project.groupTotals.isNotEmpty()) {
                InputCard(t("Gruppensummen", "Group totals")) {
                    project.groupTotals.toSortedMap().forEach { (group, total) ->
                        Text(group.ifEmpty { t("Ohne Gruppe", "Ungrouped") }, style = MaterialTheme.typography.titleMedium)
                        ProjectTotals(total, de)
                    }
                }
            }
            InputCard(t("Heizkreise", "Circuits")) {
                project.circuits.forEach { circuit ->
                    Text(circuit.name, style = MaterialTheme.typography.titleMedium)
                    if (circuit.group.isNotBlank()) Text(circuit.group)
                    Text("${n(circuit.powerKW)} kW · ΔT ${n(circuit.deltaT)} K")
                    Text(circuit.flowLh?.let { "${n(it)} l/h" } ?: t("Ungültig / ausgeschlossen", "Invalid / excluded"))
                    TextButton(onClick = { edit(circuit) }) { Text(t("Heizkreis bearbeiten", "Edit circuit")) }
                    TextButton(onClick = { deleteCircuitId = circuit.id; confirmation = "circuit" }) { Text(t("Löschen", "Delete")) }
                    HorizontalDivider()
                }
                PrimaryAction(t("Heizkreis hinzufügen", "Add circuit")) { edit(HydroCircuit(name = "", group = "", powerKW = 1.0, deltaT = 10.0)) }
            }
            TextButton(onClick = { confirmation = "project" }) { Text(t("Projekt löschen", "Delete project"), color = MaterialTheme.colorScheme.error) }
        } else {
            NoteCard(t("Räume und Heizkreise speichern, Sollwerte zusammenfassen und Änderungen vergleichen.", "Save rooms and circuits, review target totals and compare changes."))
            if (projects.isEmpty()) Text(t("Noch keine Projekte", "No projects yet"))
            projects.forEach { item ->
                OutlinedButton(onClick = { selectedId = item.id }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth()) {
                        Text(item.name, style = MaterialTheme.typography.titleMedium)
                        Text("${item.circuits.size} ${t("Heizkreise", "circuits")} · ${n(item.totals.flowLh)} l/h")
                    }
                }
            }
            PrimaryAction(t("Neues Projekt", "New project")) { projectName = ""; nameAction = "new" }
        }
        NoteCard(t(
            "Heizungswasser: Näherung 1,163 Wh/(l·K). Stoffwerte für Glykol/andere Medien gesondert prüfen. Rechnerische Sollwerte, keine Messwerte. Kein Nachweis eines hydraulischen Abgleichs und keine Pumpenauslegung.",
            "Heating water: approximation 1.163 Wh/(l·K). Check properties for glycol/other fluids separately. Calculated targets, not measurements. Does not certify hydraulic balancing or size a pump.",
        ))
    }
    if (nameAction.isNotEmpty()) AlertDialog(
        onDismissRequest = { nameAction = "" },
        title = { Text(if (nameAction == "new") t("Neues Projekt", "New project") else t("Umbenennen", "Rename")) },
        text = { OutlinedTextField(projectName, { projectName = it }, label = { Text(t("Projektname", "Project name")) }) },
        confirmButton = { TextButton(enabled = projectName.isNotBlank(), onClick = {
            if (nameAction == "new") {
                val created = HydroProject(name = projectName.trim())
                if (persist(projects + created)) { selectedId = created.id; nameAction = "" }
            } else if (project != null && update(project.copy(name = projectName.trim()))) nameAction = ""
        }) { Text(t("Speichern", "Save")) } },
        dismissButton = { TextButton(onClick = { nameAction = "" }) { Text(t("Abbrechen", "Cancel")) } },
    )
    if (confirmation.isNotEmpty() && project != null) AlertDialog(
        onDismissRequest = { confirmation = "" },
        title = { Text(when (confirmation) { "baseline" -> t("Ausgangsstand ersetzen?", "Replace baseline?"); "circuit" -> t("Heizkreis löschen?", "Delete circuit?"); else -> t("Projekt löschen?", "Delete project?") }) },
        text = { Text(if (confirmation == "baseline") t("Der bisherige Ausgangsstand wird durch die aktuellen Werte ersetzt. Spätere Änderungen beeinflussen ihn nicht.", "Replaces the existing baseline with current values. Later edits do not change it.") else t("Dieser Eintrag wird dauerhaft gelöscht.", "This entry will be permanently deleted.")) },
        confirmButton = { TextButton(onClick = {
            when (confirmation) {
                "baseline" -> update(project.captureBaseline())
                "circuit" -> update(project.copy(circuits = project.circuits.filter { it.id != deleteCircuitId }))
                "project" -> if (persist(projects.filter { it.id != project.id })) selectedId = null
            }
            confirmation = ""
        }) { Text(if (confirmation == "baseline") t("Sichern", "Capture") else t("Löschen", "Delete")) } },
        dismissButton = { TextButton(onClick = { confirmation = "" }) { Text(t("Abbrechen", "Cancel")) } },
    )
    if (error.isNotEmpty()) AlertDialog(
        onDismissRequest = { error = "" }, title = { Text(t("Projektspeicher", "Project storage")) },
        text = { Text(when (error) {
            "load" -> t("Projekte konnten nicht geladen werden. Die Datei bleibt unverändert; Änderungen sind gesperrt. Bitte erneut laden.", "Projects could not be loaded. The file is unchanged; editing is blocked. Retry loading.")
            "share" -> t("Teilen ist derzeit nicht verfügbar. Die gespeicherten Daten bleiben erhalten.", "Sharing is unavailable. Your saved data is retained.")
            else -> t("Speichern fehlgeschlagen. Der bisherige Stand bleibt erhalten. Speicherplatz und Zugriff prüfen, dann erneut versuchen.", "Could not save. Previous saved values are retained. Check storage and access, then try again.")
        }) }, confirmButton = { TextButton(onClick = { error = "" }) { Text(t("Fertig", "Done")) } },
    )
}

@Composable
private fun ProjectTotals(total: HydroTotals, de: Boolean) {
    val format = NumberFormat.getNumberInstance(if (de) Locale.GERMANY else Locale.US).apply { maximumFractionDigits = 3 }
    Text("${format.format(total.powerKW)} kW · ${format.format(total.flowLh)} l/h")
    if (total.invalidCount > 0) Text("${if (de) "Ungültige Heizkreise ausgeschlossen" else "Invalid circuits excluded"}: ${total.invalidCount}", color = MaterialTheme.colorScheme.error)
}
