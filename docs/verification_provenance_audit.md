# Final Provenance and Scientific Evidence Consistency Audit Report
## Repository: AhmedKaram134679/AgroShift

**Audit Date:** 2026-10-28T11:05:00Z (2026-10-28T14:05:00+03:00)
**Auditor Roles:** Senior Git Provenance Engineer, Flutter/Dart Verification Auditor, PowerShell Test Infrastructure Reviewer, Scientific Evidence Documentation Specialist
**Primary Branch:** `main`  
**Governing Standard:** Antigravity Audit and Scientific Evidence Consistency Protocol  

---

## 1. Executive Summary

This formal audit report reconciles Git provenance, verification runner evidence, saved test outputs, and documented scientific claims across repository `AhmedKaram134679/AgroShift`.

### Key Audit Conclusions & Resolved Inconsistencies
1. **Resolution of Published Commits & Provenance Timeline:**
   - Commit `ef07cda22024f952d061f5f1c2fa96d2383475b3` (`ef07cda`) was the clean execution revision tested by run `20261027_095914`.
   - Commit `60f1adfd18987e1038d90039fce413494efce434` (`60f1adf`) published the initial 21 evidence files for run `20261027_095914` and earlier audit documentation.
   - Commit `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) was the **historical validation execution commit** tested by run `20261028_024200`.
   - Commit `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`) was the **evidence-publication commit** that formally committed the 21 evidence files of run `20261028_024200` to the repository.
   - Commit `bd48dd2657f74144e79496baac8ea804f0cc4938` (`bd48dd2`) was the **initial audit-report publication commit** (published at `2026-10-28T00:14:36Z` / `03:14:36+03:00`).
   - Commit `9af0dc24001ba5551ef6db960b27df967b9c6d2c` (`9af0dc2`) was an **intermediate audit-report revision commit** (published at `2026-10-28T03:57:38Z` / `06:57:38+03:00`).
   - Commit `7e379f5e9a0e9a2818e0e5a19ec587073bc29b3b` (`7e379f5`) was an **intermediate audit-report revision commit** (published at `2026-10-28T04:21:39Z` / `07:21:39+03:00`).
   - Commit `bb17d0d27c2ce872702488238187abe709cb4927` (`bb17d0d`) was an **intermediate audit-report revision commit** (published at `2026-10-28T04:37:34Z` / `07:37:34+03:00`).
   - Commit `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`) was the clean committed execution revision tested by verification run `20261028_084500` (published at `2026-10-28T05:12:28Z` / `08:12:28+03:00`).
   - Commit `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`) was the **evidence-publication commit** (published at `2026-10-28T05:59:55Z` / `08:59:55+03:00`), which formally published the 21 evidence files of run `20261028_084500` along with updated audit documentation.
   - Commit `b0c96ed35e432f7473cc6e721b43f5603c7e1a25` (`b0c96ed`) was an **intermediate audit-report publication commit** (published at `2026-10-28T06:29:35Z` / `09:29:35+03:00`).
   - Commit `853521059dc5a16b673fddac9197ca25c68e9c67` (`8535210`) was a feature commit implementing ET0 input validation in `EtcCalculator` and associated regression tests (published at `2026-10-28T07:28:06Z` / `10:28:06+03:00`).
   - Commit `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`) was the **clean committed execution revision tested by run `20261028_105807`** (published at `2026-10-28T09:47:26Z` / `12:47:26+03:00`).
   - Commit `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) is the **evidence-publication commit** formally publishing the 21 evidence files of clean run `20261028_105807` to `origin/main` (published at `2026-10-28T11:04:55Z` / `14:04:55+03:00`).
   - **Verification Qualification:** Clean committed-revision execution has been independently verified across four distinct milestones: run `20261027_095914` (over `ef07cda`), run `20261028_024200` (over `25438d0`), run `20261028_084500` (over `2e29eec`), and run `20261028_105807` (over `1e6e067`), all achieving `OverallStatus = PASS`. Subsequent publication commits (`60f1adf`, `d776842`, `bd48dd2`, `9af0dc2`, `7e379f5`, `bb17d0d`, `d9e9e08`, `b0c96ed`, `00827d5`) publish artifacts or documentation improvements and do not alter historical execution revisions.
