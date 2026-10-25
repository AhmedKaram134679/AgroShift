# AgroShift — Phase 2.1.x.6 Final Engineering Report
## Historical Model Compatibility, Scientific Claims Verification, and Data Integrity Hardening

### 1. Executive Summary
- **Overall Status:** `PASS — Ready for independent review`
- **Readiness:** Phase 2.1.x.6 is fully implemented, verified, hardened, and ready for independent engineering and agronomic review.
- **P0 / P1 / P2 Audit Items Resolved:**
  1. **P0 Model Compatibility:** Live API queries proved `models=era5_land` returned `null` for both $ET_0$ and precipitation on daily historical endpoints. `models=era5` was confirmed live to provide complete non-null data for all 4 required daily variables ($T_{\max}$, $T_{\min}$, $ET_0$, Precipitation) on an authentic ECMWF ERA5 grid cell (0.25° grid, ~25 km resolution).
  2. **P1 Period Completeness & Missing-Day Denominator:** Added `expectedPeriodDays` to `DataSourceProvenance` and passed it from both the adapter and SQLite cache lookup. In `environmental_analysis_screen.dart` and `dashboard_screen.dart`, completeness is calculated using `expectedPeriodDays` (the requested period length) rather than the count of surviving records. Days skipped due to missing temperature (up to 10%) are explicitly factored into the missing count and communicated in Arabic.
  3. **P1 Historical Date Window in `agro_providers.dart`:** Updated `fieldHistorical30DaysProvider` to implement Option A: querying `[latestEligible - 29 days, latestEligible]`, where `latestEligible = WeatherRepositoryImpl.getLatestEligibleHistoricalDate()`. This ensures an exact 30-day eligible historical sequence without getting truncated to 26 days by the 5-day publication delay.
  4. **P1 Removal of Stale ERA5-Land References:** Cleaned all remaining references in `weather_repository_impl.dart` (renamed `era5LandArchiveDelayDays` to `era5ArchiveDelayDays` with an alias for tests, updated Arabic error message), `environmental_analysis_screen.dart` (loading string), `scientific_provenance_screen.dart` (resolution and model name), and `cache_policy.dart`.
  5. **P1 Provenance Claims Alignment:** Updated documentation and UI architecture to clarify that each meteorological view presents a primary dataset provenance card (`ProvenanceCard`) reflecting the underlying dataset series (ERA5 Reanalysis Archive or Open-Meteo Best Match Forecast).
  6. **P2 ERA5 Spatial Resolution:** Updated `DATA_SOURCES_AND_VALIDATION.md` and UI strings to document ~25 km (0.25° grid), explicitly explaining the longitudinal convergence from ~27.8 km at the equator to ~24–26 km at Egyptian latitudes ($22^\circ\text{N}–31.8^\circ\text{N}$).
  7. **P2 Operational Quality Envelopes vs Physical Invariants:** Documented clear distinctions between operational data-quality screening envelopes ($[-5.0^\circ\text{C}, +55.0^\circ\text{C}]$, $ET_0 \le 25\text{ mm}$, $P \le 250\text{ mm}$) and inviolable physical domain laws ($T_{\max} \ge T_{\min}$, $P \ge 0$).
  8. **P2 NASA POWER Limitations:** Added documentation on multi-source sensor transitions (MERRA-2 assimilation updates, CERES vs earlier instruments) and temporal heterogeneity caveats for long-term trend analysis.

---

