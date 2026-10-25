# AgroShift — Phase 2.1.x.3 Final Audit Report: Forecast Cache and Retry-After

## Executive Summary

Phase 2.1.x.3 performed a narrow, code-level verification and audit of the forecast caching subsystem, Africa/Cairo calendar-day rollover rules, HTTP 429 rate-limiting semantics, RFC 7231 `Retry-After` header parsing, and stale-fallback guarantees.

All Clean Architecture boundaries, Drift/SQLite persistence models, Riverpod state management, domain contracts, and agricultural science calculations (FAO-56 Penman-Monteith $ET_0$, crop evapotranspiration $ET_c = K_c \times ET_0$, GDD cutoffs, and soil depletion matrices) were strictly preserved without introducing external dependencies.

---

## 1. Findings Confirmed from Source Inspection

Inspection of `lib/data/repositories/weather_repository_impl.dart`, `test/data/persistence_tests.dart`, and related adapters identified the following specific discrepancies prior to remediation:

1. **Forecast Start Date Validation Laxity**:
   - `isForecastValidForToday()` checked `if (i == 0 && recDate.isBefore(today)) return false;`. While this prevented records from the past, it permitted a forecast starting tomorrow or subsequent days to pass as valid for today.
   - The upstream Open-Meteo contract (`/v1/forecast?timezone=Africa/Cairo&forecast_days=N`) always provides today's Cairo calendar date as the first record. A valid forecast for today must strictly start on today's calendar date (`recDate == today`).

2. **Interval Count (`expectedDays`) Call-Site Omission**:
   - Although `isForecastValidForToday()` supported an optional `expectedDays` parameter, all 4 lookup sites in `getForecastDailyRecords` (L1 memory cache, L2 fresh SQLite cache, L2 stale fallback, and L1 stale fallback) omitted `expectedDays: days`.
   - Consequently, truncated forecast sequences (e.g., 2 or 3 records when 7 days were requested) could be returned as valid forecasts.

3. **Calendar Day Normalization vs. Device Local Clock**:
   - `nowCairo` was instantiated via `DateTime.now()` (device local time), rather than calculating the exact calendar date for `Africa/Cairo` (`UTC+2` Standard Time / `UTC+3` Daylight Saving Time). On devices operating in disparate timezones (e.g., UTC or US timezones), the cached forecast date could drift relative to Egyptian local time.

4. **Blind `Retry-After` String Formatting**:
   - The repository inspected `dioErr.response?.headers.value('retry-after')` and unconditionally formatted it as `' (Retry-After: ${retryAfter}s)'`.
   - When upstream APIs return an RFC 7231 HTTP-date (e.g. `Wed, 21 Oct 2026 07:28:00 GMT`), the diagnostic string resulted in an invalid expression: `(Retry-After: Wed, 21 Oct 2026 07:28:00 GMTs)`.

5. **HTTP 429 Stale Fallback Isolation**:
   - Confirmed that HTTP 429 correctly routes through `_isTransientNetworkError()`, allowing stale cache fallback only if cached data exists and satisfies all structural, chronological, and scientific validity checks. Corrupted or invalid cache data is never returned.

---

## 2. Exact Files Changed and Reasons

### 1. `lib/data/repositories/weather_repository_impl.dart`
- **Cairo Calendar Helper (`getCairoDateTime`)**:
  - Implemented dynamic UTC offset calculation for Egypt standard time (`UTC+2`) and Daylight Saving Time (`UTC+3`, running from the last Friday of April 00:00 to the last Thursday of October 24:00).
- **RFC 7231 `Retry-After` Parser (`parseRetryAfterNote`)**:
  - Added support for non-negative integer seconds (`"120"` $\rightarrow$ `(Retry-After: 120s)`).
  - Added support for IMF-fixdate HTTP-dates via `HttpDate.parse()` (`"Sun, 25 Oct 2026 11:00:00 GMT"` $\rightarrow$ calculates remaining seconds and displays formatted delay without trailing `'s'`).
  - Gracefully handles negative durations, malformed strings, and empty headers without throwing or corrupting messages.
- **Strict Start Date and Contiguous Interval Enforcement (`isForecastValidForToday`)**:
  - Enforced `recDate.isAtSameMomentAs(today)` on index 0 to ensure the sequence starts on today's calendar date.
  - Enforced continuity (`difference.inDays == 1`), strictly monotonic order (`recDate.isAfter(prevDate)`), and `records.length >= expectedDays`.
- **Consistent Call-Site Integration**:
  - Supplied `nowCairo = getCairoDateTime()` and passed `expectedDays: days` at all 4 cache check sites in `getForecastDailyRecords`.

### 2. `test/data/persistence_tests.dart`
- **Updated Test 11**:
  - Seeded complete 7-day forecast series matching `expectedDays: 7`.
- **Added Tests 25–32**:
  - **Test 25**: Rejection of sequence starting one day too late (tomorrow).
  - **Test 26**: Rejection of sequence ending one day too early (6 days when 7 expected).
  - **Test 27**: Rejection of duplicate dates within forecast sequence.
  - **Test 28**: Verification of Africa/Cairo standard time (`UTC+2`), DST (`UTC+3`), and UTC midnight rollover.
  - **Test 29**: Validation of UTC-represented forecast dates matching Cairo calendar day.
  - **Test 30**: Comprehensive parsing tests for `Retry-After` (integer seconds, HTTP-date, past dates, malformed strings, null/empty).
  - **Test 31**: HTTP 429 with HTTP-date header formatting and fallback to valid stale cache.
  - **Test 32**: HTTP 429 with no usable cached data returning clean `NetworkFailure` with accurate diagnostics.