2. **Provenance Separation Established:** Verification summaries accurately record distinct fields for starting Git HEAD, ending Git HEAD, initial working-tree cleanliness, final working-tree cleanliness, initial and final source-tree fingerprints, and source mutation during the run.
3. **Fingerprint vs. Cleanliness Fallacy Resolved:** A stable composite source-tree fingerprint ($SHA\text{-}256$) establishes solely that monitored files in the specified source scope (`lib/`, `test/`, `scripts/`, `docs/`, `pubspec.yaml`, `pubspec.lock`) did not mutate between initial and final measurements during the run (`SourceTreeMutatedDuringRun = false`). It does **not** prove that the starting working tree was clean, nor does it establish that untracked or unmonitored files were absent.
4. **Historical Runs Reconciled:**
   - Run `20261026_132450` tested a modified working tree over `84eec0c` (55 det. + 1 live = 56 passed; 158 Flutter tests).
   - Run `20261027_070738` tested a modified working tree over `c9d7b52` (55 det. + 1 live = 56 passed; 158 Flutter tests).
   - Run `20261027_075935` tested a modified working tree over `868aa97` (67 det. + 1 live = 68 passed; 159 Flutter tests).
   - Run `20261027_095914` tested a **Clean Committed Revision (`ef07cda22024f952d061f5f1c2fa96d2383475b3`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; published in commit `60f1adf`).
   - Run `20261028_024200` tested a **Clean Committed Revision (`25438d0e9ab725dce5788f52e1ef7056c30237ea`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; evidence published in commit `d776842`).
   - Run `20261028_084500` tested a **Clean Committed Revision (`2e29eecb994a528e06675ded0ba564ced8fa6a34`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; evidence published in commit `d9e9e08`, 21 files).
   - Run `20261028_105807` tested a **Clean Committed Revision (`1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4`)** (67 det. + 1 live = 68 passed; 159 Flutter tests; evidence published in commit `00827d5`, 21 files).
5. **Exact Flutter Test Count Reconciled (159 vs. 158):** The saved Flutter test logs in runs `20261027_075935`, `20261027_095914`, `20261028_024200`, `20261028_084500`, and `20261028_105807` conclude with `+159: All tests passed!`:
   - `test/domain/domain_scientific_test.dart`: **47 passed**
   - `test/data/open_meteo_adapter_test.dart`: **42 passed**
   - `test/data/persistence_test.dart`: **63 passed**
   - `test/widget_test.dart`: **7 passed**
   - **Total Discovered and Executed Tests:** $47 + 42 + 63 + 7 = \mathbf{159}$.
6. **Scientific Baseline Preserved:** Crop evapotranspiration arithmetic ($ET_c = K_c \times ET_0$) is validated (`PASS`), volumetric delta is confirmed as approximately $83.3\text{ L}$ per feddan per $100\text{ mm}$, client-side FAO-56 Penman-Monteith recomputation remains `INCOMPLETE`, ground-truth field calibration across Egypt remains `DEFERRED`, and physical Android migration remains `DEFERRED`.

---

## 2. Repository and Commit Provenance

### Core Provenance Snapshots: Historical Execution vs. Publication State

The target commits form a verified direct linear ancestry chain (`25438d0` $\leftarrow$ `d776842` $\leftarrow$ `bd48dd2` $\leftarrow$ `9af0dc2` $\leftarrow$ `7e379f5` $\leftarrow$ `bb17d0d` $\leftarrow$ `2e29eec` $\leftarrow$ `d9e9e08` $\leftarrow$ `b0c96ed` $\leftarrow$ `8535210` $\leftarrow$ `1e6e067` $\leftarrow$ `00827d5`):

