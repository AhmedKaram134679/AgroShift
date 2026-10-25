# AgroShift — Phase 2.1.x.4: Historical Weather Integrity Audit and Implementation Report

**Author:** Senior Flutter/Dart Engineer  
**Date:** 2026-10-25  
**Workspace:** `d:\Programming projects\agro_shift`  
**Status:** Implemented, Formatted, Analyzed, Tested (93/93 Passed), Release APK Built (58.7 MB)

---

## 1. Executive Summary

This report documents the targeted correction of the historical weather data pipeline in AgroShift. The implementation enforces the official Open-Meteo ERA5-Land 5-day publication delay, introduces strict raw date sequence and parallel-array validation in `OpenMeteoAdapter`, establishes structural validation and shared-metadata consistency in SQLite persistence (`WeatherLocalDataSource`), and unifies L1 memory and L2 persistent cache TTL and stale-fallback policies in `WeatherRepositoryImpl`.

Clean Architecture, Riverpod providers, Drift/SQLite persistence, Cairo DST boundaries, Arabic user-facing messages, scientific thresholds, and null vs 0.0 distinctions are fully preserved.

---

## 2. Exact Files Changed

1. `lib/data/datasources/remote/open_meteo_adapter.dart`:
   - Enforced non-empty `time` array.
   - Enforced parallel-array length equivalence across `temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, and `precipitation_sum`.
   - Added strict calendar date validation matching `^\d{4}-\d{2}-\d{2}$` with calendar round-trip parsing to prevent invalid date shifting.
   - Added duplicate date rejection and strictly ascending chronological order verification.
   - Added daily continuity verification ($\Delta t = 1\text{ day}$) on raw API date sequences.
   - Added boundary checking against optional `expectedStartDate`, `expectedEndDate`, and `expectedCount`.
   - Preserved missing temperature filtering ($\le 10\%$) and zero vs null semantics.

2. `lib/data/datasources/local/weather_local_data_source.dart`:
   - Updated `getCachedRecords()` to accept `expectedStartDate`, `expectedEndDate`, and optional reference time `now`.
   - Added shared metadata consistency verification: validates that all rows in a cache key share the identical `cachedAt` timestamp.
   - Added canonical UTC calendar date normalization, duplicate detection, ascending chronological ordering, and interval boundary containment.

3. `lib/data/repositories/weather_repository_impl.dart`:
   - Implemented `_MemoryCacheEntry` struct wrapping cached records with `storedAt` timestamp and `isFresh()` method delegating to `CachePolicy`.
   - Defined `static const int era5LandArchiveDelayDays = 5;` based on official Open-Meteo documentation.
   - Added `getLatestEligibleHistoricalDate([DateTime? referenceTime])` using Cairo civil calendar date.
   - Clamped historical requested end dates to `latestEligibleDate`. If `startDate > effectiveEndDate`, returns typed `InsufficientEvidenceFailure`.
   - Added `isHistoricalValid()` structural validation for L1 and L2 cache evaluation.
   - Preserved independent forecast queries without applying archive delay.
   - Aligned L1 memory cache and L2 SQLite cache with 7-day historical and 6-hour forecast TTLs.
   - Restricted stale fallback to transient network errors (connection timeouts, 5xx, 429), strictly preventing non-transient HTTP 400/422 errors from consuming stale data.

4. `test/data/open_meteo_adapter_tests.dart`:
   - Added 7 unit tests (Tests 8 to 14) for raw date sequence validation.

5. `test/data/persistence_tests.dart`:
   - Added 17 regression tests (Tests 39 to 55) covering historical publication delay clamping, raw vs cached integrity, L1/L2 TTL expiration, and transient fallback rules.

6. `docs/DATA_SOURCES_AND_VALIDATION.md`:
   - Added Section 5 (ERA5-Land Publication Delay Policy), Section 6 (Raw Response vs Domain Sequence Validation), and Section 7 (Cache Freshness and Fallback Protocol).

---

## 3. Root Causes & Corrections

| Issue | Root Cause | Correction |
|---|---|---|
| Historical End-Date Overreach | Repository clamped end-dates only to `now`, ignoring ERA5-Land publication lag (~5 days). Requests for days within the delay period caused upstream failures or missing data. | Added `era5LandArchiveDelayDays = 5` and `getLatestEligibleHistoricalDate()`. Clamps end date and returns `InsufficientEvidenceFailure` if no eligible days exist in requested interval. |
| Raw API Sequence Integrity | `toDomainRecords()` directly filtered missing temperatures without first verifying raw array consistency or chronological order. | Added preliminary integrity check ensuring non-empty arrays, matching lengths, strict ISO regex, strict chronological order, duplicate rejection, and consecutive daily spacing. |
| Permitted Domain Gaps vs Raw Sequence | Missing-temperature filtering causes valid days to be omitted from domain lists. | Gaps are strictly rejected in raw API feeds, while permitted in final domain records provided missingness is $\le 10\%$. |
| Cached Data Inconsistency | `getCachedRecords()` queried by `recordDate` order without verifying that all rows belonged to the same cached transaction or fell within query interval. | Added shared `cachedAt` validation and interval boundary validation (`expectedStartDate`, `expectedEndDate`). |
| L1 vs Persistent Cache Freshness Divergence | L1 memory cache lacked timestamps and never expired, returning stale entries after SQLite cache expired. | Introduced `_MemoryCacheEntry` with `storedAt` and verified freshness against `CachePolicy.historicalTtl` (7d) and `forecastTtl` (6h). |

---

## 4. Verification Command Outputs

### 1. Code Formatting (`dart format`)
```bash
dart format lib/ test/
```
**Output:** Formatted 42 files (0 syntax or formatting issues). Exit code 0.

### 2. Static Analysis (`flutter analyze`)
```bash
flutter analyze
```
**Output:**
```
Analyzing agro_shift...
No issues found! (ran in 4.6s)
```
Exit code 0.

### 3. Complete Test Suite Execution
```bash
flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart
```
**Output:**
```
00:02 +93: All tests passed!
```
Exit code 0. (All 93 tests passing: 14 adapter tests, 55 persistence/cache tests, 23 domain scientific tests, 1 widget test).

### 4. Release APK Build
```bash
flutter build apk --release
```
**Output:**
```
Running Gradle task 'assembleRelease'...                           54.4s
√ Built build\app\outputs\flutter-apk\app-release.apk (58.7MB)
```
Exit code 0. Release binary size: **58.7 MB**.

---

## 5. Cairo DST & Timezone Confirmation

All existing Cairo Daylight Saving Time tests were strictly preserved and re-executed:
- Test 33: Cairo DST start transition (April) exact boundaries in UTC (UTC+2 to UTC+3 at 22:00:00Z).
- Test 34: Cairo DST end transition (October) exact boundaries in UTC (UTC+3 to UTC+2 at 21:00:00Z).
- Test 35: Cairo midnight rollover occurs exactly at 22:00 UTC in winter (UTC+2) and 21:00 UTC in summer (UTC+3).
- Test 36: Device local timezone does not alter Cairo calendar calculation.
- Test 43: Historical delay calculation behaves correctly across Cairo midnight and DST boundaries.

---

## 6. Remaining Limitations

1. **Upstream Publication Variations:** The 5-day publication delay is Open-Meteo's standard operational schedule for ERA5-Land reanalysis. On rare occasions of upstream ECMWF pipeline stalls, data may experience an additional delay. The application handles this safely via typed `InsufficientEvidenceFailure`.
2. **Physical Device Verification:** Tests were executed in the verified Flutter test harness and release APK build environments. No physical Android device was attached during this session.
