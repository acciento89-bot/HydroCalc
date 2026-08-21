package de.kamilunavo.hydrocalc

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val billing = remember { BillingManager(applicationContext) }
            HydroCalcRoot(this, billing)
        }
    }
}

private enum class Language { DE, EN }
private enum class TabMode { FLOW, PRESSURE, PIPE, KV }
private enum class FlowMode { FLOW, POWER, DELTA_T }
private enum class PressureUnit { BAR, KPA, MBAR, MWS, PSI }

@Composable
private fun HydroCalcRoot(activity: Activity, billing: BillingManager) {
    var language by remember { mutableStateOf(Language.DE) }
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = TabMode.entries

    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFF42A5F5),
            secondary = Color(0xFF26C6DA),
            background = Color(0xFF0E1620),
            surface = Color(0xFF172331),
        )
    ) {
        Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                Header(language) { language = it }
                ScrollableTabRow(selectedTabIndex = selectedTab) {
                    tabs.forEachIndexed { index, tab ->
                        Tab(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            text = { Text(tabTitle(tab, language)) },
                        )
                    }
                }

                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    when (tabs[selectedTab]) {
                        TabMode.FLOW -> FlowCalculator(language)
                        TabMode.PRESSURE -> PressureConverter(language)
                        TabMode.PIPE -> if (billing.isPro) PipeCalculator(language) else ProGate(language, activity, billing)
                        TabMode.KV -> if (billing.isPro) KvCalculator(language) else ProGate(language, activity, billing)
                    }

                    if (billing.isPro) {
                        Text(
                            if (language == Language.DE) "HydroCalc Pro aktiv" else "HydroCalc Pro active",
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold,
                        )
                    } else {
                        OutlinedButton(onClick = billing::restorePurchases, modifier = Modifier.fillMaxWidth()) {
                            Text(if (language == Language.DE) "Käufe wiederherstellen" else "Restore purchases")
                        }
                    }
                    billing.statusMessage?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    Text(
                        if (language == Language.DE)
                            "Rechenhilfe für Fachkräfte. Herstellerangaben, Normen, Anlagenplanung und reale Messwerte haben Vorrang."
                        else
                            "Calculation aid for trained professionals. Manufacturer data, standards, system design and actual measurements take precedence.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.LightGray,
                    )
                }
            }
        }
    }
}

@Composable
private fun Header(language: Language, onLanguage: (Language) -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp)) {
        Text("HydroCalc", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
        Text(
            if (language == Language.DE) "Hydraulik-Rechner für SHK" else "Hydronic calculator for HVAC",
            style = MaterialTheme.typography.bodySmall,
            color = Color.LightGray,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            if (language == Language.DE) Button(onClick = { onLanguage(Language.DE) }) { Text("DE") }
            else OutlinedButton(onClick = { onLanguage(Language.DE) }) { Text("DE") }
            if (language == Language.EN) Button(onClick = { onLanguage(Language.EN) }) { Text("EN") }
            else OutlinedButton(onClick = { onLanguage(Language.EN) }) { Text("EN") }
        }
    }
}

private fun tabTitle(tab: TabMode, language: Language): String = when (tab) {
    TabMode.FLOW -> if (language == Language.DE) "Volumenstrom" else "Flow"
    TabMode.PRESSURE -> if (language == Language.DE) "Druck" else "Pressure"
    TabMode.PIPE -> if (language == Language.DE) "Rohr" else "Pipe"
    TabMode.KV -> "Kv"
}