| Concept | Verified Commit / Value | Required Meaning & Evidence Basis |
| :--- | :--- | :--- |
| **Historical Execution Commit (Run `20261028_024200`)** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | Tested commit recorded in `artifacts/validation_runs/20261028_024200/verification_summary.json` |
| **Evidence-Publication Commit (Run `20261028_024200`)** | `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`) | Commit adding the 21 evidence files of run `20261028_024200` to the repository (`git log -1 d776842`; 2026-10-28T03:00:46+03:00) |
| **Historical Execution Commit (`20261028_084500`)** | `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`) | Historical revision used by run `20261028_084500` (`verification_summary.json`); ancestor of `d9e9e08` |
| **Evidence-Publication Commit (Run `20261028_084500`)** | `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`) | Published 21 evidence files of run `20261028_084500` and updated audit documentation (`git log -1 d9e9e08`) |
| **Intermediate Documentation Publication Commit** | `b0c96ed35e432f7473cc6e721b43f5603c7e1a25` (`b0c96ed`) | Audit documentation update commit on `main` (`git log -1 b0c96ed`) |
| **Historical Feature Implementation Commit** | `853521059dc5a16b673fddac9197ca25c68e9c67` (`8535210`) | Feature commit implementing ET0 input validation in `EtcCalculator` (`git log -1 8535210`) |
| **Tested Clean Execution Commit (`20261028_105807`)** | `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`) | Clean committed revision tested by verification run `20261028_105807` (`artifacts/validation_runs/20261028_105807/verification_summary.json`) |
| **Evidence-Publication Commit (Run `20261028_105807`)** | `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | Published 21 evidence files of run `20261028_105807` to `origin/main` (`git log -1 00827d5`) |
| **Historical Working-Tree Condition** | Clean committed revision (`true`) | Established by runner verification summary (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries = []`) |
| **During-Run Source Stability** | Initial and final fingerprints match (`SourceTreeMutatedDuringRun = false`) | Monitored scope (`lib`, `test`, `scripts`, `docs`, `pubspec.yaml`, `pubspec.lock`; 74 files) matched composite SHA-256 `73943e601c...` |
| **Current Published State on `origin/main`** | Commit `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | Latest remote `origin/main` HEAD at completion of evidence publication |

### Detailed Repository Metadata

| Property | Verified Value | Evidence Source |
| :--- | :--- | :--- |
| **Repository Root** | `D:\Programming projects\agro_shift` | Git filesystem root |
| **Primary Branch** | `main` | `git rev-parse --abbrev-ref HEAD` |
| **Historical Validated Execution Commit (`20261027_095914`)** | `ef07cda22024f952d061f5f1c2fa96d2383475b3` (`ef07cda`) | `artifacts/validation_runs/20261027_095914/verification_summary.json` |
| **Historical Evidence Publication Commit (`20261027_095914`)** | `60f1adfd18987e1038d90039fce413494efce434` (`60f1adf`) | `git log -1 60f1adf` (published 21 evidence files) |
| **Historical Execution Commit (`20261028_024200`)** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | `artifacts/validation_runs/20261028_024200/verification_summary.json` |
| **Evidence Publication Commit for Run `20261028_024200`** | `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`) | `git log -1 d776842` (published 21 evidence files) |
| **Historical Execution Commit (`20261028_084500`)** | `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`) | `artifacts/validation_runs/20261028_084500/verification_summary.json` |
| **Evidence Publication Commit for Run `20261028_084500`** | `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`) | `git log -1 d9e9e08` (published 21 evidence files) |
| **Clean Execution Commit Tested by Run `20261028_105807`** | `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`) | `artifacts/validation_runs/20261028_105807/verification_summary.json` |
| **Evidence Publication Commit for Run `20261028_105807`** | `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | `git log -1 00827d5` (published 21 evidence files) |
| **Current Published `origin/main` Commit** | `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | `git rev-parse origin/main` |
| **Evidence Publication Status for Run `20261028_105807`** | Published in commit `00827d5` (21 files) | `git ls-tree -r --name-only 00827d5 artifacts/validation_runs/20261028_105807/` |

---

## 3. Comprehensive Provenance Reconciliation Table Across All Runs

| Field | Run `20261026_132450` | Run `20261027_070738` | Run `20261027_075935` | Run `20261027_095914` | Run `20261028_024200` | Run `20261028_084500` | Run `20261028_105807` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Run ID** | `20261026_132450` | `20261027_070738` | `20261027_075935` | `20261027_095914` | `20261028_024200` | `20261028_084500` | `20261028_105807` |
| **Tested HEAD Commit** | `84eec0c27d912dc` | `c9d7b5296731981` | `868aa9766d94934` | `ef07cda22024f95` | `25438d0e9ab725d` | `2e29eecb994a528` | `1e6e067ee138dc6` |
| **Baseline Relationship** | Modified Working Tree | Modified Working Tree | Modified Working Tree | Clean Committed Revision | Clean Committed Revision | Clean Committed Revision | **Clean Committed Revision** |
| **Initial Working-Tree State** | Modified (`false`) | Modified (`false`) | Modified (`false`) | **Clean (`true`)** | **Clean (`true`)** | **Clean (`true`)** | **Clean (`true`)** |
| **Final Working-Tree State** | Modified (`false`) | Modified (`false`) | Modified (`false`) | Modified (`false`) (run artifacts) | **Clean (`true`)** (isolated worktree) | **Clean (`true`)** (isolated worktree) | Modified (`false`) (run artifacts) |
| **Monitored Scope** | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` |
| **Monitored File Count** | 70 | 72 | 73 | 73 | 74 | 74 | **74** |
| **Initial Fingerprint** | `ed096c44f379be...` | `061bc7311ca4d9...` | `41cc307590b926...` | `41cc307590b926...` | `07bafeea427812...` | `aade0d00c98172...` | `73943e601c14d4...` |
| **Final Fingerprint** | `ed096c44f379be...` | `061bc7311ca4d9...` | `41cc307590b926...` | `41cc307590b926...` | `07bafeea427812...` | `aade0d00c98172...` | `73943e601c14d4...` |
| **Source Mutation Detected** | `false` | `false` | `false` | `false` | `false` | `false` | `false` |
| **PowerShell Checks** | 56 / 56 passed | 56 / 56 passed | 68 / 68 passed | 68 / 68 passed | 68 / 68 passed | 68 / 68 passed | **68 / 68 passed** |
| **Flutter Test Result** | 158 passed | 158 passed | 159 passed | 159 passed | 159 passed | 159 passed | **159 passed** |
| **Release Build Result** | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | Exit 0 (APK built) | **Exit 0 (APK built)** |
| **Evidence Directory** | `20261026_132450` | `20261027_070738` | `20261027_075935` | `20261027_095914` | `20261028_024200` | `20261028_084500` | `20261028_105807` |
| **Evidence Availability** | Verified (Local disk) | Verified (Local disk) | Verified (Local disk) | **Published (`60f1adf`, 21 files)** | **Published (`d776842`, 21 files)** | **Published (`d9e9e08`, 21 files)** | **Published (`00827d5`, 21 files)** |
| **Material Limitations** | Modified tree run | Modified tree run | Modified tree run | Initial clean; ending dirty | Clean execution over `25438d0` | Clean execution over `2e29eec` | Clean execution over `1e6e067`; published in `00827d5` |

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

