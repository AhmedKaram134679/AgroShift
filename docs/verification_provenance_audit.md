# Final Provenance and Scientific Evidence Consistency Audit Report
## Repository: AhmedKaram134679/AgroShift

**Audit Date:** 2026-10-28T00:00:00Z (2026-10-28T03:00:00+03:00)  
**Auditor Roles:** Senior Git Provenance Engineer, Flutter/Dart Verification Auditor, PowerShell Test Infrastructure Reviewer, Scientific Evidence Documentation Specialist  
**Primary Branch:** `main`  
**Governing Standard:** Antigravity Audit and Scientific Evidence Consistency Protocol  

---

## 1. Executive Summary

This formal audit report reconciles Git provenance, verification runner evidence, saved test outputs, and documented scientific claims across repository `AhmedKaram134679/AgroShift`.

### Key Audit Conclusions & Resolved Inconsistencies
1. **Resolution of Published Commit & Clean Execution Provenance:**
   - Commit `ef07cda22024f952d061f5f1c2fa96d2383475b3` was the clean execution revision tested by run `20261027_095914`.
   - Commit `60f1adfd18987e1038d90039fce413494efce434` published the initial 21 evidence files and audit documentation.
   - Commit `25438d0e9ab725dce5788f52e1ef7056c30237ea` is the **latest published commit on `origin/main`**, incorporating the initial documentation and provenance audit reconciliation.
   - Run `20261028_024200` was executed cleanly against published commit `25438d0e9ab725dce5788f52e1ef7056c30237ea` from an isolated clean worktree with `-RequireCleanRevision`, achieving `OverallStatus = PASS`.
2. **Provenance Separation Established:** Verification summaries accurately record distinct fields for starting Git HEAD, ending Git HEAD, initial working-tree cleanliness, final working-tree cleanliness, initial and final source-tree fingerprints, and source mutation during the run.
3. **Fingerprint vs. Cleanliness Fallacy Resolved:** A stable composite source-tree fingerprint ($SHA\text{-}256$) establishes solely that monitored files (`lib/`, `test/`, `scripts/`, `docs/`, `pubspec.yaml`, `pubspec.lock`) did not mutate between initial and final measurements during the run (`SourceTreeMutatedDuringRun = false`). It does **not** prove that the starting working tree was clean.
4. **Historical Runs Reconciled:**
   - Run `20261026_132450` tested a modified working tree over `84eec0c` (55 det. + 1 live = 56 passed; 158 Flutter tests).
   - Run `20261027_070738` tested a modified working tree over `c9d7b52` (55 det. + 1 live = 56 passed; 158 Flutter tests).
   - Run `20261027_075935` tested a modified working tree over `868aa97` (67 det. + 1 live = 68 passed; 159 Flutter tests).
   - Run `20261027_095914` tested a **Clean Committed Revision (`ef07cda22024f952d061f5f1c2fa96d2383475b3`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; published in commit `60f1adf`).
   - Run `20261028_024200` tested a **Clean Committed Revision (`25438d0e9ab725dce5788f52e1ef7056c30237ea`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; local evidence).
5. **Exact Flutter Test Count Reconciled (159 vs. 158):** The saved Flutter test logs in runs `20261027_075935`, `20261027_095914`, and `20261028_024200` conclude with `+159: All tests passed!`:
   - `test/domain/domain_scientific_test.dart`: **47 passed**
   - `test/data/open_meteo_adapter_test.dart`: **42 passed**
   - `test/data/persistence_test.dart`: **63 passed**
   - `test/widget_test.dart`: **7 passed**
   - **Total Discovered and Executed Tests:** $47 + 42 + 63 + 7 = \mathbf{159}$.
6. **Scientific Baseline Preserved:** Crop evapotranspiration arithmetic ($ET_c = K_c \times ET_0$) is validated (`PASS`), volumetric delta is confirmed as approximately $83.3\text{ L}$ per feddan per $100\text{ mm}$, client-side FAO-56 Penman-Monteith recomputation remains `INCOMPLETE`, ground-truth field calibration across Egypt remains `DEFERRED`, and physical Android migration remains `DEFERRED`.

---

## 2. Repository and Commit Provenance

| Property | Verified Value | Evidence Source |
| :--- | :--- | :--- |
| **Repository Root** | `D:\Programming projects\agro_shift` | Git filesystem root |
| **Primary Branch** | `main` | `git rev-parse --abbrev-ref HEAD` |
| **Previously Tested Execution Commit** | `ef07cda22024f952d061f5f1c2fa96d2383475b3` | `artifacts/validation_runs/20261027_095914/verification_summary.json` |
| **Historical Evidence Publication Commit** | `60f1adfd18987e1038d90039fce413494efce434` (`60f1adf`) | `git log -1 60f1adf` (published 21 evidence files) |
| **Latest Published Commit on `origin/main`** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | `git rev-parse origin/main` |
| **Current Local Branch HEAD** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | `git rev-parse HEAD` |
| **New Verification Execution Commit** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | `artifacts/validation_runs/20261028_024200/verification_summary.json` |
| **New Evidence Publication Commit** | `LOCAL ONLY — NOT YET PUBLISHED` | Local directory `artifacts/validation_runs/20261028_024200` |