### 2. Files Changed
1. [open_meteo_remote_data_source.dart](file:///d:/Programming%20projects/agro_shift/lib/data/datasources/remote/open_meteo_remote_data_source.dart)
   - *Change:* Configured `'models': 'era5'` in `fetchHistoricalDaily()`.
   - *Rationale:* Verified via live API queries that `era5` reliably returns complete, non-null values for all 4 required daily variables.
2. [data_source_provenance.dart](file:///d:/Programming%20projects/agro_shift/lib/domain/environment/models/data_source_provenance.dart)
   - *Change:* Added optional `final int? expectedPeriodDays;` to `DataSourceProvenance`.
   - *Rationale:* Enables UI and downstream components to accurately determine the requested period denominator independently of filtered/surviving records.
3. [open_meteo_adapter.dart](file:///d:/Programming%20projects/agro_shift/lib/data/datasources/remote/open_meteo_adapter.dart)
   - *Change:* Passed `expectedPeriodDays: expectedCount ?? count` to `DataSourceProvenance`.
   - *Rationale:* Tracks the requested period length on every returned record.
4. [weather_local_data_source.dart](file:///d:/Programming%20projects/agro_shift/lib/data/datasources/local/weather_local_data_source.dart)
   - *Change:* Set `expectedPeriodDays: expectedDays` on `DataSourceProvenance` when restoring records from cache.
   - *Rationale:* Preserves requested period denominator across offline cache reads.
5. [weather_repository_impl.dart](file:///d:/Programming%20projects/agro_shift/lib/data/repositories/weather_repository_impl.dart)
   - *Change:* Renamed `era5LandArchiveDelayDays` to `era5ArchiveDelayDays` (with backward compatibility alias `era5LandArchiveDelayDays`), updated Arabic error message to reference ERA5, and forwarded `expectedPeriodDays` in `_markAsStale()`.
   - *Rationale:* Eliminates stale ERA5-Land references and preserves period denominator across stale fallback.
6. [agro_providers.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/providers/agro_providers.dart)
   - *Change:* Updated `fieldHistorical30DaysProvider` to query `[latestEligible - 29 days, latestEligible]`.
   - *Rationale:* Delivers exactly 30 eligible historical days accounting for the 5-day publication delay (Option A).
7. [environmental_analysis_screen.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/screens/environmental_analysis_screen.dart)
   - *Change:* Updated loading text from `ERA5-Land` to `ERA5`. Recomputed $ET_0$ completeness against `expectedPeriodDays` and added detailed Arabic warning distinguishing missing temperature days from missing $ET_0$ days.
   - *Rationale:* Prevents false 100% completeness claims when temperature-missing days are omitted from the record list.
8. [dashboard_screen.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/screens/dashboard_screen.dart)
   - *Change:* Evaluated forecast $ET_0$ completeness against `expectedForecastDays` and updated Arabic warning.
   - *Rationale:* Guarantees consistency between expected forecast days and available $ET_0$ readings.
9. [scientific_provenance_screen.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/screens/scientific_provenance_screen.dart)
   - *Change:* Updated line 93 to `(ERA5 بدقة ~25 كم / 0.25°)`.
   - *Rationale:* Eliminates stale ERA5-Land 11 km claims.
10. [cache_policy.dart](file:///d:/Programming%20projects/agro_shift/lib/data/datasources/local/cache_policy.dart)
    - *Change:* Updated comment from `ERA5-Land` to `ERA5`.
    - *Rationale:* Keeps documentation consistent with codebase.
11. [DATA_SOURCES_AND_VALIDATION.md](file:///d:/Programming%20projects/agro_shift/docs/DATA_SOURCES_AND_VALIDATION.md)
    - *Change:* Documented ~25 km resolution (with latitudinal cosine formula), primary dataset provenance display architecture, NASA POWER sensor transition caveats, and requested-period denominator semantics in Section 3.3.
    - *Rationale:* Establishes rigorous scientific documentation.
12. [open_meteo_adapter_tests.dart](file:///d:/Programming%20projects/agro_shift/test/data/open_meteo_adapter_tests.dart)
    - *Change:* Added assertions verifying that `expectedPeriodDays` equals 10 when 1 day has missing temperature and is skipped from the record list.
    - *Rationale:* Prevents regressions in requested period tracking.
13. [persistence_tests.dart](file:///d:/Programming%20projects/agro_shift/test/data/persistence_tests.dart)
    - *Change:* Added Test 59 (verifying Option A 30-day window across Cairo summer DST and month boundary) and Test 60 (verifying `era5ArchiveDelayDays` and `era5LandArchiveDelayDays` alias).
    - *Rationale:* Prevents regressions in historical date window and delay constants.

---

### 3. Historical Source Decision
- **Final Provider and Model Configuration:**
  - Endpoint: `https://archive-api.open-meteo.com/v1/archive`
  - Model Parameter: `models=era5`
  - Dataset Name: `ERA5 Reanalysis Archive`
  - Daily Variables: `temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, `precipitation_sum`
  - Timezone: `Africa/Cairo`
- **Live API Evidence:**
  - `models=era5_land` returns `null` arrays for `et0_fao_evapotranspiration` and `precipitation_sum`.
  - `models=era5` returns non-null valid numbers for all 4 variables ($T_{\max}$, $T_{\min}$, $ET_0$, Precipitation) on the 0.25° grid (~25 km resolution in Egypt).
  - Default (no models parameter) returns non-null data on Open-Meteo's blended reanalysis grid.
- **Decision:** Explicitly configured `models=era5` to guarantee global ECMWF ERA5 reanalysis consistency and complete 4-variable availability.

---

### 4. Data Integrity and Cache
- **Validation Changes:**
  - `OpenMeteoAdapter` strictly validates parallel array lengths, date formatting, chronological continuity, and 10% maximum missingness thresholds per variable.
  - `expectedPeriodDays` is embedded into `DataSourceProvenance` to decouple interval coverage from surviving record count.
- **Cache Isolation:**
  - Historical cache key: `'hist_openmeteo_era5_${coord.latitude}_${coord.longitude}_${startIso}_$endIso'`
  - Forecast cache key: `'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_$days'`
  - Full floating-point precision coordinates are retained without lossy rounding.
- **Corrupt Cache Overwrite Protection:**
  - Corrupt or incomplete network responses return typed failures before modifying memory or SQLite cache.

---

### 5. Scientific and Geographic Corrections
- **Spatial Resolution:** Documented as ~25 km (0.25° grid) reflecting longitudinal convergence at Egyptian latitudes ($22^\circ\text{N}–31.8^\circ\text{N}$).
- **Display Architecture:** Clarified that the UI renders a single primary dataset provenance card for the displayed series.
- **NASA POWER Limitations:** Documented sensor transitions (MERRA-2 assimilation, CERES vs earlier radiometers) for multi-decadal trends.
- **Physical vs Operational Screening:** Documented clear distinctions between operational outlier screening gates and physical invariants.

---

### 6. Tests Actually Executed

| Command | Executed | Result | Test Count | Details |
|---|---|---|---|---|
| `flutter test test/data/open_meteo_adapter_tests.dart` | Yes | PASS | 26 tests | Complete 4-variable array validation, sequence checks, missingness tolerance, null vs 0.0, and `expectedPeriodDays` tracking. |
| `flutter test test/data/persistence_tests.dart` | Yes | PASS | 60 tests | Cache isolation, `models=era5` outgoing query, stale fallback, 429 Retry-After, Cairo DST boundaries, 30-day Option A date window, delay alias. |
| `flutter test test/domain/domain_scientific_tests.dart` | Yes | PASS | 23 tests | Geographic coordinate validation, physical ranges, GDD, $ET_c$, heat stress, crop rotation. |
| `flutter test test/widget_test.dart` | Yes | PASS | 2 tests | App bootstrap navigation and distinct requested vs grid coordinate rendering in `ProvenanceCard`. |
| `flutter test test/data/open_meteo_adapter_tests.dart test/data/persistence_tests.dart test/domain/domain_scientific_tests.dart test/widget_test.dart` | Yes | PASS | 111 tests | Complete test suite passed synchronously with 0 failures. |

---

### 7. Static Analysis and Build

| Command | Executed | Result | Details |
|---|---|---|---|
| `dart format lib/ test/` | Yes | PASS | Formatted 42 files (clean formatting). |
| `flutter analyze` | Yes | PASS | **No issues found!** (0 errors, 0 warnings, 0 lints). |
| `flutter build apk --release` | Yes | PASS | Production release build verified. |

---

### 8. Live API Verification
- **Execution:** Live HTTP GET requests were executed against the official Open-Meteo endpoints using PowerShell.
- **Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
- **Location:** Kafr El-Sheikh field coordinates (`latitude=31.10`, `longitude=30.95`).
- **Date Range Tested:** `2024-06-01` to `2024-06-05`.
- **Findings:**
  - `models=era5_land`: `et0` and `precipitation` return arrays of `null`.
  - `models=era5`: Complete non-null data for all four variables ($T_{\max} \approx 34.0^\circ\text{C}$, $T_{\min} \approx 21.0^\circ\text{C}$, $ET_0 \approx 7.8\text{ mm/day}$, $P = 0.0\text{ mm/day}$).
  - Default (no model): Complete non-null data on Open-Meteo's blended reanalysis grid.

---

### 9. Remaining Risks
- **Low (Operational):** Upstream publication delay of 5 calendar days is properly handled by querying exactly 30 eligible historical days ($[D-34, D-5]$) via Option A.
- **Low (Geographic):** Coordinate validation utilizes an operational rectangular bounding envelope. All valid Egyptian agricultural land is properly supported without external GIS polygon dependencies.

---

### 10. Final Status
**PASS — Ready for independent review**
