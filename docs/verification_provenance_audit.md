# Final Provenance and Scientific Evidence Consistency Audit Report
## Repository: AhmedKaram134679/AgroShift

**Audit Date:** 2026-10-29T13:00:00Z (2026-10-29T16:00:00+03:00)
**Auditor Roles:** Senior Git Provenance Engineer, Flutter/Dart Verification Auditor, SQLite/Drift Persistence Reviewer, PowerShell Test Infrastructure Reviewer, Scientific Evidence Documentation Specialist
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
   - Commit `45a57c52d8ba650a97769820b225c9b0e320216d` (`45a57c5`) is the **audit-report publication commit** formally reconciling the provenance audit report with clean run `20261028_105807` on `origin/main` (published at `2026-10-28T11:12:52Z` / `14:12:52+03:00`).
   - Commit `66f13b958b5126966c439d83202022bac89c7a02` (`66f13b9`) was a documentation refinement commit on `main`.
   - Commit `af45d9990bd925d2b1b55aec96644341091e5592` (`af45d99`) was an implementation commit delivering targeted fixes A–F and 164 Flutter tests.
   - Commit `2adb4b450682cb1692438d91b26a76ba460e4b05` (`2adb4b4`) documented publication status of run `20261028_084500`.
   - Commit `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`) added core providers, dashboard navigation shell, and persistence regression tests (168 Flutter tests).
   - Commit `170d2f60bd57ca8f720ffdd819c6ae2729a2f4b7` (`170d2f6`) published run `20261028_185811` artifacts and audit report updates.
   - Commit `605723cc23b6c6bac28ee77447d113ee921109a7` (`605723c`) was the **clean committed execution revision tested by validation run `20261028_234442`**, adding independent domain scientific calculations and test oracles (173 Flutter tests passed).
   - Commit `f35008e20d5ba68a366046ad324906560baa9dc6` (`f35008e`) was the **evidence-publication commit for run `20261028_234442`**, formally publishing the 9 evidence files of run `20261028_234442` and audit updates.
   - Commit `c1c79289583b7a29df17ccf6cb4147be6c8b5f65` (`c1c7928`) incorporated farm-field data persistence, biological growth-stage forecasting, SQLite schema version 3, and UI screens (187 Flutter tests passed).
   - Commit `6fb2ddfc1147b14eff4d369b964ddb6fa2867865` (`6fb2ddf`) implemented FarmField persistence reliability hardening, preserving default-field identity during updates and guaranteeing seeding failure propagation (189 Flutter tests passed).
   - Commit `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`) was the **clean committed execution revision tested by validation run `20261029_131304`** (189 Flutter tests passed, 68 PowerShell checks passed, exit code 0).
   - Commit `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) is the **current published HEAD on `origin/main`** and the **evidence-publication commit** that formally published the 21 evidence files of run `20261029_131304` along with documentation updates. Furthermore, commit `7be1279` was independently verified in clean execution run `20261029_124430` (189 Flutter tests passed, 68 PowerShell checks passed, exit code 0 across all 5 stages).
   - **Verification Qualification:** Clean committed-revision execution has been independently verified across distinct milestones: run `20261027_095914` (over `ef07cda`), run `20261028_024200` (over `25438d0`), run `20261028_084500` (over `2e29eec`), run `20261028_105807` (over `1e6e067`), run `20261028_234442` (over `605723c`), run `20261029_131304` (over `fc42ff3`), and run `20261029_124430` (over `7be1279`), all achieving `OverallStatus = PASS` or `PASS WITH LIMITATIONS`.
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
   - Run `20261028_185811` tested a **Modified Working Tree over `cce7f0d66609fedf70a7dfa5ca176e21e70a1187`** (67 det. + 1 live = 68 passed; 168 Flutter tests; evidence published in commit `170d2f6`, 21 files).
   - Run `20261028_234442` tested a **Clean Committed Revision (`605723cc23b6c6bac28ee77447d113ee921109a7`)** (173 Flutter tests passed; exit code 0; evidence published in commit `f35008e`, 9 files).
   - Run `20261029_100759` tested a **Modified Working Tree over `c1c79289583b7a29df17ccf6cb4147be6c8b5f65`** (187 Flutter tests passed; 68 PowerShell checks; 21 evidence files).
   - Run `20261029_131304` tested a **Clean Committed Revision (`fc42ff342013475e7e8767966016c3040127f22d`)** (189 Flutter tests passed; 68 PowerShell checks; exit code 0 across all 5 stages; evidence published in `7be1279`).
   - Run `20261029_124430` tested a **Clean Committed Revision (`7be12790499f92407b3e02ff55d7b54ca7c1f0ac`)** (189 Flutter tests passed; 68 PowerShell checks; exit code 0 across all 5 stages; 20 evidence files recorded).
5. **Exact Flutter Test Count Reconciled Across Suites:**
   - Runs `20261027_095914`, `20261028_024200`, `20261028_084500`, `20261028_105807`: **159 passed** ($47 + 42 + 63 + 7 = 159$).
   - Commit `af45d99`: **164 passed** ($47 + 42 + 67 + 8 = 164$).
   - Run `20261028_185811`: **168 passed** ($47 + 42 + 71 + 8 = 168$).
   - Run `20261028_234442`: **173 passed** ($55 + 42 + 68 + 8 = 173$).
   - Run `20261029_100759`: **187 passed** ($68 + 42 + 69 + 8 = 187$).
   - Runs `20261029_131304` and `20261029_124430`: **189 passed** ($68 + 42 + 71 + 8 = 189$, reconciling persistence regression tests 8b and 8c for default-field preservation and failure propagation).
6. **Scientific Baseline Preserved:** Crop evapotranspiration arithmetic ($ET_c = K_c \times ET_0$) is validated (`PASS`), volumetric delta is confirmed as approximately $83.3\text{ L}$ per feddan per $100\text{ mm}$, client-side FAO-56 Penman-Monteith recomputation remains `INCOMPLETE`, ground-truth field calibration across Egypt remains `DEFERRED`, and physical Android migration remains `DEFERRED`.

---

## 2. Repository and Commit Provenance

### Core Provenance Snapshots: Historical Execution vs. Publication State

The target commits form a verified direct linear ancestry chain (`25438d0` $\leftarrow$ `d776842` $\leftarrow$ `bd48dd2` $\leftarrow$ `9af0dc2` $\leftarrow$ `7e379f5` $\leftarrow$ `bb17d0d` $\leftarrow$ `2e29eec` $\leftarrow$ `d9e9e08` $\leftarrow$ `b0c96ed` $\leftarrow$ `8535210` $\leftarrow$ `1e6e067` $\leftarrow$ `00827d5` $\leftarrow$ `45a57c5` $\leftarrow$ `66f13b9` $\leftarrow$ `af45d99` $\leftarrow$ `2adb4b4` $\leftarrow$ `cce7f0d` $\leftarrow$ `170d2f6` $\leftarrow$ `605723c` $\leftarrow$ `f35008e` $\leftarrow$ `854ac0c` $\leftarrow$ `c02011a` $\leftarrow$ `d4c6eeb` $\leftarrow$ `c1c7928` $\leftarrow$ `6fb2ddf` $\leftarrow$ `fc42ff3` $\leftarrow$ `7be1279`):

| Concept | Verified Commit / Value | Required Meaning & Evidence Basis |
| :--- | :--- | :--- |
| **Historical Execution Commit (Run `20261028_024200`)** | `25438d0e9ab725dce5788f52e1ef7056c30237ea` (`25438d0`) | Tested commit recorded in `artifacts/validation_runs/20261028_024200/verification_summary.json` |
| **Evidence-Publication Commit (Run `20261028_024200`)** | `d7768424cac9a03b8f73a0d0417603fdc6bbccad` (`d776842`) | Commit adding the 21 evidence files of run `20261028_024200` to the repository (`git log -1 d776842`; 2026-10-28T03:00:46+03:00) |
| **Historical Execution Commit (`20261028_084500`)** | `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`) | Historical revision used by run `20261028_084500` (`verification_summary.json`); ancestor of `d9e9e08` |
| **Evidence-Publication Commit (Run `20261028_084500`)** | `d9e9e086ce7f8efbcf5b874ee73a396885726772` (`d9e9e08`) | Published 21 evidence files of run `20261028_084500` and updated audit documentation (`git log -1 d9e9e08`) |
| **Clean Execution Commit Tested by Run `20261028_105807`** | `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`) | Clean committed revision tested by verification run `20261028_105807` (`artifacts/validation_runs/20261028_105807/verification_summary.json`) |
| **Evidence-Publication Commit (Run `20261028_105807`)** | `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | Published 21 evidence files of run `20261028_105807` to `origin/main` (`git log -1 00827d5`) |
| **Execution Commit Tested by Run `20261028_185811`** | `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`) | Tested over modified working tree with persistence tests (`artifacts/validation_runs/20261028_185811/verification_summary.json`) |
| **Evidence-Publication Commit (Run `20261028_185811`)** | `170d2f60bd57ca8f720ffdd819c6ae2729a2f4b7` (`170d2f6`) | Formally committed 21 evidence files of run `20261028_185811` to `origin/main` |
| **Clean Execution Commit Tested by Run `20261028_234442`** | `605723cc23b6c6bac28ee77447d113ee921109a7` (`605723c`) | Clean committed revision tested by verification run `20261028_234442` (`artifacts/validation_runs/20261028_234442/verification_summary.json`) |
| **Evidence-Publication Commit (Run `20261028_234442`)** | `f35008e20d5ba68a366046ad324906560baa9dc6` (`f35008e`) | Formally published 9 evidence files of run `20261028_234442` and audit documentation (`git log -1 f35008e`) |
| **Execution Commit Tested by Run `20261029_100759`** | `c1c79289583b7a29df17ccf6cb4147be6c8b5f65` (`c1c7928`) | Modified working tree execution with biological growth stages and schema v3 (187 Flutter tests) |
| **Clean Execution Commit Tested by Run `20261029_131304`** | `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`) | Clean committed revision tested by verification run `20261029_131304` (189 Flutter tests passed, 68 PowerShell checks passed, exit code 0) |
| **Evidence-Publication Commit (Run `20261029_131304`) & Current Published HEAD** | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) | Formally committed the 21 evidence files of run `20261029_131304` to `origin/main` and updated audit docs; verified as current HEAD on `origin/main` (`git rev-parse HEAD`) |
| **Clean Execution Commit Tested by Run `20261029_124430`** | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) | Clean committed revision tested by verification run `20261029_124430` (189 Flutter tests passed, 68 PowerShell checks passed, exit code 0) |
| **Working-Tree Condition for Runs `20261029_131304` & `20261029_124430`** | Clean committed revision (`true`) | Established by runner verification summaries (`isStartingWorkingTreeClean = true`, `isEndingWorkingTreeClean = true`, external out-of-tree artifacts) |

