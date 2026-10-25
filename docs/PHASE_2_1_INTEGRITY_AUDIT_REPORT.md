# AgroShift — Phase 2.1: Persistence Integrity Audit and Targeted Remediation Report

**Date**: 2026-10-25  
**Workspace**: `D:\Programming projects\agro_shift\`  
**Verified Platform**: Flutter 3.47.2 (channel stable, revision d3b14c8769, 2026-08-26) / Dart 3.13.2 / DevTools 2.60.0 (Android 14 API 34 Target)  
*(Note: Initial draft stated Flutter 3.29.3 / Dart 3.7.2 carried over from prior documentation baseline; verified active CLI host environment confirmed Flutter 3.47.2 / Dart 3.13.2)*  
**Baseline Document**: `docs/PHASE_2_PERSISTENCE_REPORT.md`  

---

## Executive Summary

As part of **Phase 2.1**, an independent, code-level integrity audit of the local persistence architecture (SQLite via Drift), offline weather cache, and domain data pipelines was performed. Rather than relying on previous summary claims, all data paths were traced from remote Open-Meteo DTOs through domain entities, SQLite schema columns, Riverpod asynchronous providers, and the UI layer.

Defects and integrity gaps discovered during inspection were remedied with targeted, non-destructive modifications. 4 additional regression tests were added to the test suite (expanding test coverage to 44 automated tests across 4 test suites). All tests, formatting checks, static analysis, and release APK builds succeeded with 0 errors.

---

## 1. Files and Methods Inspected

1. **`lib/data/datasources/local/database/app_database.dart`**:
   - `FarmFieldsTable`, `DeletedDefaultFieldIdsTable`, and `CachedDailyRecordsTable`.
   - Primary key definitions: `{id}` for farm fields and `{cacheKey, recordDate}` for cached daily records.
   - Nullability constraints: `maxTemperatureC` and `minTemperatureC` (non-nullable), `precipitationMm` and `referenceEt0Mm` (nullable).
2. **`lib/data/datasources/local/database/connection.dart`**:
   - `openConnection()` leveraging `NativeDatabase.createInBackground` with `LazyDatabase`.
   - `constructTestDb()` providing in-memory SQLite isolation for unit/integration testing.
3. **`lib/data/datasources/local/cache_policy.dart`**:
   - `isFresh()` method applying 6-hour TTL for forecast records and 7-day TTL for historical reanalysis series.
4. **`lib/data/datasources/local/weather_local_data_source.dart`**:
   - `getCachedRecords()`: row-to-domain mapping, timezone consistency, and physical range validation.
   - `saveRecords()`: atomic transactional replacement and custom `cachedAt` support.
5. **`lib/data/repositories/weather_repository_impl.dart`**:
   - `getHistoricalDailyRecords()` & `getForecastDailyRecords()`: cache-key generation, memory L1 caching, durable SQLite L2 caching, stale provenance tagging, and non-fatal DB write error handling.
6. **`lib/data/repositories/farm_field_repository_impl.dart`**:
   - `getAllFields()`, `saveField()`, `deleteField()`, and `seedDefaultFieldsIfNecessary()` with deletion tombstoning via `DeletedDefaultFieldIdsTable`.
7. **`lib/data/datasources/remote/open_meteo_adapter.dart`**:
   - `toDomainRecords()`: enforces temperature non-nullability invariant, distinct 0.0 vs null preservation for precipitation and ET0, and missingness tolerance rules (<= 10%).
8. **`lib/data/models/open_meteo_dto.dart`**:
   - `OpenMeteoDailyResponseDto.fromJson()`: JSON casting resilience.
9. **`lib/presentation/providers/agro_providers.dart`**:
   - `appDatabaseProvider` with automatic disposal, `FieldListNotifier`, `SelectedFieldNotifier`, and async weather providers.
10. **`lib/presentation/widgets/provenance_card.dart` & `dashboard_screen.dart`**:
    - Scientific provenance rendering and offline stale data identification.

---

## 2. Integrity Audit Findings & Severity Classification

| Finding ID | Domain Area | Severity | Description & Root Cause | Status |
|---|---|---|---|---|
| **F-01** | Missing Data Validation | **High** | In `weather_local_data_source.dart`, cached rows were deserialized into `DailyAgroRecord` without re-running physical range validation. If on-disk SQLite data was modified or corrupted, impossible records ($T_{max} < T_{min}$ or out-of-bounds ET0) could be consumed by downstream agronomic engines. | **Remedied** |
| **F-02** | Cache-Key Isolation | **Medium** | Cache keys previously used `'hist_${lat}_${lon}_${start}_${end}'` and `'fc_${lat}_${lon}_${days}'`. While coordinates and dates were separated, the key did not incorporate provider/dataset model names (`openmeteo_era5land` vs `openmeteo_ecmwf_dwd`), creating theoretical collision risk if alternative models or providers are cached. | **Remedied** |
| **F-03** | Stale Fallback Visibility | **Medium** | When offline fallback was activated in `WeatherRepositoryImpl`, cached records were returned without indicating to callers or UI components that the returned series was stale offline data rather than fresh upstream data. | **Remedied** |
| **F-04** | Database Write Resilience | **Medium** | In `WeatherRepositoryImpl`, `saveRecords` was called without a localized try/catch block. A database write error (e.g. disk full, locked DB) could throw an unhandled exception, discarding freshly fetched and validated network records. | **Remedied** |
| **F-05** | Upstream Publication Latency | **Low / Doc** | Open-Meteo's ERA5-Land reanalysis archive has an inherent publication latency of 5–7 days from ECMWF. If the user requests data up to `DateTime.now()`, the last 5 days contain null values. `OpenMeteoAdapter` correctly flags this if missing values exceed 10%. | **Documented & Managed** |
| **F-06** | JSON Serialization Type Safety | **Low** | In `open_meteo_dto.dart`, `json['daily_units'] as Map<String, dynamic>?` threw a runtime cast exception when given generic `_Map<dynamic, dynamic>` payloads in non-standard environments. | **Remedied** |

---

## 3. Targeted Remediation Implemented

### A. Missing Values and Physical Invariants
- **Non-nullability of $T_{max}$ and $T_{min}$**:
  Verified in both `DailyAgroRecord` and `CachedDailyRecordsTable` (`real()()`). Upstream Open-Meteo data missing temperature is strictly tracked in `OpenMeteoAdapter`. If daily temperature is absent, the day cannot form an agro-climatic record. If missing days exceed 10%, `InsufficientEvidenceFailure` is explicitly returned.
- **Null vs 0.0 Distinction**:
  `precipitationMm` and `referenceEt0Mm` are nullable `RealColumn`s. Affirmative zero rainfall (`0.0 mm`) is preserved distinctly from unrecorded/missing days (`null`).
- **Post-Cache Range Validation**:
  `WeatherLocalDataSource.getCachedRecords` now validates all read rows through `ScientificRangeValidator.validateTemperature`, `validateEt0`, and `validatePrecipitation`. If any row contains corrupted or physically impossible data ($T_{max} < T_{min}$, negative ET0, extreme temperatures), the cache lookup returns `null`, forcing an authoritative re-fetch.

### B. Cache-Key Isolation
Cache keys now incorporate provider and dataset tags:
- Historical: `'hist_openmeteo_era5land_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}_${startIso}_$endIso'`
- Forecast: `'fc_openmeteo_ecmwf_dwd_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}_$days'`
This guarantees total isolation across coordinates (millidegree precision), date ranges, query types, and forecast vs historical datasets.

### C. Date and Timestamp Consistency
- Daily record dates are stored as UTC dates (`row.recordDate.toUtc()`).
- Retrieval timestamps preserve UTC acquisition time (`row.acquisitionTimestamp.toUtc()`).
- Prevents timezone shifts across Cairo standard/daylight time and avoids duplicate or shifted date records.

### D. Offline Fallback & Stale Data Transparency
In `WeatherRepositoryImpl`, when network requests fail (`DioException` or `SocketException`) and a cached dataset is available (even if beyond TTL):
1. Records are retrieved from SQLite.
2. The records are transformed via `_markAsStale()`:
   - `datasetName` is annotated with `[نسخة مخزنة دون اتصال - أوفلاين]`.
   - `scientificDisclaimerAr` is annotated with `(ملاحظة: البيانات معروضة من الذاكرة المؤقتة لعدم توفر اتصال بالشبكة)`.
3. Callers and `ProvenanceCard` display this transparently to the agricultural operator.

### E. Database Write Fault Tolerance
Calls to `_localDataSource.saveRecords()` are wrapped in defensive `try/catch` blocks. If disk writing fails, the repository still delivers the validated network data to the caller rather than failing the entire operation.

### F. Default Farm Fields & Tombstone Permanence
`FarmFieldRepositoryImpl` tracks deleted default fields in `DeletedDefaultFieldIdsTable`. When the app starts and seeds default Egyptian benchmark fields, any field whose ID is in the tombstone table is skipped. Custom user edits to benchmark fields are never overwritten.

---

## 4. Verification and Regression Testing

### Regression Tests Added (`test/data/persistence_tests.dart`)
1. **Test 11**: Stale offline cache is returned with explicit stale provenance marking when network fails.
2. **Test 12**: Corrupted records violating physical ranges in SQLite ($T_{max} < T_{min}$) are rejected during cache retrieval.
3. **Test 13**: Failed database writes do not crash repository or discard fetched records.
4. **Test 14**: Cache keys strictly isolate coordinates, dates, and datasets.

### Verification Command Outcomes

#### 1. Formatting
```bash
$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.50 seconds.
Exit code: 0
```

#### 2. Static Analysis
```bash
$ flutter analyze
Analyzing agro_shift...
No issues found! (ran in 5.1s)
Exit code: 0
```

#### 3. Test Suite Execution
```bash
$ flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart
00:02 +44: All tests passed!
Exit code: 0
```
- `open_meteo_adapter_tests.dart`: 6 tests passed.
- `domain_scientific_tests.dart`: 23 tests passed.
- `persistence_tests.dart`: 14 tests passed.
- `widget_test.dart`: 1 smoke test passed.
- **Total**: 44 tests passed (0 failures).

#### 4. Release Production Build
```bash
$ flutter build apk --release
Running Gradle task 'assembleRelease'...                           80.1s
√ Built build\app\outputs\flutter-apk\app-release.apk (58.5MB)
Exit code: 0
```

---

## 5. Agricultural Invariant Confirmation

- **Formulas Preserved**: No modifications were made to $ET_c = K_c \times ET_0$, GDD calculation formulas, high-temperature cutoff logic ($T_{cutoff}$), crop heat stress thresholds, or soil nitrogen replenishment rules.
- **Clean Architecture Preserved**: Separation between Domain entities, Data layer SQLite/Drift tables, and Presentation Riverpod state management was maintained with zero leaks.

---

## 6. Remaining Limitations & Physical Device Verification

1. **Physical Device Testing**:
   - Automated tests and release APK packaging were verified on the local host build environment.
   - Live installation and touch verification on a physical Android 14 device remains **unverified** in this headless environment.
2. **ERA5-Land Publication Latency**:
   - Because ERA5-Land has ~5-day publication latency, historical queries requesting data up to current day will encounter missing values for the latest 5 days. For operational real-time monitoring of the most recent 5 days, a transition to blended forecast/analysis datasets is recommended in a future enhancement phase with explicit provenance transition labeling.
