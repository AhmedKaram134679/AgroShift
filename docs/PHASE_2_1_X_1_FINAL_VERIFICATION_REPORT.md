# AgroShift — Phase 2.1.x.1: Final Cache Identity and Verification Review Report

**Date**: 2026-10-25  
**Workspace**: `D:\Programming projects\agro_shift\`  
**Verified Platform**: Flutter 3.47.2 (channel stable, revision d3b14c8769, 2026-08-26) / Dart 3.13.2 / DevTools 2.60.0 (Android 14 API 34 Target)  
**Baseline Documents**:  
- `docs/PHASE_2_PERSISTENCE_REPORT.md`  
- `docs/PHASE_2_1_INTEGRITY_AUDIT_REPORT.md`  
- `docs/PHASE_2_1_X_INTEGRITY_FOLLOWUP_REPORT.md`

---

## Executive Summary

Phase 2.1.x.1 executed a minimal, evidence-driven follow-up addressing cache identity precision, forecast rollover semantics, and network failure classification in AgroShift. Every change was verified against actual upstream Open-Meteo API behavior, local database persistence, and clean error handling without rewriting architectural layers, altering agricultural formulas, or adding dependencies.

All automated verification commands passed with zero errors, covering the full test suite of **52 unit, persistence, scientific, and widget tests** and producing a release APK.

---

## 1. Confirmed Findings and Evidence

### 1.1 Coordinate Cache-Key Correctness
- **Finding**: The Phase 2.1 implementation rounded requested coordinates to three decimal places (`toStringAsFixed(3)`), conflating locations within ~111 meters. The previous justification cited upstream model resolution (~9 km for ERA5-Land, ~2.2–4.4 km for ECMWF/DWD). However:
  1. Open-Meteo performs its own nearest-neighbor land/sea masking and grid-cell interpolation upstream based on the exact requested coordinates.
  2. Decimal rounding client-side does not correspond to an established canonical grid-cell assignment and risks silent data collision between distinct plots on grid boundaries.
  3. Upstream responses return both requested coordinates and resolved grid coordinates (`gridLatitude`, `gridLongitude`).
- **Correction Applied**:
  - Replaced lossy 3-decimal rounding with **exact, stable requested-coordinate identity** (`${coordinate.latitude}_${coordinate.longitude}`) in both historical and forecast cache keys:
    - Historical: `'hist_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${startIso}_$endIso'`
    - Forecast: `'fc_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${todayIso}_$days'`
  - Corrected previous report claims: client-side spatial coalescing without an upstream canonical mapping has been removed in favor of strict, deterministic request isolation.

### 1.2 Forecast Date Identity and Midnight Rollover
- **Finding**: Forecast records were previously cached under a key without calendar date identity (`'fc_${datasetTag}_${lat}_${lon}_$days'`) and protected solely by a 6-hour TTL. If a user cached a 7-day forecast at 23:00 and queried the forecast at 01:00 (within the 6-hour TTL), the repository would reuse the cached series where Day 1 represented yesterday, presenting past data as today's forecast.
- **Correction Applied**:
  - Incorporated current calendar date identity (`todayIso = DateFormat('yyyy-MM-dd').format(nowCairo)`) into the forecast cache key:
    `'fc_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${todayIso}_$days'`
  - Added explicit record-level validation `_isForecastValidForToday(records, nowCairo)` on both L1 in-memory cache and L2 SQLite cache lookups:
    `dart
    bool _isForecastValidForToday(List<DailyAgroRecord> records, DateTime now) {
      if (records.isEmpty) return false;
      final today = DateTime.utc(now.year, now.month, now.day);
      final firstRecordDate = DateTime.utc(
        records.first.date.year,
        records.first.date.month,
        records.first.date.day,
      );
      return !firstRecordDate.isBefore(today);
    }
    `
  - Preserved the existing 6-hour TTL (`Duration(hours: 6)`), which remains optimal for intraday weather updates while midnight date boundaries are strictly enforced.

### 1.3 Transient Network Failure Classification
- **Finding**: The stale-cache fallback path previously intercepted generic `DioException` errors without distinguishing transient connection faults from fatal client errors (such as HTTP 400 Bad Request or HTTP 422 Unprocessable Entity). Treating invalid queries or out-of-range dates as connectivity failures could mask programmer or parameter bugs under stale cache.
- **Correction Applied**:
  - Added dedicated policy method `_isTransientNetworkError(DioException dioErr)`:
    - **Transient (Eligible for stale fallback)**: `connectionTimeout`, `sendTimeout`, `receiveTimeout`, `connectionError`, `transformTimeout`, HTTP 5xx server errors, and `SocketException`.
    - **Non-Transient (Ineligible for stale fallback)**: HTTP 4xx client errors (400, 422), request cancellations, and bad certificates.
  - When a non-transient error occurs, the repository bypasses stale cache, extracts upstream error details (e.g., Open-Meteo `reason` payload), and returns a precise `NetworkFailure(statusCode: 400)`.

---

## 2. Exact Changes Made

### 2.1 `lib/data/repositories/weather_repository_impl.dart`
1. **Historical Cache Key**:
   - Updated from 3-decimal rounding to exact coordinate doubles:
     `'hist_____'`.
2. **Forecast Cache Key**:
   - Updated to incorporate exact coordinates and `todayIso`:
     `'fc_____'`.
3. **Date Validation**:
   - Implemented `_isForecastValidForToday()` to verify that cached forecast records start on or after the query calendar date.
4. **Transient Error Filter**:
   - Implemented `_isTransientNetworkError()` covering all `DioExceptionType` cases (including `transformTimeout`) and HTTP status code classification.
5. **Write Error Logging**:
   - Added `developer.log()` in `saveRecords` catch blocks for diagnostic traceability.

### 2.2 `test/data/persistence_tests.dart`
1. Updated Tests 14, 15, and 16 to validate exact coordinate identity and calendar date keys.
2. Added **Test 20**: Forecast midnight rollover regression test verifying that a forecast cached before midnight is not served on the next day.
3. Added **Test 21**: Non-transient 4xx error regression test verifying that HTTP 400 errors do not trigger stale fallback.

---

## 3. Regression Tests Added

| Test ID | Location | Purpose & Assertion | Result |
|---|---|---|---|
| **Test 14** | `test/data/persistence_tests.dart` | Validates that cache keys strictly isolate exact coordinates, date ranges, and datasets without lossy client-side rounding. | **Passed** |
| **Test 15** | `test/data/persistence_tests.dart` | Demonstrates that sub-millidegree coordinates (`31.1001` vs `31.1004`) produce distinct cache keys, preventing silent collision. | **Passed** |
| **Test 16** | `test/data/persistence_tests.dart` | Proves repository rejects physically corrupt cached records ({max} < T_{min}$) during network failure and returns `NetworkFailure`. | **Passed** |
| **Test 20** | `test/data/persistence_tests.dart` | **Midnight Rollover**: Forecast cached 2 hours ago with yesterday's calendar date is rejected when queried today; fails gracefully without presenting past dates as future forecasts. | **Passed** |
| **Test 21** | `test/data/persistence_tests.dart` | **Non-Transient 4xx Error**: Seeded stale cache is NOT returned when upstream responds with HTTP 400 Bad Request (`reason: 'Cannot specify time range outside available period'`); returns exact `NetworkFailure(statusCode: 400)`. | **Passed** |

---

## 4. Complete Verification Results

All verification commands were executed from the project root (`D:\Programming projects\agro_shift\`):

### 4.1 Formatting Check
`ash
dart format --output=none --set-exit-if-changed .
`
- **Exit Code**: `0`
- **Output**: `Formatted 42 files (0 changed) in 0.43 seconds.`

### 4.2 Static Analysis
`ash
flutter analyze
`
- **Exit Code**: `0`
- **Output**:
  `
  Analyzing agro_shift...
  No issues found! (ran in 5.3s)
  `

### 4.3 Automated Test Suite Execution
The complete test suite across all 4 test files was executed without exclusion:
`ash
flutter test (Get-ChildItem -Recurse -Filter *_test*.dart test | Select-Object -ExpandProperty FullName)
`
- **Exit Code**: `0`
- **Total Tests**: **52 tests** (0 failed, 0 skipped, 0 excluded)
- **Suite Breakdown**:
  - `test/widget_test.dart`: 1 test (App bootstrap and navigation smoke test)
  - `test/data/open_meteo_adapter_tests.dart`: 7 tests (DTO mapping, missingness thresholding, physical range integrity, denominator preservation)
  - `test/data/persistence_tests.dart`: 21 tests (Field CRUD, seeding protection, cache persistence, null vs zero preservation, provenance survival, migration, physical bounds validation, atomic rollbacks, sub-millidegree isolation, midnight rollover, 4xx non-transient handling)
  - `test/domain/domain_scientific_tests.dart`: 23 tests (Coordinates, Egyptian boundaries, scientific validator, GDD cutoffs, ETc volumetric conversion, heat stress, crop rotation enrichment/depletion)

### 4.4 Release APK Build
`ash
flutter build apk --release
`
- **Exit Code**: `0`
- **Build Duration**: `69.8s`
- **Artifact**: `build\app\outputs\flutter-apk\app-release.apk` (58.5 MB)
- **Status**: Production release bundle compiled cleanly with R8 tree-shaking and zero compilation errors.

---

## 5. Remaining Limitations

1. **Headless Execution Environment**:
   - Verification was executed in a Windows headless CLI environment. While SQLite binary bindings, Drift database migrations, and release APK compilation succeeded without errors, execution on physical Android 14 (API 34) hardware has not occurred.
2. **Upstream Rate Limits**:
   - Open-Meteo's non-commercial API tier enforces rate limits (10,000 daily calls, 600 hourly calls). While the stale-cache fallback handles transient 5xx or connection drops, prolonged 429 Too Many Requests errors will return non-transient network failures per policy.
3. **Network Time Inaccuracy**:
   - Forecast midnight rollover relies on device clock calendar dates. If a device has an inaccurate date/time setting, the calendar key may misalign until system time synchronization is restored.