@Composable
private fun FlowCalculator(language: Language) {
    var mode by remember { mutableStateOf(FlowMode.FLOW) }
    var power by remember { mutableStateOf("20") }
    var flow by remember { mutableStateOf("860") }
    var deltaT by remember { mutableStateOf("20") }

    CalculatorCard(if (language == Language.DE) "Hydraulischer Grundrechner" else "Hydronic basic calculator") {
        ModeButton(mode == FlowMode.FLOW, if (language == Language.DE) "Volumenstrom berechnen" else "Calculate flow") { mode = FlowMode.FLOW }
        ModeButton(mode == FlowMode.POWER, if (language == Language.DE) "Leistung berechnen" else "Calculate power") { mode = FlowMode.POWER }
        ModeButton(mode == FlowMode.DELTA_T, if (language == Language.DE) "Spreizung berechnen" else "Calculate ΔT") { mode = FlowMode.DELTA_T }

        if (mode != FlowMode.POWER) NumberField(if (language == Language.DE) "Leistung kW" else "Heat output kW", power) { power = it }
        if (mode != FlowMode.FLOW) NumberField(if (language == Language.DE) "Volumenstrom l/h" else "Flow l/h", flow) { flow = it }
        if (mode != FlowMode.DELTA_T) NumberField(if (language == Language.DE) "Spreizung ΔT K" else "Temperature difference ΔT K", deltaT) { deltaT = it }

        when (mode) {
            FlowMode.FLOW -> {
                val result = HydroCalculator.flowLitersPerHour(power.number(), deltaT.number())
                if (result != null) {
                    ResultLine(if (language == Language.DE) "Volumenstrom" else "Flow", "${fmt(result)} l/h")
                    ResultLine(if (language == Language.DE) "Volumenstrom" else "Flow", "${fmt(result / 60.0)} l/min")
                    ResultLine(if (language == Language.DE) "Volumenstrom" else "Flow", "${fmt(result / 1000.0, 3)} m³/h")
                } else InvalidText(language)
            }
            FlowMode.POWER -> HydroCalculator.powerKW(flow.number(), deltaT.number())?.let {
                ResultLine(if (language == Language.DE) "Leistung" else "Heat output", "${fmt(it)} kW")
            } ?: InvalidText(language)
            FlowMode.DELTA_T -> HydroCalculator.deltaT(power.number(), flow.number())?.let {
                ResultLine(if (language == Language.DE) "Spreizung" else "Temperature difference", "${fmt(it)} K")
            } ?: InvalidText(language)
        }
    }
}

@Composable
private fun PressureConverter(language: Language) {
    var unit by remember { mutableStateOf(PressureUnit.BAR) }
    var input by remember { mutableStateOf("1") }
    val value = input.number()
    val bar = when (unit) {
        PressureUnit.BAR -> value
        PressureUnit.KPA -> value / 100.0
        PressureUnit.MBAR -> value / 1000.0
        PressureUnit.MWS -> value / 10.19716213
        PressureUnit.PSI -> value / 14.5037738
    }

    CalculatorCard(if (language == Language.DE) "Druck umrechnen" else "Pressure converter") {
        PressureUnit.entries.forEach { item ->
            ModeButton(unit == item, item.name.lowercase().replace("mws", "mWS").replace("kpa", "kPa")) { unit = item }
        }
        NumberField(if (language == Language.DE) "Wert" else "Value", input) { input = it }
        if (value >= 0) {
            ResultLine("bar", fmt(bar, 4))
            ResultLine("kPa", fmt(bar * 100.0))
            ResultLine("mbar", fmt(bar * 1000.0, 1))
            ResultLine("mWS", fmt(bar * 10.19716213, 3))
            ResultLine("psi", fmt(bar * 14.5037738))
        } else InvalidText(language)
    }
}

@Composable
private fun PipeCalculator(language: Language) {
    var reverse by remember { mutableStateOf(false) }
    var flow by remember { mutableStateOf("1000") }
    var diameter by remember { mutableStateOf("28") }
    var velocity by remember { mutableStateOf("0,5") }

    CalculatorCard(if (language == Language.DE) "Rohr / Geschwindigkeit" else "Pipe / velocity") {
        ModeButton(!reverse, if (language == Language.DE) "Geschwindigkeit berechnen" else "Calculate velocity") { reverse = false }
        ModeButton(reverse, if (language == Language.DE) "Innendurchmesser berechnen" else "Calculate inside diameter") { reverse = true }
        NumberField(if (language == Language.DE) "Volumenstrom l/h" else "Flow l/h", flow) { flow = it }
        if (reverse) {
            NumberField(if (language == Language.DE) "Zielgeschwindigkeit m/s" else "Target velocity m/s", velocity) { velocity = it }
            HydroCalculator.innerDiameterMM(flow.number(), velocity.number())?.let {
                ResultLine(if (language == Language.DE) "Innendurchmesser" else "Inside diameter", "${fmt(it)} mm")
            } ?: InvalidText(language)
        } else {
            NumberField(if (language == Language.DE) "Innendurchmesser mm" else "Inside diameter mm", diameter) { diameter = it }
            HydroCalculator.velocity(flow.number(), diameter.number())?.let {
                ResultLine(if (language == Language.DE) "Geschwindigkeit" else "Velocity", "${fmt(it, 3)} m/s")
            } ?: InvalidText(language)
        }
    }
}