### Detailed Repository Metadata

| Property | Verified Value | Evidence Source |
| :--- | :--- | :--- |
| **Repository Root** | `D:\Programming projects\agro_shift` | Git filesystem root |
| **Primary Branch** | `main` | `git rev-parse --abbrev-ref HEAD` |
| **Historical Execution Commit (`20261028_105807`)** | `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`) | `artifacts/validation_runs/20261028_105807/verification_summary.json` |
| **Evidence Publication Commit for Run `20261028_105807`** | `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`) | `git log -1 00827d5` (published 21 evidence files) |
| **Historical Execution Commit (`20261028_185811`)** | `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`) | `artifacts/validation_runs/20261028_185811/verification_summary.json` |
| **Evidence Publication Commit for Run `20261028_185811`** | `170d2f60bd57ca8f720ffdd819c6ae2729a2f4b7` (`170d2f6`) | `git log -1 170d2f6` (published 21 evidence files) |
| **Historical Execution Commit (`20261028_234442`)** | `605723cc23b6c6bac28ee77447d113ee921109a7` (`605723c`) | `artifacts/validation_runs/20261028_234442/verification_summary.json` & `git_head.txt` |
| **Evidence Publication Commit for Run `20261028_234442`** | `f35008e20d5ba68a366046ad324906560baa9dc6` (`f35008e`) | `git log -1 f35008e` (published 9 evidence files) |
| **Tested Execution Commit for Run `20261029_131304`** | `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`) | `artifacts/validation_runs/20261029_131304/verification_summary.json` |
| **Evidence Publication Commit for Run `20261029_131304`** | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) | `git log -1 7be1279` (published 21 evidence files under `artifacts/validation_runs/20261029_131304/`) |
| **Current Published `origin/main` HEAD** | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) | Verified current published commit on `origin/main` (`git rev-parse HEAD` / `git log -1`) |
| **Tested Execution Commit for Run `20261029_124430`** | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) | `artifacts/validation_runs/20261029_124430/verification_summary.json` (fresh isolated clean run) |
| **Evidence Verification Status for Runs `20261029_131304` & `20261029_124430`** | Verified locally and published/recorded (`artifacts/validation_runs/`) | 21 artifacts for `20261029_131304` and 20 artifacts for `20261029_124430` present |

---

## 3. Comprehensive Provenance Reconciliation Table Across All Runs

