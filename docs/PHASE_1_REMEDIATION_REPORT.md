# AgroShift — Phase 1 Remediation Report: Scientific Data Integrity & Critical Corrections

**Date:** 2026-10-24  
**Scope:** Minimal, evidence-driven Phase 1 remediation pass on AgroShift.  
**Workspace:** `D:\Programming projects\agro_shift\`  
**Governing References:** FAO Irrigation and Drainage Paper No. 56, McMaster & Wilhelm (1997) *Agric. For. Meteorol.*, Open-Meteo API Documentation & Live Probing.

---

## 1. Executive Summary of Corrections

Phase 1 addressed four critical areas identified in the independent audit without rewriting the architecture or altering unrelated components:

1. **Historical Weather Availability & Handling:**
   - Probed the live Open-Meteo Historical Archive API to ascertain actual temporal constraints.
   - Identified that while Open-Meteo allows queries up to the current date, any date in the future (even tomorrow by timezone drift) returns HTTP 400 with explicit error payloads.
   - Guarded against invalid date ranges (`startDate > endDate`), clamped requests safely to current local/UTC date, and parsed real API error messages (`reason`) into `NetworkFailure` rather than generic catch-all errors.

2. **Accurate Presentation of Crop Evapotranspiration ($ET_c$):**
   - Preserved the FAO-56 single-crop calculation $ET_c = K_c \times ET_0$.
   - Removed misleading UI labels presenting $ET_c \times 4.2$ as "الطلب المائي التقديري" ("Estimated Irrigation Demand").
   - Explicitly relabeled the metric to "الاستهلاك المائي التبخري للمحصول (ETc) — فترة 7 أيام" (Crop Evapotranspiration over 7-day period) in [dashboard_screen.dart](file:///D:/Programming%20projects/agro_shift/lib/presentation/screens/dashboard_screen.dart).
   - Clarified the theoretical草 reference nature of the 30-day cumulative $ET_0$ volume in [environmental_analysis_screen.dart](file:///D:/Programming%20projects/agro_shift/lib/presentation/screens/environmental_analysis_screen.dart).
   - Did not introduce arbitrary leaching fractions, efficiency numbers, or unverified irrigation coefficients in this phase.

3. **Variable-Specific Missing-Data Validation:**
   - Updated [open_meteo_adapter.dart](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/remote/open_meteo_adapter.dart) to track missingness independently across $T_{2m}$, $ET_0$, and precipitation.
   - Enforced the 10% maximum missingness policy on all three variables.
   - Ensured that legitimate measured zero values ($0.0\text{ mm}$ precipitation) are preserved as `0.0` while `null` values are strictly tracked and never silently coerced into zero.
   - Enhanced [failures.dart](file:///D:/Programming%20projects/agro_shift/lib/core/error/failures.dart) so `InsufficientEvidenceFailure` conveys the specific failing variable name and exact missing ratio.

4. **GDD Upper-Threshold Edge Case Resolution:**
   - In [gdd_calculator.dart](file:///D:/Programming%20projects/agro_shift/lib/domain/agronomy/science/gdd_calculator.dart), resolved the extreme heatwave anomaly where effective $T_{\min}$ exceeded effective $T_{\max}$ when minimum temperatures stay above $T_{\text{cutoff}}$.
   - Capped effective $T_{\min}$ at $T_{\text{cutoff}}$ and ensured $\text{effective } T_{\min} \le \text{effective } T_{\max}$ in accordance with standard agro-meteorological practice (McMaster & Wilhelm, 1997 Method 1).

---

## 2. Before-and-After Analysis

| Area | Before Phase 1 | After Phase 1 |
|---|---|---|
| **Historical Weather Requests** | Unchecked dates passed to remote API. Future dates returned HTTP 400 that surfaced as generic network failure. | Clamped `endDate` to `DateTime.now()`, prevented `startDate > endDate`, and extracted real API error reason from HTTP 400 responses. |
| **ETc UI Presentation** | Presented $ET_c$ directly as "الطلب المائي التقديري للفدان" ("Estimated Irrigation Demand"), misrepresenting pure atmospheric loss as gross field irrigation water. | Renamed to "الاستهلاك المائي التبخري للمحصول (ETc)" with explicit explanatory disclaimer explaining that field irrigation efficiency and leaching fractions must be factored in for actual gross duty. |
| **Missing-Data Validation** | Only $T_{\max}$ and $T_{\min}$ incremented `missingDataCount`. Responses with 100% missing $ET_0$ or precipitation passed validation and downstream code summed `null` to `0.0`. | Independent counters `missingTempCount`, `missingEt0Count`, and `missingPrecipCount`. If any variable exceeds 10% missingness, fails with `InsufficientEvidenceFailure` detailing the offending variable. |
| **GDD Calculation** | $T_{\max}$ capped at $T_{\text{cutoff}}$, but $T_{\min}$ only floored at $T_{\text{base}}$. When $T_{\min} > T_{\text{cutoff}}$, effective $T_{\min}$ exceeded effective $T_{\max}$ ($32^\circ\text{C} > 30^\circ\text{C}$). | $T_{\min}$ also capped at $T_{\text{cutoff}}$ and clamped so effective $T_{\min} \le$ effective $T_{\max}$, producing biologically consistent thermal accumulation. |
| **Code Formatting** | Formatting drift in `test/widget_test.dart` (failing `dart format --set-exit-if-changed`). | Clean 0-drift formatting across all 34 project files. |
| **Widget Responsiveness** | Static row in dashboard water card overflowed by 28px in RTL mode during widget pump. | Text wrapped in `Expanded` widget; smoke tests pass with 0 layout overflows. |

---

## 3. Files Modified

1. [`lib/core/error/failures.dart`](file:///D:/Programming%20projects/agro_shift/lib/core/error/failures.dart)
   - Extended `InsufficientEvidenceFailure` with optional `variableName`, `missingCount`, and `totalCount` parameters for precise scientific auditing.
2. [`lib/domain/agronomy/science/gdd_calculator.dart`](file:///D:/Programming%20projects/agro_shift/lib/domain/agronomy/science/gdd_calculator.dart)
   - Corrected high-temperature cutoff logic to cap effective $T_{\min}$ at $T_{\text{cutoff}}$ and enforce effective $T_{\min} \le$ effective $T_{\max}$.
3. [`lib/data/datasources/remote/open_meteo_adapter.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/remote/open_meteo_adapter.dart)
   - Implemented three independent missingness trackers (`missingTempCount`, `missingEt0Count`, `missingPrecipCount`).
   - Added validation gates returning `InsufficientEvidenceFailure` if any required variable exceeds the 10% threshold.