---

## 3. Comprehensive Provenance Reconciliation Table Across All Runs

| Field | Run `20261026_132450` | Run `20261027_070738` | Run `20261027_075935` | Run `20261027_095914` | Run `20261028_024200` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Run ID** | `20261026_132450` | `20261027_070738` | `20261027_075935` | `20261027_095914` | `20261028_024200` |
| **Tested HEAD Commit** | `84eec0c27d912dc` | `c9d7b5296731981` | `868aa9766d94934` | `ef07cda22024f95` | `25438d0e9ab725d` |
| **Baseline Relationship** | Modified Working Tree | Modified Working Tree | Modified Working Tree | Clean Committed Revision | **Clean Committed Revision** |
| **Initial Working-Tree State** | Modified (`false`) | Modified (`false`) | Modified (`false`) | **Clean (`true`)** | **Clean (`true`)** |
| **Final Working-Tree State** | Modified (`false`) | Modified (`false`) | Modified (`false`) | Modified (`false`) (run artifacts) | **Clean (`true`)** (isolated worktree) |
| **Monitored Scope** | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` |
| **Monitored File Count** | 70 | 72 | 73 | 73 | 74 |
| **Initial Fingerprint** | `ed096c44f379be...` | `061bc7311ca4d9...` | `41cc307590b926...` | `41cc307590b926...` | `07bafeea427812...` |
| **Final Fingerprint** | `ed096c44f379be...` | `061bc7311ca4d9...` | `41cc307590b926...` | `41cc307590b926...` | `07bafeea427812...` |
| **Source Mutation Detected** | `false` | `false` | `false` | `false` | `false` |
| **PowerShell Checks** | 56 / 56 passed | 56 / 56 passed | 68 / 68 passed | 68 / 68 passed | **68 / 68 passed** |
| **Flutter Test Result** | 158 passed | 158 passed | 159 passed | 159 passed | **159 passed** |
| **Release Build Result** | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | **Exit 0 (APK built)** |
| **Evidence Directory** | `20261026_132450` | `20261027_070738` | `20261027_075935` | `20261027_095914` | `20261028_024200` |
| **Evidence Availability** | Verified (Local disk) | Verified (Local disk) | Verified (Local disk) | **Published (`60f1adf`, 21 files)** | **Local Only (`20261028_024200`)** |
| **Material Limitations** | Modified tree run | Modified tree run | Modified tree run | Initial clean; ending dirty | Clean execution over `25438d0` |

---

## 4. Test Seam and Process-Cleanup Limitations

1. **Test 49 (Output-Reader Initialization Failure):**
   - Implemented in `test/scripts/test_validate_historical_models.ps1` (lines 912–954).
   - Injects a simulated exception via environment variable `AGROSHIFT_TEST_FAIL_READER_INIT` inside `Run-Stage` before `$p.StandardOutput.ReadToEndAsync()`.
   - **Limitation:** Application-level simulation. Verifies that `OutputError` is populated, `LaunchError` remains null, subsequent stages continue executing, and the overall runner exits with code `1`. It does not prove kernel I/O handle exhaustion or hardware memory fault handling.
2. **Process Cleanup and Timeout Logic:**
   - Implemented in `Stop-ProcessTree` within `scripts/record_verification_evidence.ps1`.
   - Uses `taskkill.exe /T /F /PID <pid>` wrapped with `$killProc.WaitForExit(5000)` to prevent unbounded hangs. If `taskkill.exe` fails or times out, it falls back to `$p.Kill()` with a secondary `$p.WaitForExit(5000)`.
   - **Limitation:** Tested deterministically in Tests 58, 59, and 60 (child sleep scripts, simulated utility failure, simulated fallback failure). While proven robust under Windows PowerShell process management, it does not guarantee instant child termination if the underlying process is in an uninterruptible Windows kernel state.

---

## 5. Scientific Baseline & Scope Disclosures

1. **Daily Reference Evapotranspiration ($ET_0$):**
   - Source: Open-Meteo Historical Archive API using ECMWF ERA5 reanalysis (`models=era5`).
   - The application enforces operational range screening $[0.0, 25.0]\text{ mm/day}$ and interval completeness ($\le 10\%$ missingness).
   - **Status:** **`INCOMPLETE`** for independent client-side Penman-Monteith numerical recomputation from raw radiation, temperature, dew point, and wind fields.
2. **Crop Evapotranspiration ($ET_c$):**
   - Formula: $ET_c = K_c \times ET_0$ evaluated daily.
   - **Status:** **`PASS`**, verified against independent hand-calculated numerical oracles.
3. **Volumetric Water Requirement:**
   - Factor: $4.2\text{ m}^3/\text{feddan/mm}$ ($1\text{ Egyptian feddan} = 4,200.833\text{ m}^2$, standardized to $4.2$).
   - Operational conversion: $100\text{ mm} \times 4.2 = 420.0\text{ m}^3/\text{feddan} = 420,000\text{ liters}$.
   - Exact survey area conversion: $100\text{ mm} \times 4,200.833\text{ m}^2 \times 0.001\text{ m/mm} = 420,083.3\text{ liters}$.
   - Delta: approximately $83.3\text{ liters per feddan per } 100\text{ mm}$.
   - **Status:** **`PASS`**, verified mathematically.
4. **Crop Growth Stage Durations ($L_{\text{stage}}$):**
   - Implementation: Four-stage piecewise linear interpolation with fixed $[0.20, 0.30, 0.30, 0.20]$ developmental fraction partitioning.
   - **Status:** **`DOCUMENTED APPROXIMATION`**, adequate for relative rotational comparison, but not an empirical biological schedule.
5. **Ground-Truth Field Calibration:**
   - **Status:** **`DEFERRED`** (in-situ eddy-covariance and lysimeter observations across Egypt are not present in this software repository).

---

## 6. Verification Run Evidence: `20261027_095914` (Published in Commit `60f1adf`)

- **Evidence Directory:** `artifacts/validation_runs/20261027_095914` (21 files published on `origin/main`)
- **Run Start / End (UTC):** `2026-10-27T09:59:14Z` / `2026-10-27T10:01:23Z`
- **Starting HEAD Commit:** `ef07cda22024f952d061f5f1c2fa96d2383475b3`
- **Initial Working Tree State:** Clean (`true`)
- **Initial / Final Fingerprint:** `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6`
- **Validation Scope:** `Clean Committed Revision (ef07cda22024f952d061f5f1c2fa96d2383475b3)`
- **Overall Status:** `PASS`
- **Stages:** Dart Format (0), Flutter Analyze (0), Flutter Tests (0, 159 passed), PowerShell Tests (0, 68 passed), Release Build (0, APK built).

---

## 7. Final Published Provenance Snapshot Reconciliation (Run `20261028_024200`)

Executed directly from an isolated clean checkout of published commit `25438d0e9ab725dce5788f52e1ef7056c30237ea`:

- **Audit Timestamp (UTC):** `2026-10-28T02:47:09Z`
- **Local Branch / Tracking:** `main` at `25438d0e9ab725dce5788f52e1ef7056c30237ea` (up to date with `origin/main`)
- **Execution Commit:** `25438d0e9ab725dce5788f52e1ef7056c30237ea`
- **New Run ID:** `20261028_024200`
- **Evidence Directory:** `artifacts/validation_runs/20261028_024200` (Local only)
- **Initial Working Tree:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Final Working Tree:** Clean (`IsEndingWorkingTreeClean = true`, `EndingWorkingTreeEntries: []`)
- **Initial / Final Fingerprint:** `07bafeea427812dc8875725c5b95d7ee7f59b2d1027a811ecbb06b576f6b369f`
- **Source Mutation:** `false`
- **Validation Scope:** `Clean Committed Revision (25438d0e9ab725dce5788f52e1ef7056c30237ea)`
- **Overall Status:** `PASS`

### Stage Execution Results:

| Stage | Command | Exit Code | Status | Duration | Evidence File |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 3 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 18 s | `flutter_analyze.stdout.txt` (No issues found) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 40 s | `flutter_test.stdout.txt` (159 passed) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 88 s | `powershell_tests.stdout.txt` (67 det. + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 158 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

---

## 8. Final Verdict

**FINAL STATUS: `PASS WITH LIMITATIONS`**

- **Verified Facts:** Clean committed-revision execution was executed against both `ef07cda` (run `20261027_095914`, published in `60f1adf`) and `25438d0` (run `20261028_024200`, local evidence), both passing with exit code 0; test counts are verified as 159 Flutter tests and 68 PowerShell checks; provenance separation is fully established.
- **Explicit Limitations:**
  - Independent client-side calculation of FAO-56 Penman-Monteith remains **`INCOMPLETE`**.
  - Ground-truth field calibration across Egyptian climate zones remains **`DEFERRED`**.
  - Physical Android SQLite migration on a physical handset remains **`DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED`**.
  - Run `20261028_024200` evidence directory is `LOCAL ONLY` and not yet published on GitHub.