@Composable
private fun KvCalculator(language: Language) {
    var reverse by remember { mutableStateOf(false) }
    var flow by remember { mutableStateOf("2,5") }
    var dp by remember { mutableStateOf("0,2") }
    var kv by remember { mutableStateOf("5,6") }

    CalculatorCard("Kv / Δp") {
        ModeButton(!reverse, if (language == Language.DE) "Kv berechnen" else "Calculate Kv") { reverse = false }
        ModeButton(reverse, if (language == Language.DE) "Differenzdruck berechnen" else "Calculate differential pressure") { reverse = true }
        NumberField(if (language == Language.DE) "Volumenstrom m³/h" else "Flow m³/h", flow) { flow = it }
        if (reverse) {
            NumberField("Kv", kv) { kv = it }
            HydroCalculator.differentialPressureBar(flow.number(), kv.number())?.let {
                ResultLine(if (language == Language.DE) "Differenzdruck" else "Differential pressure", "${fmt(it, 3)} bar")
            } ?: InvalidText(language)
        } else {
            NumberField(if (language == Language.DE) "Differenzdruck bar" else "Differential pressure bar", dp) { dp = it }
            HydroCalculator.kv(flow.number(), dp.number())?.let {
                ResultLine("Kv", fmt(it, 3))
            } ?: InvalidText(language)
        }
    }
}

@Composable
private fun ProGate(language: Language, activity: Activity, billing: BillingManager) {
    CalculatorCard("HydroCalc Pro") {
        Text(
            if (language == Language.DE)
                "Strömungsgeschwindigkeit, Rohrinnendurchmesser und Kv/Δp dauerhaft freischalten. Einmaliger Kauf, kein Abo."
            else
                "Permanently unlock flow velocity, inside diameter and Kv/Δp calculators. One-time purchase, no subscription."
        )
        Button(onClick = { billing.launchPurchase(activity) }, enabled = billing.billingReady, modifier = Modifier.fillMaxWidth()) {
            val price = billing.productPrice?.let { " · $it" } ?: ""
            Text(if (language == Language.DE) "Pro freischalten$price" else "Unlock Pro$price")
        }
        OutlinedButton(onClick = billing::restorePurchases, modifier = Modifier.fillMaxWidth()) {
            Text(if (language == Language.DE) "Käufe wiederherstellen" else "Restore purchases")
        }
    }
}

@Composable
private fun ModeButton(selected: Boolean, title: String, onClick: () -> Unit) {
    if (selected) Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) { Text(title) }
    else OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) { Text(title) }
}

@Composable
private fun CalculatorCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black)
            content()
        }
    }
}

@Composable
private fun NumberField(label: String, value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = { next -> if (next.all { it.isDigit() || it == ',' || it == '.' || it == '-' }) onValueChange(next) },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun ResultLine(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Color.LightGray)
        Text(value, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun InvalidText(language: Language) {
    Text(if (language == Language.DE) "Eingaben prüfen." else "Check inputs.", color = MaterialTheme.colorScheme.error)
}

private fun String.number(): Double = replace(',', '.').toDoubleOrNull() ?: 0.0
private fun fmt(value: Double, digits: Int = 2): String = String.format(Locale.GERMANY, "%.${digits}f", value)