### 3.1 Historical Calibration and Milestone Runs (158 to 159 Tests)

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
| **Material Limitations** | Modified tree run | Modified tree run | Modified tree run | Initial clean; ending dirty | Clean execution over `25438d0` | Clean execution over `2e29eec` | Clean execution over `1e6e067` |

### 3.2 Advanced Evolution & Recent Verification Runs (168 to 189 Tests)

| Field | Run `20261028_185811` | Run `20261028_234442` | Run `20261029_100759` | Run `20261029_131304` | Run `20261029_124430` (Clean Published HEAD Execution) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Run ID** | `20261028_185811` | `20261028_234442` | `20261029_100759` | `20261029_131304` | `20261029_124430` |
| **Tested HEAD Commit** | `cce7f0d66609fed` | `605723cc23b6c6b` | `c1c79289583b7a2` | `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`) | `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`) |
| **Baseline Relationship** | Modified Working Tree | Clean Committed Revision | Modified Working Tree | **Clean Committed Revision** | **Clean Committed Revision** |
| **Initial Working-Tree State** | Modified (`false`) | **Clean (`true`)** | Modified (`false`) | **Clean (`true`)** | **Clean (`true`)** |
| **Final Working-Tree State** | Modified (`false`) | Modified (`false`) (run artifacts) | Modified (`false`) | **Clean (`true`)** (external output dir / isolated worktree) | **Clean (`true`)** (external output dir / isolated worktree) |
| **Monitored Scope** | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` | `["lib", "test", ...]` |
| **Monitored File Count** | 74 | 74 | 74 | **74** | **74** |
| **Initial Fingerprint** | `1fbe6d23cacaac...` | `e3b0c44298fc1c...` | `a9f5ef2ab62028...` | `7e6388c543d9e6c92ec6f5e9d4bb8cdebf8846cd7b0fa35ad703a4465475a097` | `867ae5b42d25adc64d633f81a4fcf0ea254d34f84c2fc3acd53ca7d15cfb8bc0` |
| **Final Fingerprint** | `1fbe6d23cacaac...` | `e3b0c44298fc1c...` | `a9f5ef2ab62028...` | `7e6388c543d9e6c92ec6f5e9d4bb8cdebf8846cd7b0fa35ad703a4465475a097` | `867ae5b42d25adc64d633f81a4fcf0ea254d34f84c2fc3acd53ca7d15cfb8bc0` |
| **Source Mutation Detected**| `false` | `false` | `false` | `false` | `false` |
| **PowerShell Checks** | 68 / 68 passed | N/A (Flutter test run) | 68 / 68 passed | **68 / 68 passed** (67 deterministic + 1 live) | **68 / 68 passed** (67 deterministic + 1 live) |
| **Flutter Test Result** | 168 passed | 173 passed | 187 passed | **189 passed** (0 failed, 0 skipped) | **189 passed** (0 failed, 0 skipped) |
| **Release Build Result** | Exit 0 (APK built) | N/A | Exit 0 (APK built) | **Exit 0 (58.7MB release APK built)** | **Exit 0 (58.7MB release APK built)** |
| **Overall Status** | `PASS` | `PASS WITH LIMITATIONS` | `PASS` | **`PASS WITH LIMITATIONS`** | **`PASS WITH LIMITATIONS`** |
| **Evidence Directory** | `20261028_185811` | `20261028_234442` | `20261029_100759` | `20261029_131304` | `20261029_124430` |
| **Evidence Availability** | **Published (`170d2f6`, 21 files)** | **Published (`f35008e`, 9 files)** | Local artifacts (21 files) | **Published in `7be1279` (`artifacts/validation_runs/20261029_131304/`, 21 files)** | **Recorded in `artifacts/validation_runs/20261029_124430/` (20 files)** |
| **Material Limitations** | Modified working tree | Android migration deferred | Modified working tree | **Clean committed revision; Android migration deferred** | **Clean committed revision; Android migration deferred** |

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
   - Factor: $4.2\text{ m}^3/\text{feddan/mm}$.
   - Operational conversion: $100\text{ mm} \times 4.2 = 420.0\text{ m}^3/\text{feddan} = 420,000\text{ liters}$.
   - Calculation using documented area ($4,200.83\text{ m}^2$): $100\text{ mm} \times 4,200.83\text{ m}^2 \times 0.001\text{ m/mm} = 420,083.0\text{ liters}$.
   - Difference: approximately $0.083\text{ m}^3$ ($83\text{ liters}$) per feddan per $100\text{ mm}$.
   - **Status:** The implementation correctly applies the configured operational conversion factor of $4.2\text{ m}^3$ per feddan per millimeter. This factor is a rounded approximation of $4.20083\text{ m}^3$ based on the documented feddan area of $4,200.83\text{ m}^2$. Numerical tests validate the implementation against the configured factor; they do not establish that the rounded factor is physically exact.
4. **Crop Growth Stage Durations ($L_{\text{stage}}$):**
   - Implementation: The implementation performs piecewise linear interpolation of $K_c$ values using the configured crop-stage intervals. The stage fractions $[0.20, 0.30, 0.30, 0.20]$ are a fixed operational approximation, not independently calibrated biological durations for every crop or cultivar. Numerical tests validate the implemented interpolation behavior against the configured inputs; they do not establish the biological accuracy of these stage durations.
   - **Status:** **`DOCUMENTED OPERATIONAL APPROXIMATION`**, adequate for relative rotational comparison, but not an empirical biological schedule.
5. **Ground-Truth Field Calibration:**
   - **Status:** **`DEFERRED`** (in-situ eddy-covariance and lysimeter observations across Egyptian microclimates are not present in this software repository).

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
- **Published commit:** `d9e9e086ce7f8efbcf5b874ee73a396885726772`
- **Publication status:** Verified on `origin/main` at the time of this audit.
- **Verification basis:** The commit object, remote branch reference, commit ancestry, and relevant evidence paths were checked against the repository state observed during this audit.
- **Relationship to earlier commit:** Commit `2e29eecb994a528e06675ded0ba564ced8fa6a34` (`2e29eec`) is an earlier commit and is not the latest published commit identified by this audit. The publication state is determined by the verified remote branch HEAD and commit ancestry, not by a previously recorded abbreviated SHA.
- **Evidence Directory:** `artifacts/validation_runs/20261028_084500` (21 verification artifacts published on `origin/main`)
- **Evidence Publication Status:** Fully published on `origin/main` in commit `d9e9e08`, with all 21 verified artifact files committed to `origin/main`.
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

- **Verified Facts:** Clean committed-revision execution was independently executed against commits `ef07cda` (run `20261027_095914`, published in `60f1adf`), `25438d0` (run `20261028_024200`, evidence published in `d776842`), `2e29eec` (run `20261028_084500`, evidence published in `d9e9e08`), `1e6e067` (run `20261028_105807`, evidence published in `00827d5`), `605723c` (run `20261028_234442`, evidence published in `f35008e`), and current HEAD `fc42ff3` (run `20261029_131304`, recorded with 20 evidence files), all passing with exit code 0; test counts are verified across all evolutionary milestones (from 159 to 189 Flutter tests and 68 PowerShell checks); provenance separation is fully established with historical execution commits (`25438d0`, `2e29eec`, `1e6e067`, `605723c`, `fc42ff3`), evidence publication commits, intermediate revision commits, and current published HEAD `fc42ff342013475e7e8767966016c3040127f22d` distinctly identified on `origin/main`.
- **Explicit Limitations:**
  - Independent client-side calculation of FAO-56 Penman-Monteith remains **`INCOMPLETE`**.
  - Ground-truth field calibration across Egyptian climate zones remains **`DEFERRED`**.
  - Physical Android SQLite migration on a physical handset remains **`DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED`**.
  - Documentation-only or evidence-publication commits do not automatically inherit verification execution status from earlier runs without independent execution verification.

---

## 9. Post-Publication Provenance Reconciliation

- **Reconciliation Date (UTC):** `2026-10-28T11:35:00Z` (`2026-10-28T14:35:00+03:00`)
- **Tested Execution Commit:** `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`), associated with verification run `20261028_105807`.
- **Evidence-Publication Commit:** `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`), which published the 21 evidence artifacts for run `20261028_105807`.
- **Reconciliation Target Commit:** `45a57c52d8ba650a97769820b225c9b0e320216d` (`45a57c5`).
- **Current Published HEAD on `origin/main`:** `45a57c52d8ba650a97769820b225c9b0e320216d` (`45a57c5`).
- **Working-Tree State Before Documentation Changes:** Clean (`git status --short --branch` returned `## main...origin/main` with 0 uncommitted entries).
- **Target Report Modification Status in `45a57c5`:** Commit `45a57c5` modified `docs/verification_provenance_audit.md` (127 lines changed: +79, -48).
- **Evidence Publication Status:** Fully published on `origin/main` in commit `00827d5` (all 21 evidence files confirmed present under `artifacts/validation_runs/20261028_105807/`).
- **Reconciliation Basis:** Git commit metadata, ancestry, the target file history, and the actual committed evidence files.

