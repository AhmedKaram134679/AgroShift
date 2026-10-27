# Final Provenance and Scientific Evidence Consistency Audit Report
## Repository: AhmedKaram134679/AgroShift

**Audit Date:** 2026-10-27T11:20:00Z (2026-10-27T14:20:00+03:00)  
**Auditor Roles:** Senior Flutter/Dart Quality Engineer, PowerShell Automation Auditor, Git Provenance Specialist, Scientific-Validation Evidence Reviewer  
**Primary Branch:** `main`  
**Governing Standard:** Antigravity Audit and Scientific Evidence Consistency Protocol  

---

## 1. Executive Summary

This formal audit report reconciles Git provenance, verification runner evidence, saved test outputs, and documented scientific claims across repository `AhmedKaram134679/AgroShift`.

### Key Audit Conclusions
1. **Provenance Separation Established:** Verification summaries accurately record distinct fields for starting Git HEAD, ending Git HEAD, initial working-tree cleanliness, final working-tree cleanliness, initial and final source-tree fingerprints, and source mutation during the run.
2. **Fingerprint vs. Cleanliness Fallacy Resolved:** A stable composite source-tree fingerprint ($SHA\text{-}256$) establishes solely that monitored files (`lib/`, `test/`, `scripts/`, `docs/`, `pubspec.yaml`, `pubspec.lock`) did not mutate between initial and final measurements during the run (`SourceTreeMutatedDuringRun = false`). It does **not** prove that the starting working tree was clean.
3. **Historical Run Reconciled:** Run `20261026_132450` was executed on a modified working tree based on commit `84eec0c27d912dc252895432c2f6c2d26e0c32b3`. The saved output in `powershell_tests.stdout.txt` documents **55 deterministic checks passed**, **1 live integration check passed**, for a total of **56 suite checks passed** (exit code `0`). The summary correctly recorded `IsStartingWorkingTreeClean = false` and `ValidationScope = "Modified Working Tree over (84eec0c27d912dc252895432c2f6c2d26e0c32b3)"`.
4. **Current Clean-Revision Run Executed:** Because the repository working tree at commit `ef07cda22024f952d061f5f1c2fa96d2383475b3` was clean and in sync with `origin/main`, a full clean-revision verification run (`-RequireCleanRevision`) was successfully executed under run ID `20261027_095914`. All 5 verification stages passed with exit code `0`, confirming `IsStartingWorkingTreeClean = true`, identical source fingerprints (`41cc3075...`), and `ValidationScope = "Clean Committed Revision (ef07cda22024f952d061f5f1c2fa96d2383475b3)"`.
5. **Exact Flutter Test Count Reconciled (159 vs. 158):** The saved Flutter test log in `artifacts/validation_runs/20261027_095914/flutter_test.stdout.txt` (and previously `20261027_075935`) concludes with `00:04 +159: All tests passed!`. Running the test files individually confirms:
   - `test/domain/domain_scientific_test.dart`: **47 passed** (lines +0 through +46)
   - `test/data/open_meteo_adapter_test.dart`: **42 passed** (lines +0 through +41)
   - `test/data/persistence_test.dart`: **63 passed** (lines +0 through +62)
   - `test/widget_test.dart`: **7 passed** (lines +0 through +6)
   - **Total Discovered and Executed Tests:** $47 + 42 + 63 + 7 = \mathbf{159}$.  
   Earlier reports referencing 158 tests omitted one recently added test in `domain_scientific_test.dart` (which contains 47 tests, not 46). The true, evidence-backed test count is **159 passed**.
6. **PowerShell Test Count Provenance:** Current PowerShell tests in commit `ef07cda` total **67 deterministic checks** + **1 live integration check** = **68 total suite checks**, all passing cleanly.
7. **Proportionate Limitations Documented:** Test 49 is an application-level simulation using test seam `AGROSHIFT_TEST_FAIL_READER_INIT` rather than proof of all operating system or kernel I/O failures. Process cleanup guarantees are bounded by `WaitForExit(5000)` and verified via dedicated timeout tests.
8. **Scientific Baseline Preserved:** Crop evapotranspiration arithmetic ($ET_c = K_c \times ET_0$) is validated (`PASS`), while client-side recalculation of FAO-56 Penman-Monteith from primitive weather variables remains incomplete (`INCOMPLETE`), and ground-truth field calibration across Egyptian agricultural zones remains deferred (`DEFERRED`).

---

## 2. Repository and Commit Provenance