4. [`lib/data/repositories/weather_repository_impl.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/repositories/weather_repository_impl.dart)
   - Clamped `endDate` to `DateTime.now()` to prevent out-of-range API errors.
   - Added validation preventing `startDate > endDate`.
   - Extracted API `reason` string from Dio 400 responses for transparent error reporting.
5. [`lib/presentation/screens/dashboard_screen.dart`](file:///D:/Programming%20projects/agro_shift/lib/presentation/screens/dashboard_screen.dart)
   - Relabeled water metric card from "الطلب المائي التقديري" to "الاستهلاك المائي التبخري للمحصول (ETc) — فترة 7 أيام".
   - Added agronomic caveat explaining that $ET_c$ does not include irrigation network efficiency or leaching.
   - Wrapped title text in `Expanded` to prevent RenderFlex overflow.
6. [`lib/presentation/screens/environmental_analysis_screen.dart`](file:///D:/Programming%20projects/agro_shift/lib/presentation/screens/environmental_analysis_screen.dart)
   - Relabeled 30-day cumulative volume to "المعادل الحجمي النظري للبخر المرجعي" with note that it applies to reference grass surface ($ET_0$).
7. [`test/domain/domain_scientific_tests.dart`](file:///D:/Programming%20projects/agro_shift/test/domain/domain_scientific_tests.dart)
   - Added boundary tests for GDD: severe heatwave where $T_{\min} > T_{\text{cutoff}}$, boundary thresholds where $T_{\min} = T_{\text{base}}$ and $T_{\max} = T_{\text{cutoff}}$, and cold boundary crossing $T_{\text{base}}$.
8. [`test/data/open_meteo_adapter_tests.dart`](file:///D:/Programming%20projects/agro_shift/test/data/open_meteo_adapter_tests.dart)
   - Added tests verifying rejection of series when $ET_0$ is missing $>10\%$, rejection when precipitation is missing $>10\%$, acceptance of valid series with missingness within $10\%$, and preservation of legitimate $0.0\text{ mm}$ precipitation and `null` values.
9. [`test/widget_test.dart`](file:///D:/Programming%20projects/agro_shift/test/widget_test.dart)
   - Re-formatted to resolve Dart code style check.

---

## 4. Verification Commands & Actual Results

Every required command was run directly on the local Windows development environment:

| Step | Command Executed | Exit Code | Result |
|---|---|---|---|
| **1. Formatting** | `dart format --output=none --set-exit-if-changed .` | `0` | `Formatted 34 files (0 changed) in 0.27 seconds.` |
| **2. Static Analysis** | `flutter analyze` | `0` | `No issues found! (ran in 4.9s)` |
| **3. Test Suite** | `flutter test test/domain/domain_scientific_tests.dart test/data/open_meteo_adapter_tests.dart test/widget_test.dart` | `0` | `30/30 passed (00:02)` |
| **4. Release APK Build** | `flutter build apk --release` | `0` | `Built build\app\outputs\flutter-apk\app-release.apk (51.5MB, 63.0s)` |

### Test Breakdown (30 Tests Total):
- **Geographic & Coordinate Validation:** 4 tests passing.
- **Physical Range Validation:** 5 tests passing.
- **GDD Calculation & Boundary Edge Cases:** 6 tests passing (including newly added heatwave cutoff and threshold tests).
- **$ET_c$ & Volumetric Conversions:** 3 tests passing.
- **Heat Stress Phenological Risk:** 2 tests passing.
- **Multi-Season Crop Rotation Comparison:** 3 tests passing.
- **OpenMeteo Adapter & Provenance:** 6 tests passing (including newly added variable-specific missingness and $0.0$ preservation tests).
- **Bootstrap Smoke Test:** 1 widget test passing without overflow.

---

## 5. Remaining Limitations & Agricultural Assumptions Left Unchanged

In strict adherence to the Phase 1 constraints, the following items were **deliberately preserved without speculative modification**:

1. **Local State Persistence (Volatile Memory):**
   - Farm fields and weather caching remain in volatile memory. Local database integration (e.g. SQLite/Drift) is reserved for Phase 2.
2. **Gross Irrigation Duty Formulation:**
   - Field irrigation efficiency ($\eta_{\text{irrigation}}$) and leaching requirements ($LR$) were intentionally **not** hardcoded or guessed. The UI was adjusted to accurately state that the calculation reflects net $ET_c$, awaiting user input on field irrigation methods (drip vs. flood).
3. **Paddy Rice Water Dynamics:**
   - The rotation laboratory calculation for rice was preserved as an indicative scenario comparison. Explicit puddling and percolation modeling will be calibrated in a future phase with authoritative Egyptian ARC SWERI data.
4. **Soil Nitrogen Representation:**
   - The qualitative 3-state categorization (`positiveEnrichment`, `neutralOrBalanced`, `cumulativeDepletion`) was preserved. No speculative quantitative nitrogen kilograms were invented.
5. **Weather Data Provenance:**
   - Clear attribution to Open-Meteo ERA5-Land Archive and High-Resolution Forecast models is maintained throughout the UI.

> **Production Readiness Statement:**  
> While all code formatting, static analysis, unit tests, and APK build pipelines passed with zero errors, AgroShift remains **CONDITIONALLY VALID / PROTOTYPE GRADE** until on-disk persistence (Phase 2) and localized field calibration are completed.