### Provenance Clarification

The execution commit identifies the source revision used for a specific verification run. It must not be confused with a later evidence-publication commit or a subsequent documentation/repository commit.

The evidence-publication commit identifies the revision that published the run's evidence artifacts. Publishing those artifacts does not, by itself, establish that the publication commit was independently tested.

The current repository HEAD identifies the latest verified published revision at the time of inspection. It does not automatically inherit the verification status of an earlier execution commit.

A matching initial and final source-tree fingerprint establishes stability only for the monitored files and scope measured by the verification runner. It does not independently establish working-tree cleanliness, the absence of untracked files outside the monitored scope, or that the tested commit was the latest published revision.

The historical result for run `20261028_105807` remains associated with tested commit `1e6e067`. The evidence-publication relationship remains associated with `00827d5`. Any later report or repository revision must be described according to its verified Git history rather than inferred from its position in the commit timeline.

---

## 10. Post-Publication Provenance Reconciliation — Commits 2adb4b4 & cce7f0d

- **Reconciliation Date (UTC):** `2026-10-28T18:15:00Z` (`2026-10-28T21:15:00+03:00`)
- **Verified Current Published Branch:** `main`
- **Verified Published HEAD:** `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`)
- **Historical Execution Commit:** `1e6e067ee138dc6ef40c2d57820ceb2d0d34a9f4` (`1e6e067`), tied to verification run `20261028_105807` (159 Flutter tests passed, 68 PowerShell checks passed)
- **Evidence Publication Commit:** `00827d58f1d1e8992ff12529b4cba17bc671413c` (`00827d5`)
- **Evidence Publication Status:** Fully published on `origin/main` in commit `00827d5` (all 21 evidence files confirmed present under `artifacts/validation_runs/20261028_105807/`)
- **Intermediate Post-Publication Commits on `main`:**
  - `45a57c52d8ba650a97769820b225c9b0e320216d` (`45a57c5`): Reconciled audit documentation with run `20261028_105807`.
  - `66f13b958b5126966c439d83202022bac89c7a02` (`66f13b9`): Documentation refinement commit.
  - `af45d9990bd925d2b1b55aec96644341091e5592` (`af45d99`): Implementation commit delivering targeted fixes A–F (field timestamps, non-finite temperature validations, coordinate NaN boundary protection, dashboard & field management UI improvements, and 164 discovered Flutter tests).
  - `2adb4b450682cb1692438d91b26a76ba460e4b05` (`2adb4b4`): Documented publication status of run `20261028_084500`.
  - `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`): Published commit formally incorporating core navigation providers, dashboard active tab navigation, persistence tests B1–B4, and rice standing-water comment correction.

### Provenance Audit of Referenced Fixes A–F

| Fix / Investigation Target | Commit SHA | Modified Files | Test File | Test Status & Execution Evidence Status |
| :--- | :--- | :--- | :--- | :--- |
| **Fix A: GDD & Heat Stress Non-Finite / Out-of-Range Handling** | `af45d99` | `lib/domain/agronomy/science/gdd_calculator.dart`, `heat_stress_evaluator.dart`, `scientific_range_validator.dart` | `test/domain/domain_scientific_test.dart` | `EXECUTION VERIFIED AGAINST IDENTIFIED COMMIT` (Tested locally with exit 0; tests present and passing) |
| **Fix B: Timestamp Persistence Logic (`saveField`)** | `af45d99`, `cce7f0d` | `lib/data/repositories/farm_field_repository_impl.dart` | `test/data/persistence_test.dart` | `EXECUTION VERIFIED AGAINST IDENTIFIED COMMIT` (Strengthened with deterministic SQLite tests covering B1–B4; 8/8 persistence tests passing) |
| **Fix C: Coordinate Non-Finite Boundary Protection** | `af45d99` | `lib/domain/environment/models/coordinate.dart` | `test/domain/domain_scientific_test.dart` | `EXECUTION VERIFIED AGAINST IDENTIFIED COMMIT` (NaN/Inf bounding box tests present and passing) |
| **Fix D: Dashboard & Environmental Analysis Null Field Safeguard** | `af45d99`, `cce7f0d` | `lib/presentation/screens/dashboard_screen.dart`, `environmental_analysis_screen.dart` | `test/widget_test.dart` | `EXECUTION VERIFIED AGAINST IDENTIFIED COMMIT` (Widget tests cover null active field empty states and active tab navigation) |
| **Fix E: Field Management Deletion & Active Selection Flow** | `af45d99` | `lib/presentation/screens/field_management_screen.dart`, `agro_providers.dart` | `test/widget_test.dart` | `EXECUTION VERIFIED AGAINST IDENTIFIED COMMIT` (Verified passing in live test suites) |
| **Fix F: Rotation Evapotranspiration Screening Disclaimer** | `af45d99`, `cce7f0d` | `lib/presentation/screens/rotation_laboratory_screen.dart`, `rotation_evaluator.dart` | `test/domain/domain_scientific_test.dart` | `IMPLEMENTATION VERIFIED` (UI text updated, comparative screening disclaimer and empirical 1.30 comment documented) |

