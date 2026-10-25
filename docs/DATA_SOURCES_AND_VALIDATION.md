# AgroShift — Data Sources and Scientific Validation Protocol

**Document Version:** 1.0.0  
**Domain Scope:** Arab Republic of Egypt (Nile Delta and Valley)

---

## 1. Candidate Data Sources and Evaluation Matrix

| Source | Role in AgroShift | Variables Utilized | Spatial Resolution | Time Frequency | Verified Limitations | Status |
|---|---|---|---|---|---|---|
| **Open-Meteo Historical Archive** | Primary Environmental Baseline (`models=era5`) | $T_{2m,\max}$, $T_{2m,\min}$, $ET_{0,\text{FAO}}$, Precipitation sum | ~25 km (0.25°) ECMWF ERA5 reanalysis grid | Daily aggregations | Upstream publication delay of 5 calendar days; gridded reanalysis interpolation; not an in-situ station. Note on spatial resolution: ECMWF ERA5 native resolution is 0.25° (~27.8 km at the equator). Because longitude lines converge toward the poles ($\approx 111 \times \cos(\text{latitude})\text{ km}$), at Egyptian latitudes ($22^\circ\text{N} - 31.8^\circ\text{N}$), the longitudinal grid spacing corresponds to approximately $24–26\text{ km}$, giving an average spatial resolution of ~25 km. (Note: `models=era5_land` was experimentally verified to omit daily $ET_0$ and precipitation on Open-Meteo, returning null; `models=era5` fully provides all four required variables). | **Approved (Active Baseline: ERA5 Reanalysis)** |
| **Open-Meteo Forecast API** | Short-Term Operational Monitoring (Best Match) | $T_{2m,\max}$, $T_{2m,\min}$, $ET_{0,\text{FAO}}$, Precipitation sum | ~2–11 km Seamless multi-model blend (ICON, IFS, GFS) | Daily (up to 7 days) | Numerical weather prediction model uncertainty increases significantly past day 3. Labelled honestly as Open-Meteo Best Match Forecast rather than asserting a single proprietary model. | **Approved (Short-term Forecast)** |
| **NASA POWER (Agroclimatology)** | Cross-Comparison / Validation Reference | $T_{2m}$, $RH_{2m}$, AllSky Insolation (`ALLSKY_SFC_SW_DWN`) | Meteorology: 0.5° × 0.625° (MERRA-2 GMAO); Solar: 1.0° × 1.0° (satellite CERES) | Daily | Coarse spatial resolution (50–100 km) blurs Nile River microclimates; FAO-56 $ET_0$ is not a native direct atmospheric variable in MERRA-2 (must be derived via Penman-Monteith). Furthermore, NASA POWER combines multiple assimilation streams and satellite instrument eras (e.g. MERRA-2 meteorological assimilation updates and transitions between satellite radiation instruments such as CERES and earlier sensors), introducing temporal discontinuities and structural heterogeneity that must be carefully controlled when conducting multi-decadal trend analyses. | **Secondary Reference Only (Not Queried at Runtime)** |
| **Space Apps Competition API** | Target Official Data Source | TBD | TBD | TBD | Endpoints and schema not yet released. No endpoints are assumed or invented. | **Awaiting Release** |

> **Important Scientific Distinction:** Agreement between Open-Meteo (ERA5) and NASA POWER (MERRA-2) merely demonstrates that two atmospheric models with overlapping boundary inputs arrive at similar numerical results. **Model concordance is NOT proof of ground-truth accuracy.** Furthermore, daily FAO-56 reference evapotranspiration ($ET_0$) in AgroShift is obtained directly from the Open-Meteo daily endpoint (`et0_fao_evapotranspiration`, computed upstream via FAO-56 Penman-Monteith) and is not re-computed client-side.
>
> **Display Architecture Clarification:** In the application UI (e.g., `EnvironmentalAnalysisScreen` and `DashboardScreen`), a primary dataset provenance card (`ProvenanceCard`) is rendered at the foot of each meteorological view to represent the active dataset sequence that generated the charts and summary metrics (e.g., ERA5 Reanalysis Archive or Open-Meteo Best Match Forecast). This guarantees single-card visual clarity while exposing full provenance metadata (model name, provider, requested vs resolved coordinates, elevation, timestamp, and staleness flag).

---

## 2. Physical Range Validation & Operational Quality Gates

Every incoming data point must pass through the `ScientificRangeValidator` before domain entities are instantiated. If any value falls outside physical boundaries, the record is flagged as corrupted or invalid.

### Physical Acceptance Ranges & Operational Thresholds for Egypt:

| Parameter | Unit | Code Validation Limit (`AgroConstants`) | Scientific Nature & Documentation | Action on Out-of-Range |
|---|---|---|---|---|
| **Daily Temperature Extreme ($T_{\max}$, $T_{\min}$)** | °C | $[-5.0, +55.0]$ | **Operational Data-Quality Envelope**: Broad screening limits encompassing Sinai high-elevation frost ($T_{\min} \ge -5^\circ\text{C}$) to Western Desert summer peaks ($T_{\max} \le +55^\circ\text{C}$). | Reject record; flag `PhysicalRangeFailure` |
| **Regional Daily $T_{\max}$ Expectation** | °C | Enforced by $[-5.0, +55.0]$ | Typical Nile agricultural valley $T_{\max} \in [+5.0, +55.0]^\circ\text{C}$. | Monitored |
| **Regional Daily $T_{\min}$ Expectation** | °C | Enforced by $[-5.0, +55.0]$ | Typical Nile agricultural valley $T_{\min} \in [-5.0, +42.0]^\circ\text{C}$. | Monitored |
| **Temperature Consistency** | Logic | $T_{\max} \ge T_{\min}$ | **Physical Law**: $T_{\max}$ cannot be strictly less than $T_{\min}$. | Reject record if $T_{\max} < $T_{\min}$ |
| **Reference Evapotranspiration ($ET_0$)** | mm/day | $[0.0, 25.0]$ | **Operational Screening Threshold**: Captures hyper-arid summer advective peak demand ($<25\text{ mm/day}$) per FAO-56; non-negative. | Reject record if negative or $>25$ |
| **Precipitation Sum ($P$)** | mm/day | $[0.0, 250.0]$ | **Operational Screening Threshold**: Arid baseline to extreme flash flood convective cloudburst ($<250\text{ mm/day}$); non-negative. | Reject record if negative or $>250$ |
| **Geographic Latitude** | Decimal degrees | $[22.0000, 31.8000]$ | **Approximate Bounding Box Envelope**: Geospatial sanity box covering the Egyptian territory. Does not constitute a legal/political boundary polygon. | Reject coordinates outside bounding envelope |
| **Geographic Longitude** | Decimal degrees | $[25.0000, 37.0000]$ | **Approximate Bounding Box Envelope**: Geospatial sanity box covering the Egyptian territory. Does not constitute a legal/political boundary polygon. | Reject coordinates outside bounding envelope |

> **Scientific Threshold Finding & Clarification:**
> In `ScientificRangeValidator`, both $T_{\max}$ and $T_{\min}$ are validated against the operational envelope `[AgroConstants.minAcceptableTempC, AgroConstants.maxAcceptableTempC]` ($[-5.0^\circ\text{C}, +55.0^\circ\text{C}]$), combined with the strict invariant $T_{\max} \ge T_{\min}$. Regional climatological expectations describe typical agricultural baselines but are not used as hard rejection thresholds in code to prevent rejecting valid winter extremes in Sinai or hot nocturnal records in Upper Egypt.
> Similarly, the coordinate rectangle $[22.0, 31.8]^\circ\text{N} \times [25.0, 37.0]^\circ\text{E}$ is an operational bounding screening box, preventing accidental global queries while supporting all Egyptian agricultural regions.

---

## 3. Strict Missing-Data Semantics & Completeness Reporting

1. **Zero vs. Missing Distinction:**
   - Rain gauge or model recording $0.0\text{ mm}$ indicates an affirmative measurement of **no rain**. It must be preserved as `0.0` and factored into aridity indices.
   - A missing day (null value, network dropout, or unpopulated index) must be stored as `null`. It must **never** be silently converted to `0.0`.
2. **Missingness Thresholds for Decision Support:**
   - In any calculation window (e.g., 30-day water requirement or seasonal GDD accumulation), if the percentage of missing days exceeds **10%**, the system MUST refuse to compute a composite score.
   - The UI will explicitly display:
     > **"بيانات الأرصاد غير مكتملة (نسبة الفقد > 10%): لا يمكن تقديم تقدير زراعي مؤكد"**  
     > *(Incomplete meteorological data: Evidence insufficient for agronomic estimation)*.
3. **Transparent Completeness Reporting in Summaries:**
   - When presenting period sums (such as 30-day cumulative $ET_0$ or 7-day forecast $ET_c$), the application tracks the exact count of days with valid measurements against the **total requested period length** (`expectedPeriodDays`), rather than merely against surviving records.
   - If days are excluded due to missing temperature readings (up to 10%), or if specific days lack $ET_0$ readings, the total is labeled as a **partial sum (مجموع جزئي)** with the explicit ratio against the requested period (e.g. "28 of 30 requested days").
   - Explicit alerts break down the source of missingness (e.g. unrecorded temperature days vs null $ET_0$ values), ensuring users never confuse surviving-record counts with complete interval coverage.

