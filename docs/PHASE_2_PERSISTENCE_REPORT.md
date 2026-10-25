# AgroShift — Phase 2 Remediation Report: Durable Local Persistence & Offline Data Recovery

**Date:** 2026-10-25  
**Scope:** Phase 2 implementation of durable on-device persistence for user farm fields and cached daily weather records.  
**Workspace:** `D:\Programming projects\agro_shift\`  
**Governing Principles:** Clean Architecture, Domain Isolation, Drift SQLite Type-Safe Persistence, Dual-Tier Caching, Definite Missingness Preservation.

---

## 1. Persistence Design & Technology Rationale

### Technology Selected: **SQLite with `drift` (v2.35.3) & `sqlite3_flutter_libs`**
- **Type Safety & Compile-Time Verification:** Drift generates strongly typed table companions and queries, eliminating runtime SQL syntax bugs and dynamic string mismatches.
- **Relational Integrity:** Farm fields, deletion tombstones, and composite weather records naturally fit relational constraints (primary keys, foreign/unique constraints, composite primary keys over `(cacheKey, recordDate)`).
- **Domain Independence:** The domain layer (`FarmField`, `DailyAgroRecord`, `DataSourceProvenance`) remains 100% pure Dart, with zero dependency on Drift, SQLite, or database companions.
- **Standard Flutter Ecosystem:** Uses `path_provider` to locate the standard Android application documents directory (`agro_shift.sqlite`) and `NativeDatabase.memory()` for fast, deterministic unit testing.

---

## 2. Database Schema & Migration Strategy

The schema is defined in [lib/data/datasources/local/database/app_database.dart](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/database/app_database.dart):

### Tables Created:
1. **`FarmFieldsTable`**:
   - `id` (TEXT, PRIMARY KEY): Stable unique identifier (e.g. `field_1729800000000`).
   - `nameAr` (TEXT): Arabic name of the parcel.
   - `governorateAr` (TEXT): Egyptian governorate (e.g., كفر الشيخ).
   - `latitude` (REAL) & `longitude` (REAL): Coordinates bounded by Egypt's bounding box.
   - `areaInFeddan` (REAL): Parcel area in feddans.
   - `soilType` (TEXT): String enum mapping (`clay`, `clayLoam`, `sandyLoam`, `sandy`).
   - `activeCropId` (TEXT, nullable): Selected crop ID from `EgyptianCropsCatalog`.
   - `isDefault` (BOOLEAN, default `false`): Distinguishes benchmark demonstration fields from user-created fields.
   - `createdAt` (DATETIME) & `updatedAt` (DATETIME): Audit timestamps.

2. **`DeletedDefaultFieldIdsTable`**:
   - `id` (TEXT, PRIMARY KEY): ID of a built-in default field that the user explicitly removed.
   - `deletedAt` (DATETIME): Timestamp of deletion.
   - **Purpose:** Prevents deleted built-in fields from being resurrected on application restart or repository re-instantiation.

3. **`CachedDailyRecordsTable`**:
   - `cacheKey` (TEXT) & `recordDate` (DATETIME): **Composite Primary Key** `(cacheKey, recordDate)` preventing duplicate date entries per query window.
   - `maxTemperatureC` (REAL) & `minTemperatureC` (REAL): Measured daily temperatures.
   - `precipitationMm` (REAL, nullable): **Strictly preserves `null` as missing and `0.0` as measured zero.**
   - `referenceEt0Mm` (REAL, nullable): **Strictly preserves `null` as missing.**
   - `providerName`, `datasetName`, `requestedLatitude`, `requestedLongitude`, `gridLatitude`, `gridLongitude`, `gridElevationMeters`, `acquisitionTimestamp`, `scientificDisclaimerAr`: Preserves complete scientific provenance metadata.
   - `cachedAt` (DATETIME): Retrieval timestamp used to evaluate cache TTL.

### Schema Versioning & Migration:
- **Current Version:** `1`.
- Defined via Drift's `MigrationStrategy(onCreate: ..., onUpgrade: ...)`.
- Schema upgrade callbacks are structured to support additive migrations without table drops or data loss.

---

## 3. Cache Freshness & Offline Behavior

The freshness policy is encapsulated in [lib/data/datasources/local/cache_policy.dart](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/cache_policy.dart):

1. **Short-Term Forecasts (`isForecast: true`):**
   - **TTL = 6 Hours.** Numerical weather prediction models update multiple times daily; forecasts older than 6 hours are considered stale.
2. **Historical Reanalysis (`isForecast: false`):**
   - **TTL = 7 Days.** Reanalysis archive data (ERA5-Land) is finalized and static, but a 7-day TTL allows periodic synchronization of recent windows.
3. **Dual-Tier Cache Hierarchy (L1 In-Memory + L2 SQLite Disk):**
   - **Hot Path:** Hits L1 memory cache instantly (`< 1ms`).
   - **Cold Path / App Restart:** Reads L2 SQLite database.
   - **Online Fresh:** If cached data is fresh (`<= TTL`), returns immediately without network calls.
   - **Online Stale:** If cached data is expired, attempts live network fetch; on success, updates L1 and L2 cache.
   - **Offline Recovery:** If device is offline (network error or timeout) and cached data exists (even if stale), returns cached records to allow offline agronomic planning rather than failing with a blank screen.
   - **Offline Empty:** If no cached records exist for the coordinate/period, fails gracefully with a user-friendly Arabic notification: `"لا يوجد اتصال بالشبكة ولا تتوفر بيانات مخزنة دون اتصال لهذا الموقع."`

---

## 4. Files Created and Modified

### Created Files:
1. [`lib/domain/agronomy/repositories/i_farm_field_repository.dart`](file:///D:/Programming%20projects/agro_shift/lib/domain/agronomy/repositories/i_farm_field_repository.dart): Clean architecture domain interface for field persistence.
2. [`lib/data/datasources/local/database/app_database.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/database/app_database.dart): Drift database schema, tables, and migration logic.
3. [`lib/data/datasources/local/database/app_database.g.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/database/app_database.g.dart): Drift generated database code.
4. [`lib/data/datasources/local/database/connection.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/database/connection.dart): Platform SQLite connection factory using `path_provider` and in-memory test connection helper.
5. [`lib/data/datasources/local/cache_policy.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/cache_policy.dart): TTL definition and freshness evaluator.
6. [`lib/data/datasources/local/weather_local_data_source.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/datasources/local/weather_local_data_source.dart): Data access object for weather cache operations.
7. [`lib/data/repositories/farm_field_repository_impl.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/repositories/farm_field_repository_impl.dart): Concrete SQLite implementation of `IFarmFieldRepository`.
8. [`test/data/persistence_tests.dart`](file:///D:/Programming%20projects/agro_shift/test/data/persistence_tests.dart): Comprehensive test suite covering all 10 Phase 2 test requirements.

### Modified Files:
1. [`pubspec.yaml`](file:///D:/Programming%20projects/agro_shift/pubspec.yaml): Added runtime dependencies (`drift`, `sqlite3_flutter_libs`, `path_provider`, `path`) and dev dependencies (`drift_dev`, `build_runner`).
2. [`lib/data/repositories/weather_repository_impl.dart`](file:///D:/Programming%20projects/agro_shift/lib/data/repositories/weather_repository_impl.dart): Added SQLite cache lookup, cache persistence on network success, and offline recovery fallback.
3. [`lib/presentation/providers/agro_providers.dart`](file:///D:/Programming%20projects/agro_shift/lib/presentation/providers/agro_providers.dart): Initialized `appDatabaseProvider`, `farmFieldRepositoryProvider`, and persistent `FieldListNotifier` backing.
4. [`lib/presentation/screens/field_management_screen.dart`](file:///D:/Programming%20projects/agro_shift/lib/presentation/screens/field_management_screen.dart): Added delete field button with confirmation dialog and wired it to `FieldListNotifier.deleteField`.

---

## 5. Verification Commands & Test Results

All verification commands were executed directly on the local Windows environment:

| Step | Command Executed | Exit Code | Result |
|---|---|---|---|
| **1. Formatting** | `dart format --output=none --set-exit-if-changed .` | `0` | Formatted 42 files (0 changed in 0.31s). Zero format drift. |
| **2. Static Analysis** | `flutter analyze` | `0` | `No issues found! (ran in 4.6s)`. Zero lints, zero warnings. |
| **3. Test Suite** | `flutter test test/domain/domain_scientific_tests.dart test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/widget_test.dart` | `0` | **40 / 40 tests passed** (00:02). |
| **4. Android Release Build** | `flutter build apk --release` | `0` | Built `build\app\outputs\flutter-apk\app-release.apk` (**58.4 MB**, 114.1s). |

### Phase 2 Automated Tests Breakdown (10 of 10 Passing):
1. **Field Retrieval After Re-instantiation:** Saved field retrieved with identical properties via newly constructed repository instance over SQLite.
2. **Field Update & Deletion:** Updated parcel area/crop persists; deleted parcel is completely removed from SQLite.
3. **No Default Field Resurrection:** Explicitly deleting built-in default field `def_1` records a tombstone; subsequent re-seeding calls never recreate `def_1`.
4. **Weather Retrieval After Re-instantiation:** Cached daily records retrieved with complete series integrity via newly instantiated local data source.
5. **Zero vs Null Distinction:** Day 1 with `0.0 mm` precipitation persists and returns as `0.0`; Day 2 with `null` precipitation persists and returns as `null`.
6. **Provenance & Timestamp Survival:** Model name, provider, grid coordinates, and UTC acquisition timestamps survive storage without distortion.
7. **Cache Key Collision Prevention:** Distinct keys for Nile Delta, Nile Valley, and forecast queries store and retrieve independently without collision.
8. **Cache Policy Freshness & Staleness:** 6-hour forecast TTL and 7-day historical TTL correctly identify fresh vs stale records.
9. **Migration Record Preservation:** Upgrading database schema executes migration handler and preserves all existing farm fields.
10. **Graceful Offline Recovery:** When offline and no cache exists, repository returns a clear Arabic error; when cache exists, offline recovery serves cached data.

---

## 6. Known Limitations & Remaining Manual Testing

1. **Physical Device Permissions & Multi-Process Concurrency:**
   - On Android, SQLite files reside in private internal storage (`/data/data/com.example.agro_shift/app_flutter/`).
   - Manual testing on physical Android devices is recommended to verify app behavior across OS-level process kills, backup restores, and system language switching.
2. **Crop Parameters & Agronomic Logic Intact:**
   - In accordance with constraints, no formulas, crop thresholds, or rotation calculations were altered during this persistence phase.
3. **Dual-Source Calibration:**
   - Weather data provenance is transparently displayed in UI cards. Ground station validation remains an ongoing operational milestone.

> **Production Readiness Statement:**  
> With durable on-device SQLite persistence and offline recovery fully operational, AgroShift now preserves all user parcel data and historical agro-climatological series across restarts and disconnections.