| Inspection Property | Value | Evidence Source |
| :--- | :--- | :--- |
| **Repository Root** | `D:\Programming projects\agro_shift` | Git filesystem root |
| **Current Branch** | `main` | `git rev-parse --abbrev-ref HEAD` |
| **Validation-Run Execution HEAD** | `ef07cda22024f952d061f5f1c2fa96d2383475b3` | `verification_summary.json` (StartingHeadCommit) |
| **Published Evidence Commit** | `60f1adfd18987e1038d90039fce413494efce434` (`60f1adf`) | `git log -1 60f1adf` (contains 21 evidence files) |
| **Current Branch HEAD** | `60f1adfd18987e1038d90039fce413494efce434` (`60f1adf`) | `git rev-parse HEAD` |
| **Remote Tracking Branch** | `origin/main` (`https://github.com/AhmedKaram134679/AgroShift.git`) | `git branch -vv` |
| **Remote Sync Status** | Up to date (`60f1adf` matches `origin/main`) | `git status` |
| **Pre-Verification Tree State (at run 20261027_095914)** | Clean (`nothing to commit, working tree clean` over `ef07cda`) | `verification_summary.json` (StartingWorkingTreeEntries: []) |
| **Current Working Tree State** | Clean (working tree clean over `60f1adf`) | `git status` |

---

## 3. Findings Confirmed and Reconciled

### Finding 1: Verification Summary Provenance Architecture
- **Inspection Target:** `scripts/record_verification_evidence.ps1`
- **Confirmation:** The runner captures initial Git branch, initial commit SHA, initial working-tree entries via `git status --porcelain`, and initial cleanliness boolean `isInitiallyClean`. It computes an initial source fingerprint over tracked and untracked monitored files.
- **Enforcement:** If `-RequireCleanRevision` is passed and `$isInitiallyClean` is false, the runner immediately errors out with exit code `1` before executing any stages.
- **Reporting:** `ValidationScope` explicitly renders as `"Clean Committed Revision ($commit)"` if initially clean, or `"Modified Working Tree over ($commit)"` if dirty. Ending cleanliness is captured independently.

### Finding 2: Reconciled Test Counts by Specific Evidence Run
Test counts must never be conflated across different runs:

| Run ID | Commit SHA | Starting Tree | Monitored Files | Deterministic PS | Live PS | Total PS Checks | Flutter Tests | Release Build | Exit Code |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`20261026_132450`** | `84eec0c27d912dc` | Modified (`false`) | 70 | 55 / 55 | 1 (PASS) | **56 / 56** | 158 / 158 | PASS (APK built) | **0** |
| **`20261027_070738`** | `c9d7b5296731981` | Modified (`false`) | 72 | 55 / 55 | 1 (PASS) | **56 / 56** | 158 / 158 | PASS (APK built) | **0** |
| **`20261027_075935`** | `868aa9766d94934` | Modified (`false`) | 73 | 67 / 67 | 1 (PASS) | **68 / 68** | **159 / 159** | PASS (APK built) | **0** |
| **`20261027_095914`** | `ef07cda22024f95` | **Clean (`true`)** | 73 | 67 / 67 | 1 (PASS) | **68 / 68** | **159 / 159** | PASS (APK built) | **0** |

*Evidence paths:*
- Run `20261026_132450`: `artifacts/validation_runs/20261026_132450/powershell_tests.stdout.txt` (lines 1656–1660) & `verification_summary.json`.
- Run `20261027_075935`: `artifacts/validation_runs/20261027_075935/powershell_tests.stdout.txt` & `flutter_test.stdout.txt` (`+159: All tests passed!`).
- Run `20261027_095914`: `artifacts/validation_runs/20261027_095914/powershell_tests.stdout.txt` (lines 1451–1456) & `flutter_test.stdout.txt` (line 211: `00:04 +159: All tests passed!`).

### Finding 3: Exact Provenance Reconciliation Table (Issue B & E)