---

## 4. Source Provenance Metadata

Every displayed metric and chart in AgroShift exposes its provenance block via `DataSourceProvenance`:
- **Provider Identity:** (e.g. `Open-Meteo Weather API`)
- **Dataset / Model Identity:** (e.g. `ERA5 Reanalysis Archive` requested with `models=era5`)
- **Requested Coordinates:** (e.g. `Lat: 31.1000, Lon: 30.9500` - Kafr El-Sheikh field location)
- **Grid Coordinates:** (e.g. `Lat: 31.1250, Lon: 31.0000` - resolved atmospheric model cell)
- **Grid Elevation:** Model grid elevation above sea level in meters
- **Timestamp of Acquisition:** ISO-8601 UTC timestamp
- **Freshness / Stale Status:** `isStaleFallback` boolean flag
- **Uncertainty Note:** Gridded reanalysis data carries inherent spatial smoothing uncertainty.

> **Provenance Status Audit:**
> - **Implemented & Displayed:** Provider name, dataset name, requested coordinates, grid coordinates, grid elevation, acquisition timestamp, Arabic scientific disclaimer, and `isStaleFallback` state flag.
> - **Separation of Coordinates:** The UI explicitly presents requested field coordinates and resolved atmospheric grid coordinates on separate lines to prevent conflating user input with model resolution cells.

---

## 5. ERA5 Historical Archive Publication Delay Policy

- **Official Source Requirement:** Based on the official [Open-Meteo Historical Weather API documentation](https://open-meteo.com/en/docs/historical-weather-api), ERA5 reanalysis products have an upstream publication delay of typically **5 calendar days**.
- **Eligible Date Calculation:**
  $$\text{latestEligibleDate} = \text{CairoToday} - 5\text{ calendar days}$$
  The latest eligible date is derived exclusively using Egypt's civil calendar date (`Africa/Cairo` timezone via `WeatherRepositoryImpl.getCairoDateTime()`) rather than the client device's local clock.
- **Interval Clamping and Failure Semantics:**
  - If a requested historical query has an end date later than `latestEligibleDate`, the effective end date is clamped to `latestEligibleDate`.
  - If the requested interval contains no eligible days (i.e. $\text{startDate} > \text{effectiveEndDate}$), the repository rejects the request immediately with an `InsufficientEvidenceFailure` (Arabic user message indicating that the requested interval falls within the 5-day publication delay).
  - Short-term forecast queries remain completely independent of this 5-day archive delay.

---

## 6. Raw Response vs. Filtered Domain Sequence Validation

1. **Raw API Response Integrity (`OpenMeteoAdapter`):**
   - **Parallel Arrays:** All variable arrays (`temperature_2m_max`, `temperature_2m_min`, `et0_fao_evapotranspiration`, `precipitation_sum`) must have identical length to the `time` array.
   - **Strict ISO Format:** Dates must strictly match `^\d{4}-\d{2}-\d{2}$` and survive calendar round-trip parsing without shifting.
   - **Ascending & Non-Duplicate:** Raw time array must be strictly chronological ($t_i > t_{i-1}$) with no duplicate dates.
   - **Daily Continuity:** In raw API responses, consecutive days must have $\Delta t = 1\text{ day}$. Gaps in raw daily responses trigger a `DataIntegrityFailure`.
   - **Interval Containment:** Raw dates must fall within $[\text{expectedStartDate}, \text{expectedEndDate}]$.
2. **Domain-Level Filtering (`DailyAgroRecord`):**
   - Individual days with missing temperatures ($\text{null}$) are omitted from the domain record list when overall missingness is $\le 10\%$.
   - Consequently, the filtered domain sequence may contain valid date gaps, which must **not** be confused with corrupted gaps in the raw API feed.

---

## 7. Cache Freshness, TTL, and Stale Fallback Protocol

- **Forecast Cache TTL:** 6 hours (`CachePolicy.forecastTtl`).
- **Historical Cache TTL:** 7 days (`CachePolicy.historicalTtl`).
- **L1 In-Memory Alignment:** L1 entries track an explicit `storedAt` timestamp. Expired L1 entries are never served as fresh data.
- **Stale Fallback Safety:**
  - Stale fallback is allowed **only** during transient network faults (connection errors, timeouts, HTTP 5xx, HTTP 429).
  - Non-transient client errors (HTTP 400, 401, 403, 422) **never** consume stale cache and return typed failures immediately.
  - Stale records are tagged with `isStaleFallback: true` and an explicit Arabic user notice. Fresh network data is never marked as stale.

