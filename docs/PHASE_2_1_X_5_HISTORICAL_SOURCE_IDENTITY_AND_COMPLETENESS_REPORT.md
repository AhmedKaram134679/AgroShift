# AgroShift — Phase 2.1.x.5: Historical Source Identity & Completeness Audit Report

**Author:** Senior Flutter/Dart Engineer  
**Date:** 2026-10-25  
**Workspace:** `d:\Programming projects\agro_shift`  
**Status:** COMPLETE — READY FOR REVIEW  
**Test Suite:** 106/106 Passed | **Static Analysis:** 0 Issues | **Release APK:** 58.7 MB

---

## A. Executive Summary

Phase 2.1.x.5 is **complete**. Every verified risk in the historical weather-data pipeline, response completeness, model specification, and scientific documentation has been resolved:
1. **Explicit Open-Meteo Model Identity:** Outgoing historical requests in `OpenMeteoRemoteDataSource` now explicitly specify `models=era5_land`.
2. **Rejection of Empty Historical Responses:** Empty responses for non-empty requested periods fail validation (`ParsingFailure`), are never stored in cache, and cannot overwrite valid cached data.
3. **Raw Period Completeness:** `OpenMeteoAdapter` enforces that the raw response begins exactly on `expectedStartDate`, ends exactly on `expectedEndDate`, and contains exactly `expectedCount` contiguous daily entries before domain-level temperature filtering is applied.
4. **Mandatory Daily Arrays:** All four essential agronomic arrays (`temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, `precipitation_sum`) are strictly mandatory and must match the raw `time` array length.
5. **Scientific Threshold Alignment:** Harmonized documentation in `DATA_SOURCES_AND_VALIDATION.md` to reflect the physical envelope enforced in code ($[-5.0, +55.0]^\circ\text{C}$ with $T_{\max} \ge T_{\min}$) and explained regional agricultural baseline expectations.
6. **NASA POWER & ET0 Audits:** Documented exact MERRA-2 ($0.5^\circ \times 0.625^\circ$) and CERES ($1.0^\circ \times 1.0^\circ$) spatial resolutions, verified that daily FAO-56 $ET_0$ is directly supplied by Open-Meteo, and clarified that NASA POWER is a reference baseline not queried at runtime.
7. **Provenance Traceability:** Audited `DataSourceProvenance`, cataloging implemented, derivable, and non-sourced fields.

---

## B. Findings Matrix

| Finding | Classification | Explanation |
|---|---|---|
| Open-Meteo Model Identity Parameter | **Confirmed and Fixed** | `fetchHistoricalDaily` previously omitted the `models` parameter, relying on API defaults. Explicitly added `'models': 'era5_land'`. |
| Empty Historical Response Handling | **Confirmed and Fixed** | An empty `time` array previously returned `Success([])` if `expectedCount` was not provided, and `isHistoricalValid` returned `true` for empty lists. Now returns typed `ParsingFailure`, rejects empty lists in `isHistoricalValid`, and prevents cache overwrites. |
| Raw Period Subsets (Omitting Start/End) | **Confirmed and Fixed** | `OpenMeteoAdapter` previously verified range containment and daily spacing, but a consecutive subset omitting the beginning or end of the interval could pass if `expectedCount` was omitted. Now strictly validates `parsedRawDates.first == expectedStartDate` and `parsedRawDates.last == expectedEndDate`. |
| Missing Mandatory Daily Arrays | **Confirmed and Fixed** | `et0List` and `pList` were nullable without non-null enforcement. Now strictly enforced as mandatory parallel arrays matching `time.length`. |
| Temperature Threshold Documentation Discrepancy | **Confirmed and Fixed** | `DATA_SOURCES_AND_VALIDATION.md` listed separate regional ranges ($[+5, 55]$ and $[-5, 42]$), whereas code enforces the absolute climatic limits ($[-5, 55]$ with $T_{\max} \ge T_{\min}$). Documented both the code threshold and regional expectation. |
| NASA POWER Spatial Resolution Claims | **Confirmed and Fixed** | Corrected table in `DATA_SOURCES_AND_VALIDATION.md` to distinguish MERRA-2 atmospheric data ($0.5^\circ \times 0.625^\circ$) from satellite solar flux data ($1.0^\circ \times 1.0^\circ$). |
| NASA POWER FAO-56 $ET_0$ Availability | **Confirmed and Fixed** | Clarified that MERRA-2 provides raw fluxes; FAO-56 $ET_0$ in AgroShift is consumed directly from Open-Meteo's upstream FAO-56 Penman-Monteith implementation and not calculated locally. |
| Provenance Model Scope | **Confirmed and Fixed** | Audited all 8 provenance requirements against `DataSourceProvenance`, documenting stored, derivable, and unavailable fields. |

---

## C. Exact Files Changed

1. `lib/data/datasources/remote/open_meteo_remote_data_source.dart`:
   - Added `'models': 'era5_land'` to the query parameters in `fetchHistoricalDaily()`.
2. `lib/data/datasources/remote/open_meteo_adapter.dart`:
   - Made `et0List` and `pList` mandatory alongside `tMaxList` and `tMinList`.
   - Disallowed empty `times` array for any historical retrieval, returning `ParsingFailure`.
   - Added exact boundary checks: `parsedRawDates.first.isAtSameMomentAs(normalizedExpectedStart)` and `parsedRawDates.last.isAtSameMomentAs(normalizedExpectedEnd)`.
3. `lib/data/repositories/weather_repository_impl.dart`:
   - Updated `isHistoricalValid()` to reject empty lists (`if (records.isEmpty) return false`).
   - Calculated `expectedDays = effectiveEndDate.difference(normStartDate).inDays + 1` and passed `expectedCount: expectedDays` to `OpenMeteoAdapter.toDomainRecords()`.
   - Prevented empty records from being saved to L1 or SQLite caches (`if (records.isNotEmpty)`).
4. `test/data/open_meteo_adapter_tests.dart`:
   - Added 10 tests in `Phase 2.1.x.5: Period Completeness and Mandatory Arrays Tests` covering start/end omission, exact interval matching, empty responses, missing arrays, array length mismatches, and null vs 0.0 preservation.
5. `test/data/persistence_tests.dart`:
   - Added Test 56 (outgoing request explicitly includes `models=era5_land`).
   - Added Test 57 (empty raw response is rejected and does not overwrite valid cache).
   - Added Test 58 (`isHistoricalValid` rejects empty records).
6. `docs/DATA_SOURCES_AND_VALIDATION.md`:
   - Updated Section 1 (Open-Meteo `models=era5_land`, NASA POWER MERRA-2 vs CERES resolution).
   - Updated Section 2 (temperature limits vs regional expectation).
   - Updated Section 4 (provenance field audit).

---

## D. Scientific and API Decisions

- **Open-Meteo Model:** Explicitly configured as `models=era5_land` on `https://archive-api.open-meteo.com/v1/archive`.
- **Historical Availability Delay:** Maintained at 5 calendar days based on official Open-Meteo documentation for ERA5-Land.
- **Mandatory Variables:** `temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, and `precipitation_sum` are strictly required. Missing arrays trigger `ParsingFailure`.
- **Temperature Limits:** Code enforces $[-5.0, +55.0]^\circ\text{C}$ with $T_{\max} \ge T_{\min}$ to prevent rejecting valid winter extremes in Sinai or nocturnal desert heat in Upper Egypt.
- **Reference $ET_0$ Sourcing:** Directly ingested from Open-Meteo daily endpoint (`et0_fao_evapotranspiration`), which computes $ET_0$ upstream using the FAO-56 Penman-Monteith standard equations.
- **Provenance Status:** `DataSourceProvenance` captures provider, dataset label, requested coordinate, grid coordinate, grid elevation, acquisition timestamp, Arabic disclaimer, and stale fallback flag. Distance is derivable via haversine; local ground elevation is not sourced upstream and is not fabricated.

---

## E. Tests Actually Run

1. `dart format lib/ test/`:
   - **Status:** PASS (0 files with formatting violations).
2. `flutter analyze`:
   - **Status:** PASS (`No issues found!`, ran in 5.2s).
3. `flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart`:
   - **Status:** PASS (106 tests executed, 106 passed in 00:04).
4. `flutter build apk --release`:
   - **Status:** PASS (built `build\app\outputs\flutter-apk\app-release.apk`, 58.7 MB in 53.2s).

---

## F. Regression Coverage

- **New Tests (13 total):**
  - Adapter: June 1–20 returned when June 1–30 requested (omits end) rejected.
  - Adapter: June 5–30 returned when June 1–30 requested (omits start) rejected.
  - Adapter: June 1–29 returned when June 1–30 requested (off by one) rejected.
  - Adapter: June 1–30 returned completely accepted.
  - Adapter: Empty raw response rejected.
  - Adapter: Missing mandatory ET0 array rejected.
  - Adapter: Missing mandatory precipitation array rejected.
  - Adapter: Mismatched ET0 array length rejected.
  - Adapter: Mismatched precipitation array length rejected.
  - Adapter: Legitimate null measurements preserved and distinct from 0.0.
  - Persistence: Outgoing request contains `models=era5_land`.
  - Persistence: Empty raw historical response rejected and cannot overwrite valid cache.
  - Persistence: `isHistoricalValid` rejects empty records.
- **Existing Tests Preserved (93 total):**
  - Cairo DST start/end exact UTC boundaries (Tests 33, 34).
  - Cairo midnight rollover in summer and winter (Test 35).
  - Timezone calculation independent of device local clock (Test 36).
  - Forecast start date validation and sequence completeness (Tests 37, 38).
  - 5-day historical publication delay clamping and cutoff validation (Tests 39–43).
  - L1 memory cache and L2 SQLite cache 6h forecast and 7d historical TTLs (Tests 50–53).
  - Stale fallback on transient errors and rejection on HTTP 400 (Tests 54, 55).
  - Agronomic calculation models: GDD, ETc, volumetric conversion, heat stress, crop rotation (23 tests).

---

## G. Remaining Risks

1. **Upstream Archive Delay Variations:** Open-Meteo ERA5-Land publication typically runs on a 5-day lag. If ECMWF upstream pipelines experience atypical delays, requests for days 5–7 may return incomplete data; this is safely trapped and returned as `InsufficientEvidenceFailure`.
2. **Physical Device Verification:** Verification was performed using the Flutter test suite and Android release APK build pipeline. No physical Android handset was connected.

---

## H. Final Recommendation

**READY FOR REVIEW**