---

## 3. Forecast Interval Policy & Cairo/UTC Date Handling

1. **Canonical Calendar Date Definition**:
   - Open-Meteo `/v1/forecast` is requested with `timezone=Africa/Cairo`.
   - The returned date strings (`YYYY-MM-DD`) are parsed in `OpenMeteoAdapter` as UTC midnights (`DateTime.utc(year, month, day)`).
   - In `WeatherRepositoryImpl`, the current Cairo calendar date is computed from UTC reference using Egypt's official transition rules (`UTC+2` winter, `UTC+3` summer) and normalized to UTC midnight (`DateTime.utc(now.year, now.month, now.day)`).
2. **Interval Contract**:
   - Record 0 date **must equal** `today` (exact start date match).
   - Record $i$ date **must equal** Record $i-1$ date $+ 1\text{ day}$.
   - Sequence must contain no duplicates, reversals, or gaps.
   - Record count **must be $\ge$ `expectedDays`**.

---

## 4. HTTP Error Classification & Retry-After Behavior

| Status Code / Error | Classification | Stale Fallback Permitted? | Diagnostic Message |
|:---|:---|:---:|:---|
| **HTTP 429** | Transient | **Yes** (if valid cached data exists) | Preserves upstream reason + parsed `Retry-After` |
| **HTTP 5xx** | Transient | **Yes** (if valid cached data exists) | Server error message |
| **Connection / Timeout** | Transient | **Yes** (if valid cached data exists) | Network failure message |
| **HTTP 400, 401, 403, 422** | Non-Transient | **No** (strictly prohibited) | Fatal client error; cached data not masked |
| **Invalid Cache on 429/5xx** | Terminal Failure | **No** | Returns `NetworkFailure` with HTTP status code and diagnostics |

### `Retry-After` Parsing Matrix
- Non-negative integer (e.g. `120`) $\rightarrow$ `' (Retry-After: 120s)'`
- HTTP-date in future $\rightarrow$ `' (Retry-After: <delta>s, until <http-date>)'`
- HTTP-date in past $\rightarrow$ `' (Retry-After: 0s, until <http-date>)'`
- Malformed string (e.g. `foo_bar`) $\rightarrow$ `' (Retry-After: foo_bar)'` (no invalid `'s'` suffix appended)
- Missing / empty header $\rightarrow$ `''` (clean omission)

---

## 5. Cache Rollover and Stale-Fallback Policy

- **Cache Key Identity**:
  - `fc_${datasetTag}_${lat}_${lon}_${todayIso}_$days`
- **Midnight Rollover**:
  - When the Cairo calendar date rolls over past midnight, `todayIso` updates.
  - The previous day's forecast cache key cannot be accessed as today's cache entry.
  - Previous day forecasts cannot masquerade as today's requested sequence, ensuring strict temporal isolation.
- **Stale Fallback Freshness & Metadata**:
  - When a valid matching cached forecast is returned during network outage or HTTP 429:
    - Provenance sets `isStaleFallback: true`.
    - Pure scientific dataset identity (`datasetName`) is preserved.
    - `null` and `0.0` values remain distinct (preserving exact precipitation and ET0 semantics).

---

## 6. Verification Commands & Actual Terminal Outputs

All commands were executed in the project root (`d:\Programming projects\agro_shift`).

### 1. Code Formatting
```powershell
dart format --output=none --set-exit-if-changed .
```
**Output**:
```
Formatted 42 files (0 changed) in 0.46 seconds.
Exit Code: 0
```

### 2. Static Analysis
```powershell
flutter analyze
```
**Output**:
```
Analyzing agro_shift...                                         
No issues found! (ran in 5.0s)
Exit Code: 0
```

### 3. Complete Test Suite
```powershell
flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart --reporter=expanded
```
**Output**:
```
00:00 +0: loading D:/Programming projects/agro_shift/test/data/open_meteo_adapter_tests.dart
...
00:02 +63: All tests passed!
Exit Code: 0
```
- **Discovered & Executed Tests**: 63
- **Failures**: 0
- **Skips**: 0
- **Exclusions**: 0

### 4. Release Compilation
```powershell
flutter build apk --release
```
**Output**:
```
Running Gradle task 'assembleRelease'...                        
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 6580 bytes (99.6% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Running Gradle task 'assembleRelease'...                           97.6s
√ Built build\app\outputs\flutter-apk\app-release.apk (58.6MB)
Exit Code: 0
```
- **Artifact Verified**: `build\app\outputs\flutter-apk\app-release.apk` (58.6MB). Confirmed an APK file, **not** an Android App Bundle (.aab).

---

## 7. Verified Environment

- **Flutter**: `3.47.2` (channel `stable`, revision `d3b14c8769`)
- **Dart**: `3.13.2`
- **DevTools**: `2.60.0`
- **Target Platform**: Android APK (Release mode)

---

## 8. Remaining Limitations

1. **Physical-Device Verification**:
   - Verification was executed against desktop and headless Android build tooling using native SQLite (`sqlite3.dll` on Windows memory/file executors) and release APK compilation via Gradle.
   - Physical Android device installation and over-the-air field testing were **not** performed in this automated audit cycle.