## 7. Published Provenance Snapshot & Verification Runs

### 7.1 Historical Clean Verification Run (`20261028_024200`)

Executed directly from an isolated clean checkout of historical execution commit `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`), with evidence published on `origin/main` in commit `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`), initial audit documentation published in commit `bd48dd2657f74144e79496baac8ea804f0cc4938` (`bd48dd2`), intermediate audit revisions in commits `9af0dc24001ba5551ef6db960b27df967b9c6d2c` (`9af0dc2`) and `7e379f5e9a0e9a2818e0e5a19ec587073bc29b3b` (`7e379f5`), subsequent audit publications in commits `bb17d0d27c2ce872702488238187abe709cb4927` (`bb17d0d`) and `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`), evidence publication in commit `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`), and subsequent audit publication in commit `b0c96ed35e432f7473cc6e721b43f5603c7e1a25` (`b0c96ed`):

- **Run ID:** `20261028_024200`
- **Audit Timestamp (UTC):** `2026-10-28T02:47:09Z`
- **Historical Execution Commit:** `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`)
- **Evidence Publication Commit:** `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`)
- **Initial Audit-Report Publication Commit:** `bd48dd2657f74144e79496baac8ea804f0cc4938` (`bd48dd2`, published at `2026-10-28T03:14:36+03:00`)
- **Intermediate Report-Revision Commits:** `9af0dc24001ba5551ef6db960b27df967b9c6d2c` (`9af0dc2`, 06:57:38+03:00) and `7e379f5e9a0e9a2818e0e5a19ec587073bc29b3b` (`7e379f5`, 07:21:39+03:00)
- **Subsequent Report-Publication Commits:** `bb17d0d27c2ce872702488238187abe709cb4927` (`bb17d0d`, 07:37:34+03:00), `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`, 08:33:07+03:00), `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`, 08:59:55+03:00), and `b0c96ed35e432f7473cc6e721b43f5603c7e1a25` (`b0c96ed`, 09:33:07+03:00)
- **Evidence Directory:** `artifacts/validation_runs/20261028_024200` (21 files published on `origin/main`)
- **Initial Working Tree:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Final Working Tree:** Clean (`IsEndingWorkingTreeClean = true`, `EndingWorkingTreeEntries: []`)
- **Initial / Final Fingerprint:** `07bafeea427812dc8875725c5b95d7ee7f59b2d1027a811ecbb06b576f6b369f`
- **Source Mutation:** `false`
- **Validation Scope:** `Clean Committed Revision (25438d0e9ab725dce5788f52e1ef7056c30237ea)`
- **Overall Status:** `PASS`