| Field | Run `20261026_132450` | Run `20261027_070738` | Run `20261027_075935` | Run `20261027_095914` |
| :--- | :--- | :--- | :--- | :--- |
| **Run ID** | `20261026_132450` | `20261027_070738` | `20261027_075935` | `20261027_095914` |
| **Tested HEAD** | `84eec0c27d912dc252895432c2f6c2d26e0c32b3` | `c9d7b529673198176bc02a35fabd695c08076c80` | `868aa9766d94934e3ba1c405ea627b0706d80a6c` | `ef07cda22024f952d061f5f1c2fa96d2383475b3` |
| **Baseline relationship** | Modified Working Tree | Modified Working Tree | Modified Working Tree | Clean Committed Revision |
| **Initial working-tree state** | Modified (`false`) | Modified (`false`) | Modified (`false`) | **Clean (`true`)** |
| **Final working-tree state** | Modified (`false`) | Modified (`false`) | Modified (`false`) | Modified (`false`) (contains run artifacts) |
| **Fingerprint scope** | `["lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock"]` | `["lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock"]` | `["lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock"]` | `["lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock"]` |
| **Initial fingerprint** | `ed096c44f379be1edc21bacafd4b6767eaa78cec92bbd5a3c168df383b216866` | `061bc7311ca4d91394ea728e3e30ab5ea612b1a155fb0ec2b832b342cb01f556` | `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6` | `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6` |
| **Final fingerprint** | `ed096c44f379be1edc21bacafd4b6767eaa78cec92bbd5a3c168df383b216866` | `061bc7311ca4d91394ea728e3e30ab5ea612b1a155fb0ec2b832b342cb01f556` | `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6` | `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6` |
| **Source mutation detected** | `false` | `false` | `false` | `false` |
| **PowerShell test result** | 56 / 56 passed | 56 / 56 passed | 68 / 68 passed | 68 / 68 passed |
| **Flutter test result** | 158 passed | 158 passed | 159 passed | 159 passed |
| **Release build result** | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) |
| **Evidence directory** | `artifacts/validation_runs/20261026_132450` | `artifacts/validation_runs/20261027_070738` | `artifacts/validation_runs/20261027_075935` | `artifacts/validation_runs/20261027_095914` |
| **Evidence availability** | Verified (Local disk) | Verified (Local disk) | Verified (Local disk) | **Verified (Published in Git commit `60f1adf`, 21 files present)** |
| **Material Limitations** | Uncommitted modifications during run | Uncommitted test edits during run | Uncommitted runner hardening during run | None for execution baseline; run executed cleanly over `ef07cda` and published in `60f1adf` |

---

## 4. Test Seam and Process-Cleanup Limitations

1. **Test 49 (Output-Reader Initialization Failure):**
   - Implemented in `test/scripts/test_validate_historical_models.ps1` (lines 912–954).
   - Injects a simulated exception via environment variable `AGROSHIFT_TEST_FAIL_READER_INIT` inside `Run-Stage` before `$p.StandardOutput.ReadToEndAsync()`.
   - **Limitation:** This is a controlled application-level simulation verifying that an exception during reader initialization is classified as an `OutputError`, sets stage exit code to `1`, does not mask `LaunchError` as null, allows subsequent stages to run, and fails the overall verification run. It does **not** prove every operating-system, kernel pipe handle exhaustion, or hardware failure mode.
2. **Process Cleanup and Timeout Logic:**
   - Implemented in `Stop-ProcessTree` within `scripts/record_verification_evidence.ps1`.
   - Uses `taskkill.exe /T /F /PID <pid>` wrapped with `$killProc.WaitForExit(5000)` to prevent unbounded hangs. If `taskkill.exe` fails or times out, it falls back to `$p.Kill()` with a secondary `$p.WaitForExit(5000)`.
   - **Limitation:** Tested deterministically in Tests 58, 59, and 60 (child sleep scripts, simulated utility failure, simulated fallback failure). While proven robust under Windows PowerShell process management, it does not guarantee instant child termination if the underlying process is in an uninterruptible Windows kernel state.

---

## 5. Scientific Baseline & Scope Disclosures

The scientific baseline established in `docs/INDEPENDENT_ET0_ETC_VALIDATION_REPORT.md` and `docs/historical_api_validation.md` remains strictly maintained:

1. **Daily Reference Evapotranspiration ($ET_0$):**
   - Source: Open-Meteo Historical Archive API using ECMWF ERA5 reanalysis (`models=era5`).
   - The application enforces operational range screening $[0.0, 25.0]\text{ mm/day}$ and interval completeness ($\le 10\%$ missingness).
   - **Status:** **`INCOMPLETE`** for independent client-side Penman-Monteith numerical recomputation from raw radiation, temperature, dew point, and wind fields.
2. **Crop Evapotranspiration ($ET_c$):**
   - Formula: $ET_c = K_c \times ET_0$ evaluated daily.
   - **Status:** **`PASS`**, verified against independent hand-calculated numerical oracles.
3. **Volumetric Water Requirement:**
   - Factor: $4.2\text{ m}^3/\text{feddan/mm}$ ($1\text{ Egyptian feddan} = 4,200.833\text{ m}^2$, standardized to $4.2$).
   - **Status:** **`PASS`**, verified mathematically.
