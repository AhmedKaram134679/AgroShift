# AgroShift — Phase 2.1.x.6 Final Engineering Report
## Historical Model Compatibility, Scientific Claims Verification, and Data Integrity Hardening

### 1. Executive Summary
- **Overall Status:** `PASS — Ready for independent review`
- **Readiness:** Phase 2.1.x.6 is fully implemented, verified, and ready for independent engineering and agronomic review.
- **P0 / P1 Blockers:** None remaining. The critical P0 historical model-variable incompatibility has been resolved through live API verification and code configuration updates.

---

### 2. Files Changed
1. [open_meteo_remote_data_source.dart](file:///d:/Programming%20projects/agro_shift/lib/data/datasources/remote/open_meteo_remote_data_source.dart)
   - *Change:* Replaced `'models': 'era5_land'` with `'models': 'era5'` in `fetchHistoricalDaily()`. Updated class documentation.
   - *Rationale:* Verified via live API queries that Open-Meteo's `era5_land` parameter on daily historical queries returns `null` for both `et0_fao_evapotranspiration` and `precipitation_sum`. Requesting `models=era5` guarantees valid, non-null data for all four required agricultural variables ($T_{\max}$, $T_{\min}$, $ET_0$, Precipitation).
2. [weather_repository_impl.dart](file:///d:/Programming%20projects/agro_shift/lib/data/repositories/weather_repository_impl.dart)
   - *Change:* Updated historical cache tag to `openmeteo_era5` (cache key format `hist_openmeteo_era5_${lat}_${lon}_${start}_$end`) and dataset label to `'ERA5 Reanalysis Archive'`. Updated forecast cache tag to `openmeteo_bestmatch` (cache key format `fc_openmeteo_bestmatch_${lat}_${lon}_${today}_$days`) and dataset label to `'Open-Meteo Best Match Forecast'`.
   - *Rationale:* Eliminates stale dataset identity reuse, guarantees cache isolation between distinct model configurations, and honestly reflects that the forecast uses Open-Meteo's Best Match blend.
3. [coordinate.dart](file:///d:/Programming%20projects/agro_shift/lib/domain/environment/models/coordinate.dart) & [agro_constants.dart](file:///d:/Programming%20projects/agro_shift/lib/core/constants/agro_constants.dart)
   - *Change:* Documented that the $[22.0, 31.8]^\circ\text{N} \times [25.0, 37.0]^\circ\text{E}$ bounding envelope is an approximate operational screening bounding box for Egypt, not a legal or political border polygon. Updated error message to use accurate Arabic phrasing (`النطاق الجغرافي المعتمد ... (نطاق تقريبي)`).
   - *Rationale:* Prevents false scientific claims of political boundary validation.
4. [provenance_card.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/widgets/provenance_card.dart)
   - *Change:* Rendered requested field coordinates (`الإحداثيات المطلوبة للحقل`) separately from resolved atmospheric model grid coordinates (`إحداثيات خلية الشبكة (Grid)`).
   - *Rationale:* Resolves provenance conflation between user farm locations and gridded atmospheric cells.
5. [environmental_analysis_screen.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/screens/environmental_analysis_screen.dart) & [dashboard_screen.dart](file:///d:/Programming%20projects/agro_shift/lib/presentation/screens/dashboard_screen.dart)
   - *Change:* Implemented transparent completeness tracking for $ET_0$ and $ET_c$ period sums. If any days lack $ET_0$ measurements, the UI labels the metric as a partial sum (`مجموع جزئي ($availableDays من أصل $totalDays يوماً)`) and shows an Arabic warning.
   - *Rationale:* Prevents partial sums from being silently passed off as complete seasonal or 7-day period totals.
6. [DATA_SOURCES_AND_VALIDATION.md](file:///d:/Programming%20projects/agro_shift/docs/DATA_SOURCES_AND_VALIDATION.md)
   - *Change:* Synchronized documentation to reflect `models=era5`, Open-Meteo Best Match forecast, operational data-quality thresholds vs physical laws, transparent completeness reporting, and coordinate separation.
   - *Rationale:* Keeps primary scientific documentation consistent with the actual codebase.
7. [open_meteo_adapter_tests.dart](file:///d:/Programming%20projects/agro_shift/test/data/open_meteo_adapter_tests.dart)
   - *Change:* Added regression tests for missing `temperature_2m_max` and `temperature_2m_min` arrays alongside existing $ET_0$ and precipitation missing array tests.
   - *Rationale:* Enforces complete 4-variable array coverage in the adapter.
8. [persistence_tests.dart](file:///d:/Programming%20projects/agro_shift/test/data/persistence_tests.dart)
   - *Change:* Updated all cache keys to `hist_openmeteo_era5_...` and `fc_openmeteo_bestmatch_...`. Updated Test 56 to assert `models == 'era5'`.
   - *Rationale:* Verifies cache identity and request parameter consistency.
9. [widget_test.dart](file:///d:/Programming%20projects/agro_shift/test/widget_test.dart)
   - *Change:* Added widget tests verifying distinct rendering of requested vs grid coordinates in `ProvenanceCard`.
   - *Rationale:* Ensures UI provenance traceability.

---

### 3. Historical Source Decision
- **Final Provider and Model Configuration:**
  - Endpoint: `https://archive-api.open-meteo.com/v1/archive`
  - Model Parameter: `models=era5`
  - Dataset Name: `ERA5 Reanalysis Archive`
  - Daily Variables: `temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, `precipitation_sum`
  - Timezone: `Africa/Cairo`
- **Evidence Supporting Variable Compatibility:**
  - Live API testing of `models=era5_land` against the official endpoint for a valid Egypt location (`31.10°N, 30.95°E`) returned null arrays for `et0_fao_evapotranspiration` (`[null, null, ...]`) and `precipitation_sum` (`[null, null, ...]`).
  - Live API testing of `models=era5` against the same endpoint and coordinates returned complete, non-null numerical data for all 4 variables:
    - $T_{\max}$: `[34.1, 33.7, 34.0, ...]` °C
    - $T_{\min}$: `[21.2, 21.0, 21.5, ...]` °C
    - $ET_{0,\text{FAO}}$: `[7.89, 7.82, 7.75, ...]` mm/day
    - Precipitation: `[0.0, 0.0, 0.0, ...]` mm/day
- **Remaining Source Limitations:**
  - Spatial resolution is ~28 km (0.25°), which smooths localized microclimatic terrain differences compared to station sensors.
  - Upstream publication delay of 5 calendar days is enforced via `WeatherRepositoryImpl.getCairoDateTime()`.

---

### 4. Data Integrity and Cache
- **Validation Changes:**
  - `OpenMeteoAdapter` strictly rejects responses missing any of the 4 required arrays (`temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, `precipitation_sum`), responses with mismatched array lengths, duplicate dates, or gaps.
- **Cache Identity Changes:**
  - Historical cache key: `'hist_openmeteo_era5_${coord.latitude}_${coord.longitude}_${startIso}_$endIso'`
  - Forecast cache key: `'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_$days'`
  - Exact double coordinate values are preserved without lossy client-side decimal rounding, guaranteeing strict cache isolation.
- **Protection Against Invalid Cache Overwrite:**
  - Persistence is guarded: empty, malformed, or out-of-range network responses are rejected prior to touching memory (L1) or SQLite (L2) caches, preserving existing valid offline data.
- **Provenance Consistency:**
  - Domain provenance entities faithfully record provider, dataset name, requested coordinates, resolved grid coordinates, grid elevation, acquisition timestamp, and stale fallback flags.

---

### 5. Scientific and Geographic Corrections
- **Forecast Source Identity:**
  - Clarified and labeled as `Open-Meteo Best Match Forecast` rather than falsely claiming a specific ECMWF/DWD blend when no explicit model was requested.
- **Geographic Validation:**
  - The bounding rectangle $[22.0, 31.8]^\circ\text{N} \times [25.0, 37.0]^\circ\text{E}$ is officially designated and documented as an approximate operational screening envelope, removing inaccurate claims of legal political boundary validation.
- **Acceptance Threshold Documentation:**
  - Distinguishes operational data-quality thresholds ($[-5.0^\circ\text{C}, +55.0^\circ\text{C}]$, $ET_0 \le 25\text{ mm}$, $P \le 250\text{ mm}$) from physical invariants ($T_{\max} \ge T_{\min}$, non-negative precipitation) in `DATA_SOURCES_AND_VALIDATION.md`.
- **$ET_0$ Completeness and Aggregation:**
  - Both `environmental_analysis_screen.dart` and `dashboard_screen.dart` track available observation days and explicitly flag partial sums when days are missing.

---

### 6. Tests Actually Executed

| Command | Executed | Result | Test Count | Details |
|---|---|---|---|---|
| `flutter test test/data/open_meteo_adapter_tests.dart` | Yes | PASS | 26 tests | Complete 4-variable array validation, sequence checks, missingness tolerance, null vs 0.0 preservation. |
| `flutter test test/data/persistence_tests.dart` | Yes | PASS | 58 tests | Cache isolation, `models=era5` outgoing query, stale fallback, 429 Retry-After, Cairo DST boundaries. |
| `flutter test test/domain/domain_scientific_tests.dart` | Yes | PASS | 23 tests | Geographic coordinate validation, physical ranges, GDD, $ET_c$, heat stress, crop rotation. |
| `flutter test test/widget_test.dart` | Yes | PASS | 2 tests | App bootstrap navigation and distinct requested vs grid coordinate rendering in `ProvenanceCard`. |
| `flutter test test/data/ test/domain/ test/widget_test.dart` | Yes | PASS | 109 tests | Full test suite passed synchronously with 0 failures. |

---

### 7. Static Analysis and Build

| Command | Executed | Result | Details |
|---|---|---|---|
| `dart format lib/ test/` | Yes | PASS | Formatted 42 files (clean formatting). |
| `flutter analyze` | Yes | PASS | **No issues found!** (0 errors, 0 warnings, 0 lints). |
| `flutter build apk --release` | Yes | PASS | Built `build\app\outputs\flutter-apk\app-release.apk` (58.7 MB) successfully in 55.4s. |

---

### 8. Live API Verification
- **Execution:** Live HTTP GET requests were executed against the official Open-Meteo endpoints using PowerShell.
- **Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
- **Location:** Kafr El-Sheikh field coordinates (`latitude=31.10`, `longitude=30.95`).
- **Date Range Tested:** `2024-06-01` to `2024-06-05` (well beyond the 5-day publication delay).
- **Comparison Findings:**
  1. With `models=era5_land`: `et0_fao_evapotranspiration` returned `[null, null, null, null, null]`, `precipitation_sum` returned `[null, null, null, null, null]`.
  2. With `models=era5`: All four variables returned valid numbers: $T_{\max} \approx 34.0^\circ\text{C}$, $T_{\min} \approx 21.0^\circ\text{C}$, $ET_0 \approx 7.8\text{ mm/day}$, $P = 0.0\text{ mm/day}$.
  3. Default (no models parameter): Returns high-resolution seamless reanalysis grid with all four variables present.
- **Decision:** Explicitly configured `models=era5` in production code to guarantee global ECMWF reanalysis consistency with all four required variables.

---

### 9. Remaining Risks
- **Low (Operational):** Upstream publication delay of 5 calendar days means the most recent 5 days must be accessed via short-term forecast or recent operational archive once released. This is safely clamped and communicated in Arabic to the user.
- **Low (Geographic):** Coordinate validation utilizes an operational rectangular bounding envelope. A small strip of sea or uninhabited desert border is within the envelope; however, all valid Egyptian agricultural land is properly supported without external GIS polygon dependencies.

---

### 10. Final Status
**PASS — Ready for independent review**
