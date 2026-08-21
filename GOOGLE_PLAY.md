# HydroCalc — Google Play release metadata

## Android identity

- App name: HydroCalc
- Application ID: `de.kamilunavo.hydrocalc`
- Version name: `1.0.0`
- Version code: `1`
- Category: Tools
- Target SDK: Android 16 / API 36
- Minimum SDK: API 26
- Distribution: Android App Bundle (`.aab`)

## Google Play Billing

- Product: HydroCalc Pro
- Product ID: `de.kamilunavo.hydrocalc.pro`
- Type: one-time product / permanent entitlement
- Intended base price: EUR 4.99
- Unlocks: velocity/diameter and Kv/differential-pressure calculators

## German listing

### Short description
Hydraulik-Rechner für Volumenstrom, Spreizung, Druck, Rohrgeschwindigkeit und Kv.

### Full description
HydroCalc ist eine kompakte Rechenhilfe für Heizungs-, SHK- und Servicetechniker.

Funktionen:
- Leistung, Volumenstrom oder Spreizung aus den jeweils anderen beiden Werten berechnen
- Volumenstrom in l/h, l/min und m³/h anzeigen
- bar, kPa, mbar, mWS und psi umrechnen
- Deutsch und Englisch
- Offline nutzbar

HydroCalc Pro schaltet zusätzliche Hydraulik-Rechner dauerhaft mit einem einmaligen In-App-Kauf frei:
- Strömungsgeschwindigkeit aus Volumenstrom und Innendurchmesser
- Erforderlicher Innendurchmesser aus Volumenstrom und Zielgeschwindigkeit
- Kv-Wert aus Volumenstrom und Differenzdruck
- Differenzdruck aus Volumenstrom und Kv-Wert

Wichtiger Hinweis:
HydroCalc ist eine Rechenhilfe für fachkundige Anwender. Herstellerangaben, geltende Normen, Anlagenplanung und reale Messwerte haben immer Vorrang.

## English listing

### Short description
Hydronic flow, delta T, pressure, pipe velocity and Kv calculator for HVAC pros.

### Full description
HydroCalc is a compact calculation aid for heating, HVAC and service technicians.

Features:
- Calculate heat output, flow or temperature difference from the other two values
- Show flow in l/h, l/min and m³/h
- Convert bar, kPa, mbar, mH₂O and psi
- German and English
- Works offline

HydroCalc Pro permanently unlocks additional hydronic calculators with a one-time in-app purchase:
- Flow velocity from flow and inside diameter
- Required inside diameter from flow and target velocity
- Kv value from flow and differential pressure
- Differential pressure from flow and Kv

Important:
HydroCalc is a calculation aid for trained professionals. Manufacturer data, applicable standards, system design and actual measurements always take precedence.

## URLs

- Support: `https://kamilunavo.com/support`
- Privacy: `https://kamilunavo.com/hydrocalc/privacy`

## Data safety

No account, ads, analytics, tracking or Kamilunavo backend. Calculation inputs remain on device. Google Play Billing is used only for the optional Pro entitlement.

## Release gates

- [ ] Create Play Console app for `de.kamilunavo.hydrocalc`.
- [ ] Create one-time product `de.kamilunavo.hydrocalc.pro` at intended price/availability.
- [ ] Complete App content, audience, ads declaration and Data safety.
- [ ] Upload signed AAB to testing track.
- [ ] Verify Pro purchase, entitlement persistence and restore with a licensed tester.
- [ ] Satisfy any closed-testing requirement attached to the developer account.
- [ ] Promote to production when all gates are green.