4. **Crop Growth Stage Durations ($L_{\text{stage}}$):**
   - Implementation: Four-stage piecewise linear interpolation with fixed $[0.20, 0.30, 0.30, 0.20]$ developmental fraction partitioning.
   - **Status:** **`DOCUMENTED APPROXIMATION`**, adequate for relative rotational comparison, but not an empirical biological schedule.
5. **Ground-Truth Field Calibration:**
   - **Status:** **`DEFERRED`** (in-situ eddy-covariance and lysimeter observations across Egypt are not present in this software repository).

---

## 6. Verification Run Evidence: `20261027_095914`

A complete, clean-revision verification run was executed using the repository verification runner:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File scripts/record_verification_evidence.ps1 `
  -RequireCleanRevision
```

### Run Metadata
- **Evidence Directory:** `artifacts/validation_runs/20261027_095914`
- **Run Start (UTC):** `2026-10-27T09:59:14Z`
- **Run End (UTC):** `2026-10-27T10:01:23Z`
- **Duration:** `128.68` seconds
- **Starting HEAD:** `ef07cda22024f952d061f5f1c2fa96d2383475b3`
- **Ending HEAD:** `ef07cda22024f952d061f5f1c2fa96d2383475b3`
- **Starting Working Tree Clean:** `true`
- **Ending Working Tree Clean:** `false` (contains only generated evidence `artifacts/validation_runs/20261027_095914/`)
- **Initial Source File Count:** `73`
- **Final Source File Count:** `73`
- **Initial Fingerprint:** `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6`
- **Final Fingerprint:** `41cc307590b926a7e415c347fa886ca41eedf9edbd1c87939f464d5787e7dcb6`
- **Source Tree Mutated During Run:** `false`
- **Validation Scope:** `Clean Committed Revision (ef07cda22024f952d061f5f1c2fa96d2383475b3)`
- **Overall Status:** `PASS`

### Stage Results

| Stage | Command | Exit Code | Status | Duration |
| :--- | :--- | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | `PASS` | 3 s (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | `PASS` | 9 s (No issues found) |
| **Flutter Tests** | `flutter test` | `0` | `PASS` | 11 s (159 passed) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | `PASS` | 82 s (67 deterministic + 1 live = 68 checks passed) |
| **Release Build** | `flutter build apk --release` | `0` | `PASS` | 24 s (Built release APK: 58.7MB) |

---

## 7. Categorized Audit Verification Matrix

| Audit Dimension | Status | Verified Fact & Evidence Basis |
| :--- | :---: | :--- |
| **Git Provenance Distinction** | **`PASS`** | Runner records `StartingHeadCommit`, `IsStartingWorkingTreeClean`, `InitialSourceTreeFingerprint`, and `SourceTreeMutatedDuringRun` independently without conflation. |
| **Fingerprint Representation** | **`PASS`** | Documentation explicitly clarifies that fingerprint stability proves non-mutation of monitored source files, not initial tree cleanliness. |
| **Test Count Reconciliation** | **`PASS`** | Run `20261026_132450` reconciled at 55 + 1 = 56 checks. Run `20261027_095914` reconciled at 67 + 1 = 68 checks. Flutter tests reconciled at 159 checks (47 + 42 + 63 + 7). |
| **Commit vs. Source State** | **`PASS`** | Distinguishes base commit `84eec0c` (modified working tree in `20261026_132450`) from base commit `ef07cda` (clean committed revision in `20261027_095914`). |
| **Test Limitations Disclosure** | **`PASS`** | Test 49 documented as an application-level seam simulation. Process-cleanup bounded wait scope documented proportionately. |
| **Scientific Formulas & Fixtures** | **`PASS`** | $ET_c = K_c \times ET_0$, $[0.0, 25.0]\text{ mm/day}$ bounds, $4.2\text{ m}^3/\text{feddan/mm}$, and ERA5 historical fixtures preserved strictly intact. |
| **Clean Committed-Revision Run** | **`PASS`** | Executed directly from clean committed revision `ef07cda22024f952d061f5f1c2fa96d2383475b3` under run ID `20261027_095914`. |
| **Physical Android Migration** | **`DEFERRED`** | Preserved as `DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED` in verification summary. |

---

## 8. Final Verdict

**FINAL STATUS: `PASS WITH LIMITATIONS`**

All provenance fields, historical runs, test counts, test limitations, and scientific boundaries are rigorously verified, documented, and reconciled against immutable physical evidence. The verdict is `PASS WITH LIMITATIONS` because real-device physical Android database migration remains `DEFERRED`, independent client-side FAO-56 Penman-Monteith recomputation remains `INCOMPLETE`, and field calibration in Egypt remains `DEFERRED`.
