package de.kamilunavo.hydrocalc

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val billing = remember { BillingManager(applicationContext) }
            HydroCalcRoot(activity = this, billing = billing)
        }
    }
}

private enum class HydroScreen { HOME, FLOW, PRESSURE, PIPE, KV, PRO }
private enum class FlowMode { FLOW, POWER, DELTA_T }
private enum class PressureUnit { BAR, KPA, MBAR, MWS, PSI }

@Composable
private fun HydroCalcRoot(activity: Activity, billing: BillingManager) {
    var language by remember { mutableStateOf(AppLanguage.DE) }
    var screen by remember { mutableStateOf(HydroScreen.HOME) }

    BackHandler(enabled = screen != HydroScreen.HOME) { screen = HydroScreen.HOME }

    HydroTheme {
        Scaffold(
            containerColor = Hydro950,
            contentWindowInsets = WindowInsets.safeDrawing,
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color(0xFF0A2230), Hydro950, Color(0xFF041016)),
                        ),
                    )
                    .padding(padding),
            ) {
                Column(Modifier.fillMaxSize()) {
                    BrandBar(language, billing.isPro) { language = it }
                    when (screen) {
                        HydroScreen.HOME -> HomeScreen(language, billing) { destination ->
                            screen = when {
                                destination == HydroScreen.FLOW -> HydroScreen.FLOW
                                destination == HydroScreen.PRESSURE -> HydroScreen.PRESSURE
                                destination == HydroScreen.PIPE && billing.isPro -> HydroScreen.PIPE
                                destination == HydroScreen.KV && billing.isPro -> HydroScreen.KV
                                else -> HydroScreen.PRO
                            }
                        }
                        HydroScreen.FLOW -> FlowCalculator(language) { screen = HydroScreen.HOME }
                        HydroScreen.PRESSURE -> PressureConverter(language) { screen = HydroScreen.HOME }
                        HydroScreen.PIPE -> PipeCalculator(language) { screen = HydroScreen.HOME }
                        HydroScreen.KV -> KvCalculator(language) { screen = HydroScreen.HOME }
                        HydroScreen.PRO -> ProGate(language, activity, billing) { screen = HydroScreen.HOME }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeScreen(language: AppLanguage, billing: BillingManager, onOpen: (HydroScreen) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 18.dp)
            .padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HeroPanel(language)
        SectionEyebrow(if (language == AppLanguage.DE) "RECHNER" else "CALCULATORS")
        ToolCard(
            code = "Q",
            title = if (language == AppLanguage.DE) "Volumenstrom" else "Flow",
            subtitle = if (language == AppLanguage.DE)
                "Leistung, Volumenstrom und Spreizung flexibel berechnen."
            else
                "Calculate output, flow and temperature spread.",
            accent = Aqua,
            onClick = { onOpen(HydroScreen.FLOW) },
        )
        ToolCard(
            code = "Δp",
            title = if (language == AppLanguage.DE) "Druck umrechnen" else "Pressure conversion",
            subtitle = if (language == AppLanguage.DE)
                "bar, kPa, mbar, mWS und psi sofort vergleichen."
            else
                "Compare bar, kPa, mbar, mH₂O and psi instantly.",
            accent = WaterBlue,
            onClick = { onOpen(HydroScreen.PRESSURE) },
        )
        ToolCard(
            code = "DN",
            title = if (language == AppLanguage.DE) "Rohr & Geschwindigkeit" else "Pipe & velocity",
            subtitle = if (language == AppLanguage.DE)
                "Geschwindigkeit oder Innendurchmesser bestimmen."
            else
                "Calculate velocity or required inside diameter.",
            accent = AquaSoft,
            locked = !billing.isPro,
            onClick = { onOpen(HydroScreen.PIPE) },
        )
        ToolCard(
            code = "Kv",
            title = "Kv / Δp",
            subtitle = if (language == AppLanguage.DE)
                "Ventilkennwert und Differenzdruck sauber auslegen."
            else
                "Size valve coefficient and differential pressure.",
            accent = Color(0xFF7DD3FC),
            locked = !billing.isPro,
            onClick = { onOpen(HydroScreen.KV) },
        )

        if (!billing.isPro) {
            ProStrip(language, billing.productPrice) { onOpen(HydroScreen.PRO) }
            TextButton(
                onClick = billing::restorePurchases,
                modifier = Modifier.align(Alignment.CenterHorizontally),
                colors = ButtonDefaults.textButtonColors(contentColor = Text300),
            ) {
                Text(if (language == AppLanguage.DE) "Käufe wiederherstellen" else "Restore purchases")
            }
        }
        billing.statusMessage?.let { StatusBanner(it) }
        NoteCard(
            if (language == AppLanguage.DE)
                "Rechenhilfe für Fachkräfte. Herstellerangaben, Normen, Anlagenplanung und reale Messwerte haben immer Vorrang."
            else
                "Calculation aid for trained professionals. Manufacturer data, standards, system design and actual measurements always take precedence.",
        )
    }
}

@Composable
private fun FlowCalculator(language: AppLanguage, onBack: () -> Unit) {
    var mode by remember { mutableStateOf(FlowMode.FLOW) }
    var power by remember { mutableStateOf("20") }
    var flow by remember { mutableStateOf("860") }
    var deltaT by remember { mutableStateOf("20") }

    ToolScreen(
        code = "Q",
        accent = Aqua,
        title = if (language == AppLanguage.DE) "Volumenstrom" else "Hydronic flow",
        subtitle = if (language == AppLanguage.DE) "Drei Größen, ein übersichtlicher Rechenweg." else "Three values, one clear calculation path.",
        backLabel = if (language == AppLanguage.DE) "Rechner" else "Calculators",
        onBack = onBack,
    ) {
        InputCard(if (language == AppLanguage.DE) "Gesuchte Größe" else "Target value") {
            ChoiceSelector(
                options = listOf(
                    if (language == AppLanguage.DE) "Volumen" else "Flow",
                    if (language == AppLanguage.DE) "Leistung" else "Output",
                    if (language == AppLanguage.DE) "Spreizung" else "Delta T",
                ),
                selectedIndex = mode.ordinal,
                onSelected = { mode = FlowMode.entries[it] },
            )
        }
        InputCard(if (language == AppLanguage.DE) "Eingabewerte" else "Input values") {
            if (mode != FlowMode.POWER) NumberField(if (language == AppLanguage.DE) "Leistung" else "Heat output", "kW", power) { power = it }
            if (mode != FlowMode.FLOW) NumberField(if (language == AppLanguage.DE) "Volumenstrom" else "Flow", "l/h", flow) { flow = it }
            if (mode != FlowMode.DELTA_T) NumberField(if (language == AppLanguage.DE) "Spreizung" else "Temperature difference", "ΔT K", deltaT) { deltaT = it }
        }

        when (mode) {
            FlowMode.FLOW -> {
                val result = HydroCalculator.flowLitersPerHour(power.number(), deltaT.number())
                if (result != null) {
                    ResultPanel(
                        if (language == AppLanguage.DE) "VOLUMENSTROM" else "FLOW",
                        fmt(result),
                        "l/h",
                        listOf(
                            Metric(if (language == AppLanguage.DE) "Pro Minute" else "Per minute", fmt(result / 60.0), "l/min"),
                            Metric(if (language == AppLanguage.DE) "Pro Stunde" else "Per hour", fmt(result / 1000.0, 3), "m³/h"),
                        ),
                    )
                } else InvalidCard(language)
            }
            FlowMode.POWER -> {
                val result = HydroCalculator.powerKW(flow.number(), deltaT.number())
                if (result != null) {
                    ResultPanel(if (language == AppLanguage.DE) "LEISTUNG" else "OUTPUT", fmt(result), "kW", emptyList())
                } else InvalidCard(language)
            }
            FlowMode.DELTA_T -> {
                val result = HydroCalculator.deltaT(power.number(), flow.number())
                if (result != null) {
                    ResultPanel(if (language == AppLanguage.DE) "SPREIZUNG" else "TEMPERATURE DIFFERENCE", fmt(result), "K", emptyList())
                } else InvalidCard(language)
            }
        }
        NoteCard(if (language == AppLanguage.DE) "Berechnung für Wasser mit dem Faktor 1,163." else "Calculation for water using the factor 1.163.")
    }
}

@Composable
private fun PressureConverter(language: AppLanguage, onBack: () -> Unit) {
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

    ToolScreen(
        code = "Δp",
        accent = WaterBlue,
        title = if (language == AppLanguage.DE) "Druck umrechnen" else "Pressure conversion",
        subtitle = if (language == AppLanguage.DE) "Alle üblichen SHK-Druckeinheiten auf einen Blick." else "All common HVAC pressure units at a glance.",
        backLabel = if (language == AppLanguage.DE) "Rechner" else "Calculators",
        onBack = onBack,
    ) {
        InputCard(if (language == AppLanguage.DE) "Ausgangswert" else "Source value") {
            ChoiceSelector(listOf("bar", "kPa", "mbar", "mWS", "psi"), unit.ordinal) { unit = PressureUnit.entries[it] }
            NumberField(if (language == AppLanguage.DE) "Druck" else "Pressure", pressureUnitLabel(unit), input) { input = it }
        }
        if (value >= 0) {
            ResultPanel(
                eyebrow = if (language == AppLanguage.DE) "BASISWERT" else "BASE VALUE",
                primaryValue = fmt(bar, 4),
                primaryUnit = "bar",
                metrics = listOf(
                    Metric("kPa", fmt(bar * 100.0), "kPa"),
                    Metric("mbar", fmt(bar * 1000.0, 1), "mbar"),
                    Metric("mWS", fmt(bar * 10.19716213, 3), "mWS"),
                    Metric("psi", fmt(bar * 14.5037738), "psi"),
                ),
                accent = WaterBlue,
            )
        } else InvalidCard(language)
    }
}

@Composable
private fun PipeCalculator(language: AppLanguage, onBack: () -> Unit) {
    var reverse by remember { mutableStateOf(false) }
    var flow by remember { mutableStateOf("1000") }
    var diameter by remember { mutableStateOf("28") }
    var velocity by remember { mutableStateOf("0,5") }

    ToolScreen(
        code = "DN",
        accent = AquaSoft,
        title = if (language == AppLanguage.DE) "Rohr & Geschwindigkeit" else "Pipe & velocity",
        subtitle = if (language == AppLanguage.DE) "Strömung und Innendurchmesser passend auslegen." else "Size flow velocity and inside diameter.",
        backLabel = if (language == AppLanguage.DE) "Rechner" else "Calculators",
        onBack = onBack,
    ) {
        InputCard(if (language == AppLanguage.DE) "Gesuchte Größe" else "Target value") {
            ChoiceSelector(
                listOf(if (language == AppLanguage.DE) "Geschwindigkeit" else "Velocity", if (language == AppLanguage.DE) "Durchmesser" else "Diameter"),
                if (reverse) 1 else 0,
            ) { reverse = it == 1 }
        }
        InputCard(if (language == AppLanguage.DE) "Eingabewerte" else "Input values") {
            NumberField(if (language == AppLanguage.DE) "Volumenstrom" else "Flow", "l/h", flow) { flow = it }
            if (reverse) {
                NumberField(if (language == AppLanguage.DE) "Zielgeschwindigkeit" else "Target velocity", "m/s", velocity) { velocity = it }
            } else {
                NumberField(if (language == AppLanguage.DE) "Innendurchmesser" else "Inside diameter", "mm", diameter) { diameter = it }
            }
        }
        if (reverse) {
            val result = HydroCalculator.innerDiameterMM(flow.number(), velocity.number())
            if (result != null) ResultPanel(
                if (language == AppLanguage.DE) "INNENDURCHMESSER" else "INSIDE DIAMETER",
                fmt(result),
                "mm",
                emptyList(),
                AquaSoft,
            ) else InvalidCard(language)
        } else {
            val result = HydroCalculator.velocity(flow.number(), diameter.number())
            if (result != null) ResultPanel(
                if (language == AppLanguage.DE) "GESCHWINDIGKEIT" else "VELOCITY",
                fmt(result, 3),
                "m/s",
                emptyList(),
                AquaSoft,
            ) else InvalidCard(language)
        }
    }
}

@Composable
private fun KvCalculator(language: AppLanguage, onBack: () -> Unit) {
    var reverse by remember { mutableStateOf(false) }
    var flow by remember { mutableStateOf("2,5") }
    var dp by remember { mutableStateOf("0,2") }
    var kv by remember { mutableStateOf("5,6") }

    ToolScreen(
        code = "Kv",
        accent = Color(0xFF7DD3FC),
        title = "Kv / Δp",
        subtitle = if (language == AppLanguage.DE) "Ventilkennwert oder Differenzdruck bestimmen." else "Calculate valve coefficient or differential pressure.",
        backLabel = if (language == AppLanguage.DE) "Rechner" else "Calculators",
        onBack = onBack,
    ) {
        InputCard(if (language == AppLanguage.DE) "Gesuchte Größe" else "Target value") {
            ChoiceSelector(listOf("Kv", "Δp"), if (reverse) 1 else 0) { reverse = it == 1 }
        }
        InputCard(if (language == AppLanguage.DE) "Eingabewerte" else "Input values") {
            NumberField(if (language == AppLanguage.DE) "Volumenstrom" else "Flow", "m³/h", flow) { flow = it }
            if (reverse) NumberField("Kv", "", kv) { kv = it }
            else NumberField(if (language == AppLanguage.DE) "Differenzdruck" else "Differential pressure", "bar", dp) { dp = it }
        }
        if (reverse) {
            val result = HydroCalculator.differentialPressureBar(flow.number(), kv.number())
            if (result != null) ResultPanel(
                if (language == AppLanguage.DE) "DIFFERENZDRUCK" else "DIFFERENTIAL PRESSURE",
                fmt(result, 3),
                "bar",
                emptyList(),
                Color(0xFF7DD3FC),
            ) else InvalidCard(language)
        } else {
            val result = HydroCalculator.kv(flow.number(), dp.number())
            if (result != null) ResultPanel("KV-WERT", fmt(result, 3), "Kv", emptyList(), Color(0xFF7DD3FC))
            else InvalidCard(language)
        }
    }
}

@Composable
private fun ProGate(language: AppLanguage, activity: Activity, billing: BillingManager, onBack: () -> Unit) {
    ToolScreen(
        code = "PRO",
        accent = Aqua,
        title = "HydroCalc Pro",
        subtitle = if (language == AppLanguage.DE) "Mehr Hydraulik. Einmal kaufen. Dauerhaft nutzen." else "More hydronics. One purchase. Yours permanently.",
        backLabel = if (language == AppLanguage.DE) "Rechner" else "Calculators",
        onBack = onBack,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.linearGradient(listOf(Color(0xFF0B3D3B), Color(0xFF102C3B))), RoundedCornerShape(26.dp))
                .border(1.dp, Aqua.copy(alpha = 0.45f), RoundedCornerShape(26.dp))
                .padding(22.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                SectionEyebrow(if (language == AppLanguage.DE) "DAUERHAFTE FREISCHALTUNG" else "PERMANENT UNLOCK")
                Text(
                    if (language == AppLanguage.DE) "Rohrdimensionierung und Kv/Δp im selben Workflow." else "Pipe sizing and Kv/Δp in the same workflow.",
                    style = MaterialTheme.typography.headlineMedium,
                )
                FeatureLine(if (language == AppLanguage.DE) "Geschwindigkeit und Innendurchmesser" else "Velocity and inside diameter")
                FeatureLine(if (language == AppLanguage.DE) "Kv-Wert und Differenzdruck" else "Kv value and differential pressure")
                FeatureLine(if (language == AppLanguage.DE) "Kein Abo und kein Konto" else "No subscription and no account")
                PrimaryAction(
                    label = if (language == AppLanguage.DE)
                        "Pro freischalten${billing.productPrice?.let { " · $it" } ?: ""}"
                    else
                        "Unlock Pro${billing.productPrice?.let { " · $it" } ?: ""}",
                    enabled = billing.billingReady,
                ) { billing.launchPurchase(activity) }
                OutlinedButton(
                    onClick = billing::restorePurchases,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(15.dp),
                    border = BorderStroke(1.dp, HydroLine),
                ) {
                    Text(if (language == AppLanguage.DE) "Käufe wiederherstellen" else "Restore purchases")
                }
            }
        }
        billing.statusMessage?.let { StatusBanner(it) }
    }
}