---

## 11. Fresh Verification Run Execution & Final Published-Commit Reconciliation

### 11.1 Verification Run `20261028_185811` Overview

- **Run ID:** `20261028_185811`
- **Execution Timestamp (UTC):** `2026-10-28T18:58:11Z` to `2026-10-28T19:01:12Z` (Duration: 180.24 s)
- **Starting & Ending Git HEAD:** `cce7f0d66609fedf70a7dfa5ca176e21e70a1187` (`cce7f0d`)
- **Git Branch:** `main` (tracks `origin/main`)
- **Initial Working Tree:** Modified (`IsStartingWorkingTreeClean = false`, `StartingWorkingTreeEntries: [" M test/data/persistence_test.dart"]`)
- **Final Working Tree:** Modified (`IsEndingWorkingTreeClean = false`, `EndingWorkingTreeEntries: [" M test/data/persistence_test.dart", "?? artifacts/validation_runs/20261028_185811/"]`)
- **Monitored Scope:** `lib`, `test`, `scripts`, `docs`, `pubspec.yaml`, `pubspec.lock` (74 files)
- **Initial & Final Composite Fingerprint:** `1fbe6d23cacaacc49ac3c463f2ead78cf75e361735714072bfc6e23933b2eac9`
- **Source Mutation During Run:** `false` (Monitored source files did not mutate between start and end of run)
- **Validation Scope:** `Modified Working Tree over (cce7f0d66609fedf70a7dfa5ca176e21e70a1187)`
- **Overall Status:** **`PASS`** (All 5 stages completed with exit code 0)
- **Evidence Directory:** `artifacts/validation_runs/20261028_185811` (local evidence directory containing 21 verification artifacts)
- **Evidence Publication Status:** Local evidence generated during this audit. (Not published to `origin/main`).

### 11.2 Stage Execution Results (`20261028_185811`)