#### Stage Execution Results (`20261028_024200`):

| Stage | Command | Exit Code | Status | Duration | Evidence File |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 3 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 18 s | `flutter_analyze.stdout.txt` (No issues found) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 40 s | `flutter_test.stdout.txt` (159 passed) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 88 s | `powershell_tests.stdout.txt` (67 det. + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 158 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

---

### 7.2 Fresh Final Clean Verification Run (`20261028_084500`)

Executed directly from an isolated clean worktree checkout of commit `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`), with evidence subsequently published in commit `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`):

- **Run ID:** `20261028_084500`
- **Audit Execution Timestamp (UTC):** `2026-10-28T08:45:00Z`
- **Tested Committed Revision:** `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`)
- **Evidence Publication Commit:** `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`)
- **Evidence Directory:** `artifacts/validation_runs/20261028_084500` (21 verification artifacts published on `origin/main`)
- **Evidence Publication Status:** Published in commit `d9e9e08`, with all 21 verified artifact files committed to `origin/main`.
- **Initial Working Tree:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Final Working Tree:** Clean (`IsEndingWorkingTreeClean = true`, `EndingWorkingTreeEntries: []`)
- **Monitored Source Files:** 74 files
- **Initial / Final Fingerprint:** `aade0d00c98172d8d6a0acd8f6f95b63af1f31ee166c82159a00e6cbdb567489`
- **Source Mutation:** `false`
- **Validation Scope:** `Clean Committed Revision (2e29eecb994a528e06675ded0ba564ced8fa6a34)`
- **Overall Status:** `PASS`

#### Stage Execution Results (`20261028_084500`):

| Stage | Command | Exit Code | Status | Duration | Evidence File |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 3.5 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 17.1 s | `flutter_analyze.stdout.txt` (No issues found) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 39.4 s | `flutter_test.stdout.txt` (159 passed) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 68.2 s | `powershell_tests.stdout.txt` (67 det. + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 185.0 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

---

### 7.3 Fresh Final Clean Verification Run (`20261028_105807`)

Executed directly against clean committed revision `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`), with evidence subsequently published in commit `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`):