@Composable
private fun ToolScreen(
    code: String,
    accent: Color,
    title: String,
    subtitle: String,
    backLabel: String,
    onBack: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp).padding(bottom = 34.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        TextButton(onClick = onBack, colors = ButtonDefaults.textButtonColors(contentColor = Text300)) {
            Text("←  $backLabel")
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            CodeTile(code, accent)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title, style = MaterialTheme.typography.headlineMedium)
                Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Text300)
            }
        }
        Spacer(Modifier.height(2.dp))
        content()
    }
}

@Composable
private fun ProStrip(language: AppLanguage, price: String?, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = Aqua.copy(alpha = 0.10f),
        shape = RoundedCornerShape(19.dp),
        border = BorderStroke(1.dp, Aqua.copy(alpha = 0.30f)),
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatusPill("PRO", Aqua)
            Column(Modifier.weight(1f)) {
                Text(if (language == AppLanguage.DE) "Alle Profi-Rechner" else "All professional calculators", fontWeight = FontWeight.Bold)
                Text(
                    if (language == AppLanguage.DE) "Einmalkauf${price?.let { " · $it" } ?: ""}" else "One-time purchase${price?.let { " · $it" } ?: ""}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Text300,
                )
            }
            Text("›", color = Aqua, fontSize = 26.sp)
        }
    }
}

@Composable
private fun FeatureLine(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(7.dp).background(Aqua, CircleShape))
        Text(text, style = MaterialTheme.typography.bodyLarge, color = Text300)
    }
}

@Composable
private fun InvalidCard(language: AppLanguage) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.error.copy(alpha = 0.10f),
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.30f)),
    ) {
        Text(
            if (language == AppLanguage.DE) "Bitte Eingabewerte prüfen." else "Please check the input values.",
            color = MaterialTheme.colorScheme.error,
            modifier = Modifier.padding(16.dp),
        )
    }
}

private fun pressureUnitLabel(unit: PressureUnit): String = when (unit) {
    PressureUnit.BAR -> "bar"
    PressureUnit.KPA -> "kPa"
    PressureUnit.MBAR -> "mbar"
    PressureUnit.MWS -> "mWS"
    PressureUnit.PSI -> "psi"
}

private fun String.number(): Double = replace(',', '.').toDoubleOrNull() ?: 0.0
private fun fmt(value: Double, digits: Int = 2): String = String.format(Locale.GERMANY, "%.${digits}f", value)
