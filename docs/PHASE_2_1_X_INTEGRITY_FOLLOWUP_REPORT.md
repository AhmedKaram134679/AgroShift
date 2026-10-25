# AgroShift — Phase 2.1.x: Targeted Data Integrity Follow-up Report

**Date**: 2026-10-25  
**Workspace**: `D:\Programming projects\agro_shift\`  
**Verified Platform**: Flutter 3.47.2 (channel stable, revision d3b14c8769, 2026-08-26) / Dart 3.13.2 / DevTools 2.60.0 (Android 14 API 34 Target)  
**Baseline Documents**:  
- `docs/PHASE_2_PERSISTENCE_REPORT.md`  
- `docs/PHASE_2_1_INTEGRITY_AUDIT_REPORT.md`  

---

## Executive Summary

Phase 2.1.x addressed the specific data integrity, offline recovery, and provenance precision risks identified during the Phase 2.1 review. All investigations and modifications were kept strictly minimal and surgical, ensuring zero changes to agricultural formulas ($ET_c$, $GDD$, crop thresholds, rotations) while preserving Clean Architecture, Drift SQLite persistence, and Riverpod state management.

6 targeted regression tests were added across `test/data/persistence_tests.dart` and `test/data/open_meteo_adapter_tests.dart`, expanding the test suite to **50 automated tests** (0 failures).

---

## 1. Classification of Findings

| Category | Finding ID | Severity | Description | Status |
|---|---|---|---|---|
| **Confirmed & Fixed** | **F-2.1.x-1** | **Medium** | **Stale Provenance Tagging**: In `WeatherRepositoryImpl._markAsStale()`, staleness was indicated by mutating `datasetName` string. This confounded scientific dataset identity with data freshness and risked label concatenation. | **Fixed**: Added `isStaleFallback: true` to `DataSourceProvenance`, restored pure dataset identity, updated `ProvenanceCard` with dedicated badge. |
| **Confirmed & Fixed** | **F-2.1.x-2** | **Medium** | **Diagnostic Write Logging**: Database write exceptions in `saveRecords` were previously silently caught without diagnostic logging. | **Fixed**: Integrated standard `dart:developer` logging (`developer.log`) with technical stacktraces. |
| **Confirmed & Fixed** | **F-2.1.x-3** | **Medium** | **Calendar Date Parsing**: Upstream Open-Meteo `YYYY-MM-DD` strings in `OpenMeteoAdapter` were parsed with `DateTime.tryParse()`, which constructs local dates that could shift across midnight/DST boundaries. | **Fixed**: Enforced canonical `DateTime.utc(year, month, day)` calendar parsing. |
| **Confirmed & Fixed** | **F-2.1.x-4** | **Low** | **E2E Fallback Guard**: `getCachedRecords()` validated individual rows, but repository-level fallback needed an explicit end-to-end regression test proving that corrupt DB data ($T_{max} < T_{min}$) is never delivered to callers during network outages. | **Fixed**: Added test 16 verifying clean failure return with `NetworkFailure`. |
| **Investigated & Documented** | **I-2.1.x-1** | **Low** | **Coordinate Spatial Policy**: Coordinates are rounded to 3 decimal places (~111m) in cache keys. Distinct locations within 100m share cache keys. This matches the upstream grid resolution (~9 km for ERA5-Land, ~4.4 km for ECMWF/DWD). | **Documented & Tested**: Added test 15 documenting sub-millidegree grid equivalence. |
| **Investigated & Documented** | **I-2.1.x-2** | **Low** | **Missingness Denominator**: Verified that the denominator `count` in `OpenMeteoAdapter` reflects the total expected days in the requested interval, rather than the subset of valid records. | **Documented & Tested**: Added regression test in `open_meteo_adapter_tests.dart`. |
| **Unresolved Risk** | **R-2.1.x-1** | **Low** | **Physical Android Device Verification**: Real device execution remains unverified in this headless environment. | **Documented** |

---

## 2. Files Inspected and Modified

1. **`lib/domain/environment/models/data_source_provenance.dart`**:
   - Added `final bool isStaleFallback;` (defaults to `false`) to separate data freshness from scientific dataset identity.
2. **`lib/data/repositories/weather_repository_impl.dart`**:
   - `_markAsStale()`: Refactored to set `isStaleFallback: true`, preserve unmodified `datasetName`, and apply idempotent disclaimer notes.
   - Added `dart:developer` logging (`developer.log`) to all persistence write exception blocks.
3. **`lib/presentation/widgets/provenance_card.dart`**:
   - Added visual distinction: when `provenance.isStaleFallback == true`, renders an orange `cloud_off_outlined` icon, orange title ("بيانات مخزنة سابقة (أوفلاين)"), and annotates the dataset label without altering underlying provenance model fields.
4. **`lib/data/datasources/remote/open_meteo_adapter.dart`**:
   - Refactored date parsing in `toDomainRecords()` to strictly construct `DateTime.utc(year, month, day)` from `YYYY-MM-DD` strings, ensuring calendar days are impervious to local timezone shifts.
5. **`test/data/persistence_tests.dart`**:
   - Added Tests 15 through 19 covering coordinate collision boundaries, end-to-end repository rejection of corrupt cached records during network failure, calendar date preservation around DST, transaction rollback atomicity, and stale marking idempotency.
6. **`test/data/open_meteo_adapter_tests.dart`**:
   - Added test verifying that missing temperature days do not deflate the denominator when calculating missingness ratios for ET0 and precipitation.

---

## 3. Detailed Verification of Requirements

### A. Cache-Key Spatial Resolution & Isolation
- **Spatial Resolution Policy**:
  - The ERA5-Land reanalysis dataset operates on a ~9 km ($\sim 0.1^\circ$) grid.
  - The DWD/ECMWF numerical weather prediction models operate on a ~2.2 km to ~9 km grid.
  - AgroShift's cache key rounds coordinates to 3 decimal places:
    `coord.latitude.toStringAsFixed(3)` ($\approx 111 \text{ meters}$).
  - Farm fields located within 111 meters of each other evaluate to the identical grid cell from the upstream model. Preserving this 3-decimal key avoids caching thousands of identical 9 km weather cells for adjacent farm plots.
  - Added Test 15 demonstrating that sub-millidegree coordinates (e.g. `31.1001` and `31.1004`) map to the same grid cell key, while coordinates separated by $\ge 0.001^\circ$ (e.g. `31.100` vs `31.101`) are strictly isolated.

### B. End-to-End Fallback Guard Against Corrupt Records
- In `WeatherLocalDataSource.getCachedRecords()`, any row violating physical range limits ($T_{max} < T_{min}$, negative ET0, extreme temperatures) causes the entire cache retrieval to return `null`.
- In `WeatherRepositoryImpl.getForecastDailyRecords()`, when network failure occurs (`DioExceptionType.connectionError`), the repository checks the local data source. Since corrupt rows return `null`, the repository refuses to return the bad cache and instead surfaces a clean, controlled `NetworkFailure` ('لا تتوفر توقعات مخزنة سابقة بدون اتصال').
- Verified by Test 16 through the complete repository call stack.

### C. Date Semantics vs. Acquisition Timestamps
- Daily agro-meteorological records represent discrete calendar days (`recordDate`), not time instants.
- In `OpenMeteoAdapter`, `dateStr` (e.g. `"2026-06-01"`) is now parsed directly into `DateTime.utc(year, month, day)`.
- When persisted and retrieved from SQLite (`recordDate.toUtc()`), the hour is guaranteed to be `00:00:00.000Z`, preventing midnight shifts or date displacement during Cairo Daylight Saving Time transitions (e.g. April and October).
- `acquisitionTimestamp` remains an explicit instant in time (`DateTime.now().toUtc()`).
- Verified by Test 17 across DST transition dates.

### D. Missingness Denominator Verification
- Traced `OpenMeteoAdapter.toDomainRecords()`:
  - `count = times.length` represents the total expected daily records in the response interval.
  - Days where `rawTmax == null || rawTmin == null` increment `missingTempCount` and skip `DailyAgroRecord` creation.
  - The denominator for all three missingness ratios (`tempMissingRatio`, `et0MissingRatio`, `precipMissingRatio`) is always `count` (total expected days).
  - The denominator is **not** deflated by skipped days.
  - Verified by regression test in `open_meteo_adapter_tests.dart`.

### E. Stale Data Freshness vs. Dataset Identity
- Mutating `datasetName` (e.g. appending strings) risked confusing source identity with data freshness.
- Introduced `isStaleFallback` boolean flag in `DataSourceProvenance`.
- `_markAsStale()` now keeps `p.datasetName` identical to its upstream model label (`"ECMWF/DWD High-Resolution Forecast"` or `"ERA5-Land Reanalysis Archive"`), sets `isStaleFallback: true`, and applies disclaimer notes idempotently without string duplication.
- Verified by Test 19 and updated `ProvenanceCard` UI rendering.

### F. Database Write-Failure Behavior
- `WeatherLocalDataSource.saveRecords()` executes inside a Drift `_db.transaction()`. If any step fails, SQLite automatically rolls back the entire transaction, leaving previously valid cached records intact.
- In `WeatherRepositoryImpl`, write exceptions are caught, logged using `developer.log()`, and do not interrupt or fail the return of freshly fetched valid network records to the user.
- Verified by Tests 13 and 18.

---

## 4. Verification Command Outcomes

All four required verification commands were executed from the workspace root:

### 1. Code Formatting
```bash
$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.44 seconds.
Exit code: 0
```

### 2. Static Analysis
```bash
$ flutter analyze
Analyzing agro_shift...
No issues found! (ran in 5.3s)
Exit code: 0
```

### 3. Automated Test Suite Execution
```bash
$ flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart
00:02 +50: All tests passed!
Exit code: 0
```
- `open_meteo_adapter_tests.dart`: 7 tests passed (including denominator & distributed missingness).
- `domain_scientific_tests.dart`: 23 tests passed.
- `persistence_tests.dart`: 19 tests passed (including coordinate policy, e2e corrupt fallback rejection, DST calendar preservation, rollback atomicity, and stale idempotency).
- `widget_test.dart`: 1 smoke test passed.
- **Total**: 50 tests passed (0 failures).

### 4. Production Release Build
```bash
$ flutter build apk --release
Running Gradle task 'assembleRelease'...                           74.4s
√ Built build\app\outputs\flutter-apk\app-release.apk (58.5MB)
Exit code: 0
```

---

## 5. Agricultural Invariant Confirmation

- No formulas ($ET_c = K_c \times ET_0$, GDD cutoffs, crop heat stress thresholds, crop rotations, or volumetric water demand) were modified.
- Clean Architecture boundaries remain intact.

---

## 6. Remaining Limitations & Unresolved Risks

1. **Physical Device Testing**:
   - Automated tests and release APK compilation passed locally.
   - Physical touch verification on Android 14 hardware remains **unverified** in this environment.
2. **Upstream Publication Latency**:
   - As documented in Phase 2.1, ERA5-Land reanalysis data is subject to a 5–7 day publication latency by ECMWF/Copernicus. Real-time operations for the latest 5 days will encounter missing reanalysis records unless an operational real-time blended dataset is introduced in a future release.