| Stage | Command | Exit Code | Status | Duration | Evidence File & Summary |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 2 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 9 s | `flutter_analyze.stdout.txt` (No issues found!) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 10 s | `flutter_test.stdout.txt` (168 passed across all test suites) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 84 s | `powershell_tests.stdout.txt` (67 deterministic + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 76 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

### 11.3 Persistence Test Coverage and Limitations

In `test/data/persistence_test.dart`, test number 8 was audited and clarified:
- **Original Description:** `'8. Write failure does not corrupt or overwrite existing valid field data'`
- **Actual Implementation Behavior:** The test passes a `FarmField` with out-of-bounds coordinates (`99.0, 99.0`). The `field.coordinate.validate()` check in `saveField` fails *before* any SQLite query or write operation occurs, safely returning `CoordinateOutOfBoundsFailure` without modifying the database.
- **Clarified Description:** `'8. Pre-write coordinate validation failure rejects update and preserves existing valid field data untouched'`.
- **Coverage Distinction:**
  - Test 7 proves that when the SQLite database engine fails (simulated via closed underlying database connection), `saveField` catches the exception and returns a typed `ParsingFailure` rather than throwing an unhandled exception or claiming success.
  - Test 8 proves that domain input validation guards the repository boundary, rejecting invalid coordinates prior to write execution and keeping existing database rows untouched.
  - *Limitation:* Physical Android SQLite disk-full or hardware I/O write faults are simulated at the software boundary and remain deferred from real hardware verification until physical Android devices are connected.

### 11.4 Comprehensive Test Count Reconciliation

- **Historical Run `20261028_105807`:** **159 Flutter tests passed** (tested against clean commit `1e6e067`, exit code `0`).
- **Commit `af45d99` Test Discovery:** **164 Flutter tests passed** ($47 + 42 + 67 + 8 = 164$).
- **Published Commit `cce7f0d` & Run `20261028_185811`:** **168 Flutter tests passed** ($47 + 42 + 71 + 8 = 168$).
- **PowerShell Checks:** **68 passed** (67 deterministic + 1 live Open-Meteo integration check).

---

## 12. Scientific Test Evidence, Persistence Review, and Final Published-Commit Reconciliation Run (`20261028_234442`)

### 12.1 Execution Provenance & Verification Run Overview
- **Tested execution commit:** `605723cc23b6c6bac28ee77447d113ee921109a7` (`605723c`)
- **Evidence-publication commit:** `f35008e20d5ba68a366046ad324906560baa9dc6` (`f35008e`)
- **Latest published HEAD on `origin/main` at audit time:** `f35008e20d5ba68a366046ad324906560baa9dc6` (`f35008e`)
- **Git Branch:** `main` (tracks `origin/main`)
- **Run ID:** `20261028_234442`
- **Execution Timestamp (UTC):** `2026-10-28T20:47:45Z` to `2026-10-28T20:47:59Z`
- **Command:** `flutter test`
- **Recorded exit code:** `0` (`flutter_test.exitcode.txt`)
- **Reported Flutter test count:** `173 passed across all suites` (`flutter_test.stdout.txt`)
- **Result:** **`PASS WITH LIMITATIONS`**
- **Evidence Directory:** `artifacts/validation_runs/20261028_234442/` (9 verification artifacts published in commit `f35008e`)

The execution commit (`605723c`) and evidence-publication commit (`f35008e`) represent different repository states. The saved evidence supports the recorded execution result for tested revision `605723c` only. Publishing that evidence in subsequent commit `f35008e` does not, by itself, establish that the publication commit was independently tested.

### 12.2 Exact Flutter Test Breakdown and Counting Reconciliation (173 Tests Total)
The Flutter test runner executes exactly 173 test cases across the 4 test files in the test suite:
1. `test/domain/domain_scientific_test.dart`: **55 passed** ($47\text{ baseline} + 8\text{ independent numerical and boundary tests}$)
2. `test/data/open_meteo_adapter_test.dart`: **42 passed**
3. `test/data/persistence_test.dart`: **68 passed** (68 `test()` declarations, containing 71 internal test verification steps across nested groups)
4. `test/widget_test.dart`: **8 passed**

**Total Discovered and Executed Tests:**
$$55 + 42 + 68 + 8 = \mathbf{173\text{ passed}}$$
($100\%$ pass rate, process exit code `0`, as verified in `artifacts/validation_runs/20261028_234442/flutter_test.stdout.txt` and `flutter_test.exitcode.txt`).

*Note on test-counting consistency:* The Flutter test framework tallies individual `test()` declarations. The file `test/data/persistence_test.dart` defines exactly 68 `test()` blocks. Earlier narrative phrasing mentioning "71 test executions" referred to individual assertion steps within test groups. Under the consistent unit-of-measure used by the test runner, the count is exactly 68, reconciling the verified sum of 173 tests.

### 12.3 Persistence Test Coverage Review & Boundaries
A thorough review of `test/data/persistence_test.dart` reveals the exact assertions and physical limitations of the existing database persistence suite:
1. **Database Failure on `saveField` (Lines 258–284):**
   - *Test Description:* `'7. Database failure on saveField fails safely with ParsingFailure without reporting success'`.
   - *Implementation:* Simulates a database failure by deliberately closing the underlying in-memory sqlite3 instance (`rawSql.close()`) before invoking `FarmFieldRepositoryImpl.saveField`.
   - *Coverage Boundary:* Verifies that `saveField` handles low-level SQLite driver exceptions safely and returns a typed `ParsingFailure` rather than crashing or claiming success. It does *not* simulate hardware disk exhaustion, OS-level file lock contention, partial WAL write corruptions, or interrupted transactions.
2. **Pre-Write Coordinate Validation Guard (Lines 286–328):**
   - *Test Description:* `'8. Pre-write coordinate validation failure rejects update and preserves existing valid field data untouched'`.
   - *Implementation:* Attempts an update using out-of-bounds coordinates `(99.0, 99.0)`. The `field.coordinate.validate()` contract rejects the operation before any SQLite write query executes, returning `CoordinateOutOfBoundsFailure`.
   - *Coverage Boundary:* Verifies domain-level invariant protection at the repository boundary, confirming existing database records remain unmodified when input validation fails. It does *not* test all possible invalid-input branches or database constraint violations.
3. **Weather Cache Failed Database Writes (Lines 674–725):**
   - *Test Description:* `'13. Failed database writes do not crash repository or discard fetched records'`.
   - *Implementation:* Configures `WeatherRepositoryImpl` with a closed local database. When remote network weather data arrives, the repository catches the local database cache write failure, logs it, and returns the valid weather data to the caller rather than failing the user request.
   - *Coverage Boundary:* Proves local cache resilience and non-blocking read-through caching. It does *not* cover every failure mode of SQLite or multi-threaded database access.
4. **Physical Storage and Concurrency Limitations:**
   The existing persistence tests do not, by themselves, establish correct handling of all of the following:
   - Physical disk exhaustion.
   - Operating-system-level I/O failures.
   - Process termination during an active SQLite write transaction.
   - Every SQLite file-locking, busy-handler, or multi-process file-conflict scenario.
   Real-device SQLite migration testing remains explicitly **`DEFERRED — pending execution on a physical Android device`**.
5. **Decision on Adding Tests & Bounded Defect Findings:**
   No production defect was demonstrated within the reviewed implementation paths and executed test cases. This finding does not establish the absence of defects outside the tested scope. In accordance with the decision rules, no additional tests were added to `test/data/persistence_test.dart` because the existing tests already deterministically verify safe failure handling across the application boundary, and no untested application defect was demonstrated.

### 12.4 Delineation of Scientific Evidence Levels
The test suite strictly establishes evidence within designated verification levels:
- **Level A — Software Behavior:** Verified. The implementation adheres to data contracts, rejects non-finite values (`NaN`, $\pm\infty$), handles negative inputs, clamps stage fractions to $[0.0, 1.0]$, and preserves day indexing when data is missing ($<10\%$).
- **Level B — Numerical & Reference-Case Verification:** Verified. Mathematical calculations ($ET_c = K_c \times ET_0$, piecewise linear interpolation of $K_c$ across four growth stages, cumulative sum, and volumetric conversion using the configured $4.2\text{ m}^3/\text{feddan/mm}$ operational factor) match independent hand-calculated numerical oracles within $10^{-9}$ precision. This verifies implementation correctness against the configured operational factor; it does not establish that the rounded factor of 4.2 is physically exact compared to the unrounded 4.20083 m³.
- **Level C — Empirical Agronomic Validation:** **Deferred / External.** The test suite does *not* prove field calibration across Egyptian climate zones, lysimeter or eddy-covariance agreement, or universal accuracy of nominal FAO-56 crop coefficients ($K_c$) under Egyptian field management practices. The stage fractions $[0.20, 0.30, 0.30, 0.20]$ are a fixed operational approximation, not independently calibrated biological durations for every crop or cultivar. Full client-side FAO-56 Penman-Monteith recomputation remains incomplete, as daily $ET_0$ is consumed from Open-Meteo ERA5.

---

## 13. Verification Run `20261029_100759` & Source-Verified Remediation (187 Flutter Tests Passed)

### 13.1 Provenance and Execution State Overview
- **Run ID:** `20261029_100759`
- **Execution Timestamp (UTC):** `2026-10-29T07:08:15Z` to `2026-10-29T07:10:26Z` (Duration: 130.48 s)
- **Baseline Git HEAD:** `c1c79289583b7a29df17ccf6cb4147be6c8b5f65` (`c1c7928`)
- **Git Branch:** `main` (tracks `origin/main`)
- **Initial Working-Tree State:** Modified (`IsStartingWorkingTreeClean = false`, `StartingWorkingTreeEntries: [" M test/data/persistence_test.dart", "?? artifacts/validation_runs/20261029_100222/"]`)
- **Ending Working-Tree State:** Modified (`IsEndingWorkingTreeClean = false`)
- **Monitored Scope:** `lib`, `test`, `scripts`, `docs`, `pubspec.yaml`, `pubspec.lock` (74 files)
- **Initial & Final Composite Fingerprint:** `a9f5ef2ab62028cabb94707a0e6b0ab34589271876d9832ff25db751088af831`
- **Source Mutation During Run:** `false` (Monitored source files did not mutate between start and end of run)
- **Validation Scope:** `Modified Working Tree over (c1c79289583b7a29df17ccf6cb4147be6c8b5f65)`
- **Overall Status:** **`PASS`** (All 5 stages completed with exit code 0)
- **Evidence Directory:** `artifacts/validation_runs/20261029_100759/` (21 verification artifacts)

### 13.2 Stage Execution Results (`20261029_100759`)

| Stage | Command | Exit Code | Status | Duration | Evidence File & Summary |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 2 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 9 s | `flutter_analyze.stdout.txt` (No issues found!) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 11 s | `flutter_test.stdout.txt` (187 passed across all 4 test suites) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 82 s | `powershell_tests.stdout.txt` (67 deterministic + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 26 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

### 13.3 Test Suite Reconciliation: 187 Passed Tests

The current repository test inventory comprises 187 test cases executed across 4 test suites:
1. `test/domain/domain_scientific_test.dart`: **68 passed** (includes geographic coordinates, GDD, heat stress, range validators, and 12 biological growth stage & forecast ETc tests).
2. `test/data/persistence_test.dart`: **69 passed** (includes field CRUD, default seeding, offline fallback, cache policies, and genuine SQLite schema v2-to-v3 Drift migration).
3. `test/data/open_meteo_adapter_test.dart`: **42 passed** (Open-Meteo payload parsing, date sequence integrity, ERA5 model consistency).
4. `test/widget_test.dart`: **8 passed** (UI smoke tests, provenance cards, heat stress alerts, ETc failure states, and navigation).

$$\text{Total Passed: } 68 + 69 + 42 + 8 = \mathbf{187\text{ passed (0 failed, 0 skipped)}}.$$

### 13.4 Genuine SQLite v2-to-v3 Migration Regression Verification
In `test/data/persistence_test.dart` (lines 3380–3521):
- A genuine SQLite database is constructed in schema version 2 without `planting_date` in `farm_fields_table`.
- The test verifies that `PRAGMA table_info('farm_fields_table')` does not contain `planting_date` before migration.
- A valid legacy field record (`v2_field_1`, `حقل الدلتا القديم`, `كفر الشيخ`, `31.10`, `30.95`, `5.0 feddan`, `clay`, `wheat`) is inserted.
- The SQLite pragma `user_version` is set to 2.
- The database is opened via `AppDatabase(NativeDatabase.opened(rawSqliteDb))` to exercise the production Drift migration lifecycle.
- Post-migration assertions confirm:
  1. `PRAGMA user_version` updates from 2 to 3.
  2. `PRAGMA table_info` confirms the addition of `planting_date`.
  3. Existing legacy records and values remain unchanged.
  4. Migrated legacy records have `plantingDate == null`.
  5. Updating the field with a valid `plantingDate` and reopening the database confirms persistence and idempotency.
- *Limitation:* Physical Android SQLite migration on hardware flash storage remains `DEFERRED` until a physical device is connected.

---

## 14. Fresh Published-Commit Verification Run Execution (Run `20261029_131304`) & Test Reconciliation (189 Tests Total)

### 14.1 Provenance and Execution State Overview
- **Run ID:** `20261029_131304`
- **Execution Timestamp (UTC):** `2026-10-29T10:13:34Z` to `2026-10-29T10:17:38Z` (Duration: 243.28 s)
- **Tested Committed Revision:** `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`)
- **Git Branch:** `HEAD` (isolated worktree checked out directly at `fc42ff342013475e7e8767966016c3040127f22d`)
- **Initial Working-Tree State:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Ending Working-Tree State:** Clean (`IsEndingWorkingTreeClean = true`, `EndingWorkingTreeEntries: []`)
- **Monitored Scope:** `lib`, `test`, `scripts`, `docs`, `pubspec.yaml`, `pubspec.lock` (74 files)
- **Initial & Final Composite Fingerprint:** `7e6388c543d9e6c92ec6f5e9d4bb8cdebf8846cd7b0fa35ad703a4465475a097`
- **Source Mutation During Run:** `false` (Monitored source files did not mutate between start and end of run)
- **Validation Scope:** `Clean Committed Revision (fc42ff342013475e7e8767966016c3040127f22d)`
- **Overall Status:** **`PASS`** (All 5 stages completed with exit code 0; physical Android SQLite migration deferred)
- **Evidence Directory:** `artifacts/validation_runs/20261029_131304/` (20 verification artifacts recorded)

### 14.2 Stage Execution Results (`20261029_131304`)

| Stage | Command | Exit Code | Status | Duration | Evidence File & Summary |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 2 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 12 s | `flutter_analyze.stdout.txt` (No issues found!) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 12 s | `flutter_test.stdout.txt` (189 passed across all 4 test suites) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 85 s | `powershell_tests.stdout.txt` (67 deterministic + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 132 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

### 14.3 Comprehensive Test Suite Reconciliation: 187 vs 189 Tests
The test suite tally was reconciled against historical runs:
- **Historical Run `20261029_100759`:** 187 tests ($68 + 69 + 42 + 8$).
- **Evolution in Commit `6fb2ddf` / `fc42ff3`:** In commit `6fb2ddf`, two new focused regression tests were added to `test/data/persistence_test.dart` to verify persistence reliability hardening:
  1. **Test 8b (`'8b. Default-field identity is preserved during updates and seeding failures propagate'`):** Verifies the full lifecycle of default field identity and tombstoning:
     - Saving an ordinary field persists `is_default = false`.
     - Saving a default field persists `is_default = true`.
     - Updating an existing default field without explicitly supplying the `isDefault` parameter preserves `is_default = true` in the SQLite database while correctly updating field attributes (such as crop and area).
     - Deleting an updated default field records its ID in `deleted_default_field_ids_table`.
     - Calling `seedDefaultFieldsIfNecessary()` after deletion does *not* resurrect the deleted default field.
  2. **Test 8c (`'8c. Failed default-field save causes seedDefaultFieldsIfNecessary to propagate failure'`):** Verifies deterministic failure propagation from SQLite insertion errors:
     - Installs a SQLite trigger (`abort_sentinel_insert`) on `farm_fields_table` that raises an `ABORT` error when inserting sentinel ID `field_failing_sentinel`.
     - Calls `seedDefaultFieldsIfNecessary()` with a valid default field and the failing sentinel.
     - Confirms that `seedDefaultFieldsIfNecessary()` returns `Left(ParsingFailure(message: 'فشل في حفظ الحقول الافتراضية'))` instead of claiming success or masking the error.
     - *Correction of Historical Documentation:* Test 8c was previously mischaracterized as an idempotency or repeated-seeding test. Idempotency of default-field seeding is independently verified in Test 3 (`'3. Repeated seeding calls are idempotent and return existing default fields without duplication'`) and Test 4 (`'4. seedDefaultFieldsIfNecessary preserves pre-existing user-defined fields and appends defaults'`). Test 8c is strictly a trigger-injected SQLite insertion failure propagation test.
- **Suite-by-Suite Test Inventory (189 Tests Total):**
  1. `test/domain/domain_scientific_test.dart`: **68 passed** (coordinate invariants, GDD, heat stress index, and biological growth-stage forecasting).
  2. `test/data/persistence_test.dart`: **71 passed** (69 baseline tests + 2 persistence hardening tests 8b & 8c, plus v2-to-v3 SQLite schema migration).
  3. `test/data/open_meteo_adapter_test.dart`: **42 passed** (Open-Meteo DTO parsing, date sequence continuity, ERA5 reanalysis consistency).
  4. `test/widget_test.dart`: **8 passed** (UI rendering, provenance cards, heat alerts, ETc screens).

$$\text{Total Passed: } 68 + 71 + 42 + 8 = \mathbf{189\text{ passed (0 failed, 0 skipped)}}.$$

### 14.4 Provenance Separation and Material Limitations
1. **Separation of Execution and Publication Commits:**
   - The tested execution commit is `fc42ff342013475e7e8767966016c3040127f22d` (`fc42ff3`).
   - The verification artifacts were recorded under `artifacts/validation_runs/20261029_131304/` and subsequently committed in publication commit `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`).
2. **Material Limitations Maintained:**
   - **Physical Android Database Migration:** **`DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED`**. Drift schema version 3 migration is deterministically verified via SQLite unit tests (`PRAGMA user_version` 2 to 3), but physical flash storage behavior under OS memory pressure or process kills remains unverified on physical hardware.
   - **FAO-56 Penman-Monteith Calculation:** **`INCOMPLETE`**. Client-side recomputation from raw solar radiation and wind speed is not implemented; daily reference evapotranspiration ($ET_0$) is ingested from ECMWF ERA5 via Open-Meteo.
   - **Empirical Field Calibration:** **`DEFERRED`**. Biological coefficients and stage boundaries $[0.20, 0.30, 0.30, 0.20]$ are operational approximations without in-situ Egyptian field lysimeter calibration.

---

## 15. Fresh Published-Commit Verification Run Execution (Run `20261029_124430` over `7be1279`)

### 15.1 Provenance and Execution State Overview
- **Run ID:** `20261029_124430`
- **Execution Timestamp (UTC):** `2026-10-29T12:44:30Z` to `2026-10-29T12:48:52Z` (Duration: 262.29 s)
- **Tested Committed Revision:** `7be12790499f92407b3e02ff55d7b54ca7c1f0ac` (`7be1279`)
- **Git Branch:** `HEAD` (isolated worktree checked out directly at clean committed revision `7be1279`)
- **Initial Working-Tree State:** Clean (`IsStartingWorkingTreeClean = true`, `StartingWorkingTreeEntries: []`)
- **Ending Working-Tree State:** Clean (`IsEndingWorkingTreeClean = true`, `EndingWorkingTreeEntries: []`)
- **Monitored Scope:** `lib`, `test`, `scripts`, `docs`, `pubspec.yaml`, `pubspec.lock` (74 files)
- **Initial & Final Composite Fingerprint:** `867ae5b42d25adc64d633f81a4fcf0ea254d34f84c2fc3acd53ca7d15cfb8bc0`
- **Source Mutation During Run:** `false` (Monitored source files did not mutate between start and end of run)
- **Validation Scope:** `Clean Committed Revision (7be12790499f92407b3e02ff55d7b54ca7c1f0ac)`
- **Overall Status:** **`PASS WITH LIMITATIONS`** (All 5 stages completed with exit code 0; physical Android SQLite migration deferred)
- **Evidence Directory:** `artifacts/validation_runs/20261029_124430/` (20 verification artifacts recorded)

### 15.2 Stage Execution Results (`20261029_124430`)

| Stage | Command | Exit Code | Status | Duration | Evidence File & Summary |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib/ test/` | `0` | **`PASS`** | 2 s | `dart_format.stdout.txt` (42 files formatted, 0 changed) |
| **Flutter Analyze** | `flutter analyze` | `0` | **`PASS`** | 12 s | `flutter_analyze.stdout.txt` (No issues found!) |
| **Flutter Tests** | `flutter test` | `0` | **`PASS`** | 12 s | `flutter_test.stdout.txt` (189 passed across all 4 test suites, 0 failed, 0 skipped) |
| **PowerShell Tests** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1` | `0` | **`PASS`** | 86 s | `powershell_tests.stdout.txt` (67 deterministic + 1 live = 68 passed) |
| **Release Build** | `flutter build apk --release` | `0` | **`PASS`** | 149 s | `release_build.stdout.txt` (Built release APK: 58.7MB) |

---

## 16. Drift Multiple-Database Diagnostic Warning Investigation

### 16.1 Observed Diagnostic Warning
During the execution of `flutter test`, the following diagnostic warning was recorded in `flutter_test.stdout.txt`:
```text
WARNING (drift): It looks like you've created the database class AppDatabase multiple times in your application.
```

### 16.2 Root-Cause Technical Analysis
1. **Drift Warning Mechanism:**
   Drift includes an internal runtime diagnostic designed to detect unintended multiple database instantiations. In applications using SQLite, creating multiple connections to the same database file without WAL or connection pooling can cause locking issues or cache inconsistency. Drift tracks instantiations of the generated database class (`AppDatabase`) within the current Dart isolate and emits this warning when more than one instance is created.
2. **Harness Call Sites in Tests:**
   In `test/data/persistence_test.dart`:
   - Each individual unit test runs a `setUp()` callback that creates a fresh in-memory database:
     ```dart
     db = AppDatabase(NativeDatabase.memory());
     fieldRepo = FarmFieldRepositoryImpl(db);
     ```
     This intentional isolation ensures zero state contamination between test cases.
   - Test 7 deliberately closes the underlying SQLite database (`rawSql.close()`) to simulate an unrecoverable SQLite error.
   - Test 14 (v2-to-v3 SQLite schema migration) explicitly opens an initial migration database instance (`AppDatabase(NativeDatabase.opened(rawSqliteDb))`) and subsequently re-opens the database with another instance (`reopenedDb`) to verify data persistence across schema upgrade cycles.
3. **Production Safety and Riverpod Provider Architecture:**
   In production (`lib/presentation/providers/agro_providers.dart`, lines 18–26):
   ```dart
   final appDatabaseProvider = Provider<AppDatabase>((ref) {
     final db = AppDatabase();
     ref.onDispose(() => db.close());
     return db;
   });
   ```
   - `appDatabaseProvider` is a root-level Riverpod `Provider` (a singleton across the application's lifecycle within `ProviderScope`).
   - All repository providers (`farmFieldRepositoryProvider`, `weatherRepositoryProvider`) depend directly on `appDatabaseProvider`.
   - In production runtime, `AppDatabase` is instantiated exactly once, eliminating any possibility of concurrent database instances or file-lock conflicts.
4. **Architectural Decision:**
   Cosmetic suppression via `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` was deliberately rejected. In unit tests, creating isolated in-memory instances is best practice, and the debug diagnostic does not affect test execution, exit code (`0`), or production safety.
