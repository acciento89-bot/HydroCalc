# Saved circuit projects Implementation Plan
> **For agentic workers:** Use superpowers:executing-plans inline; root owns every compile/test/native workload.
**Goal:** Save and compare multi-circuit heating-water projects with shareable worksheet.
**Architecture:** Foundation value models and atomic versioned JSON storage, ObservableObject adapter and native SwiftUI forms. Existing calculator formula remains untouched.
**Tech Stack:** Swift5, SwiftUI, Foundation, iOS17.
**Spec:** ../specs/2026-10-21-circuit-projects-design.md

## Global Constraints
Separate de.kamilunavo.hydrocalc identity and existing StoreKit products preserved. No real transactions. No simulator or compile without root grant. No invented certification/pump claim. No push/merge. DE/EN support.

## Review Focus
- Nonfinite/zero/negative inputs: nil flow and explicit invalid count.
- Baseline value-copy remains independent of subsequent edits.
- Corrupt/future files stay intact and block editing.
- Failed save retains previous bytes and published state.
- Compact/large accessibility forms need native root validation.

### Task 1: Domain and storage
Files: Tests/ProjectTests.swift, HydroCalc/HydroProjects.swift.
Interfaces: HydroCircuit.flowLh; HydroProject.totals/groupTotals/captureBaseline/worksheet(language:); HydroProjectStorage.load/save.
- [x] Write deterministic assertions for golden 11.63kW/10K=1000l/h, invalids, grouping, baseline, bilingual report, reload and migration.
- [x] Root runs RED: swiftc HydroCalc/HydroCalculator.swift HydroCalc/HydroProjects.swift Tests/ProjectTests.swift -o /tmp/hydrocalc-project-tests && /tmp/hydrocalc-project-tests
- [x] Implement model/storage only after observed RED.
- [x] Root runs GREEN same command; retain receipt.

### Task 2: Native project UI
Files: HydroCalc/ProjectStore.swift, ProjectViews.swift, HydroCalcApp.swift, ContentView.swift, both Localizable.strings, existing pbxproj.
Interfaces: ProjectStore owns persisted project list and recoverable error; views mutate through save-before-publish methods.
- [x] Add app-owned store, list/detail/editor, comparisons and ShareLink text.
- [x] Add DE/EN keys and exact pbxproj file references without regeneration.
- [ ] Root validates generic simulator compile and native workflows serially; no source-only Duo claim.

### Task 3: Handoff
- [ ] Review diff, unchanged product/entitlements/formulas, persistence and report edge cases.
- [ ] Record draft ASO, exact evidence/limits/native QA in per-app artifact folder.
- [ ] Commit after root verification, no push.

### Task 4: Android parity — added by root after iOS source handoff
Files: android/app/src/test/java/de/kamilunavo/hydrocalc/HydroProjectsTest.kt; android/app/src/main/java/de/kamilunavo/hydrocalc/HydroProjects.kt and ProjectScreen.kt; MainActivity.kt; app/build.gradle.kts test-only JSON dependency.
Interfaces: equivalent HydroCircuit/Project/Baseline/Totals; HydroProjectCodec and HydroProjectStorage(File). ProjectScreen(activity,language,onBack) owns persistent project flow and saveable drafts.
- [x] Write golden/invalid/baseline/group/report/storage/migration tests before new Kotlin behavior.
- [x] Root Gradle testDebugUnitTest targeted RED, absent domain symbols.
- [x] Implement Kotlin model/codec/atomic file storage; immutable copy baseline; same numeric assumptions.
- [ ] Root targeted GREEN then complete Compose list/detail/editor, baseline/deletion dialogs, ACTION_SEND and local errors/retry.
- [ ] Root entire unit suite and assembleDebug; native DE/EN/rotation/cold-restart/share QA later serially.
- [ ] Preserve historical workflow/signing/package/version/IAP; no dispatch/upload/push.

### Peer review fixes
- [x] Fresh MAG review twoP2 accepted and tests written first. Root regressionRED exit133, then fix archive revalidation+duplicate identity checks, root core-review-green.log exit0.