- **Run ID:** `20261028_105807`
- **Audit Execution Timestamp (UTC):** `2026-10-28T10:58:07Z` (Duration: 178.97 s)
- **Tested Committed Revision:** `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`)
- **Evidence Publication Commit:** `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`)
- **Evidence Directory:** `artifacts/validation_runs/20261028_105807` (21 verification artifacts published on `origin/main`)
- **Evidence Publication Status:** Published in commit `00827d5`, with all 21 verified artifact files committed to `origin/main`.
- **Initial Working Tree:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Final Working Tree:** Modified by run evidence artifacts (`IsEndingWorkingTreeClean = false`, `EndingWorkingTreeEntries: ["?? artifacts/validation_runs/20261028_105807/"]`)
- **Monitored Source Files:** 74 files
- **Initial / Final Fingerprint:** `73943e601c14d46e37bf5d8c31985b82925e22a75c48adbb4e96a0f514902f23`
- **Source Mutation:** `false`
- **Validation Scope:** `Clean Committed Revision (1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4)`
- **Overall Status:** `PASS`

#### Stage Execution Results (`20261028_105807`):

| Stage | Command | Exit Code | Status | Duration | Evidence File |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 2 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 11 s | `flutter_analyze.stdout.txt` (No issues found) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 10 s | `flutter_test.stdout.txt` (159 passed) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 80 s | `powershell_tests.stdout.txt` (67 det. + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 75 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

---

## 8. Final Verdict

**FINAL STATUS: `PASS WITH LIMITATIONS`**

- **Verified Facts:** Clean committed-revision execution was independently executed against commits `ef07cda` (run `20261027_095914`, published in `60f1adf`), `25438d0` (run `20261028_024200`, evidence published in `d776842`), `2e29eec` (run `20261028_084500`, evidence published in `d9e9e08`), and `1e6e067` (run `20261028_105807`, evidence published in `00827d5`), all passing with exit code 0; test counts are verified across all runs as 159 Flutter tests and 68 PowerShell checks (67 deterministic + 1 live); provenance separation is fully established with historical execution commits (`25438d0`, `2e29eec`, `1e6e067`), evidence publication commits (`d776842`, `d9e9e08`, `00827d5`), initial audit report publication commit (`bd48dd2`), intermediate revision commits (`9af0dc2`, `7e379f5`, `bb17d0d`), and subsequent publication commits (`2e29eec`, `d9e9e08`, `b0c96ed`, `8535210`, `1e6e067`, `00827d5`) distinctly identified on `origin/main`.
- **Explicit Limitations:**
  - Independent client-side calculation of FAO-56 Penman-Monteith remains **`INCOMPLETE`**.
  - Ground-truth field calibration across Egyptian climate zones remains **`DEFERRED`**.
  - Physical Android SQLite migration on a physical handset remains **`DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED`**.
  - Documentation-only or evidence-publication commits (`bd48dd2`, `9af0dc2`, `7e379f5`, `bb17d0d`, `b0c96ed`, `00827d5`) do not automatically inherit verification execution status from earlier runs without independent execution verification.

---

## 9. Post-Publication Provenance Reconciliation

- **Reconciliation Date (UTC):** `2026-10-28T11:08:00Z` (`2026-10-28T14:08:00+03:00`)
- **Referenced Post-Publication Commit:** `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`)
- **Latest Tested Clean Execution Commit:** `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`, run `20261028_105807`)
- **Current Remote HEAD on `origin/main`:** `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`)
- **Working-Tree State at Reconciliation:** Documentation update in progress
- **Evidence Publication Status:** Fully published on `origin/main` in commit `00827d5` (all 21 evidence files confirmed present under `artifacts/validation_runs/20261028_105807/`)
- **Reconciliation Basis:** Git commit log, `git show -s --format=fuller`, `git ls-tree`, and filesystem inspection

### Provenance Clarification

The commit associated with a validation run identifies the source revision used for that run. It must not automatically be described as the latest published commit.

A clean working tree establishes that no tracked or untracked changes were present within the scope actually inspected at that time. It does not, by itself, establish that the repository revision was the latest published revision.

Publication status must be supported by the verified remote repository state and the actual presence of the relevant evidence files. Commit `00827d5` is verified as the current published HEAD on `origin/main`, succeeding `1e6e067`, `8535210`, `b0c96ed`, `d9e9e08`, and `2e29eec`.
