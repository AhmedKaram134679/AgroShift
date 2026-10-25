# AgroShift — Data Sources and Scientific Validation Protocol

**Document Version:** 1.0.0  
**Domain Scope:** Arab Republic of Egypt (Nile Delta and Valley)

---

## 1. Candidate Data Sources and Evaluation Matrix

| Source | Role in AgroShift | Variables Utilized | Spatial Resolution | Time Frequency | Verified Limitations | Status |
|---|---|---|---|---|---|---|
| **Open-Meteo Historical Archive** | Provisional Environmental Baseline | $T_{2m,\max}$, $T_{2m,\min}$, $ET_{0,\text{FAO}}$, Precipitation sum | ~11 km (0.1°) ERA5-Land reanalysis grid | Daily aggregations | Grid interpolation; not a localized in-situ station; coastal fog underrepresented in Delta. | **Approved (Provisional Baseline)** |
| **Open-Meteo Forecast API** | Short-Term Operational Monitoring | $T_{2m,\max}$, $T_{2m,\min}$, $ET_{0,\text{FAO}}$, Precipitation sum | ~11 km (0.1°) Seamless DWD/ECMWF blend | Daily (up to 7 days) | Numerical weather prediction model uncertainty increases significantly past day 3. | **Approved (Short-term Forecast)** |
| **NASA POWER (Agroclimatology)** | Cross-Comparison / Validation Source | $T_{2m}$, $RH_{2m}$, AllSky Insolation, $ET_0$ | 0.5° × 0.5° (~50 km) | Daily | Coarse spatial resolution (50 km) blurs Nile River microclimates and sharp canal boundary conditions. | **Secondary / Evaluation only** |
| **Space Apps Competition API** | Target Official Data Source | TBD | TBD | TBD | Endpoints and schema not yet released. No endpoints are assumed or invented. | **Awaiting Release** |

> **Important Distinction:** Agreement between Open-Meteo (ERA5-Land) and NASA POWER (MERRA-2) merely demonstrates that two atmospheric models with overlapping boundary inputs arrive at similar numerical results. **Model concordance is NOT proof of ground-truth accuracy.**

---

## 2. Physical Range Validation & Quality Gates

Every incoming data point must pass through the `ScientificRangeValidator` before domain entities are instantiated. If any value falls outside physical boundaries, the record is flagged as corrupted or invalid.

### Physical Acceptance Ranges for Egypt:

| Parameter | Unit | Acceptable Physical Range | Action on Out-of-Range |
|---|---|---|---|
| **Daily Max Temperature ($T_{\max}$)** | °C | $[+5.0, +55.0]$ | Reject record; flag `PhysicalRangeFailure` |
| **Daily Min Temperature ($T_{\min}$)** | °C | $[-5.0, +42.0]$ | Reject record; flag `PhysicalRangeFailure` |
| **Temperature Consistency** | Logic | $T_{\max} \ge T_{\min}$ | Reject record if $T_{\max} < T_{\min}$ |
| **Reference Evapotranspiration ($ET_0$)** | mm/day | $[0.0, 25.0]$ | Reject record if negative or $>25$ |
| **Precipitation Sum ($P$)** | mm/day | $[0.0, 250.0]$ | Reject record if negative or $>250$ |
| **Geographic Latitude** | Decimal degrees | $[22.0000, 31.8000]$ | Reject coordinates outside Egypt bounds |
| **Geographic Longitude** | Decimal degrees | $[25.0000, 37.0000]$ | Reject coordinates outside Egypt bounds |

---

## 3. Strict Missing-Data Semantics

1. **Zero vs. Missing Distinction:**
   - Rain gauge or model recording $0.0\text{ mm}$ indicates an affirmative measurement of **no rain**. It must be preserved as `0.0` and factored into aridity indices.
   - A missing day (null value, network dropout, or unpopulated index) must be stored as `null`. It must **never** be silently converted to `0.0`.
2. **Missingness Thresholds for Decision Support:**
   - In any calculation window (e.g., 30-day water requirement or seasonal GDD accumulation), if the percentage of missing days exceeds **10%**, the system MUST refuse to compute a composite score.
   - The UI will explicitly display:
     > **"بيانات الأرصاد غير مكتملة (نسبة الفقد > 10%): لا يمكن تقديم تقدير زراعي مؤكد"**  
     > *(Incomplete meteorological data: Evidence insufficient for agronomic estimation)*.

---

## 4. Source Provenance Metadata

Every displayed metric and chart in AgroShift must expose its provenance block:
- **Provider Identity:** (e.g. `Open-Meteo ERA5-Land Archive`)
- **Requested Coordinates:** (e.g. `Lat: 31.102, Lon: 30.945` - Kafr El-Sheikh)
- **Grid Coordinates:** (e.g. `Lat: 31.100, Lon: 30.900`)
- **Grid Distance Offset:** e.g. $\Delta \approx 4.2\text{ km}$
- **Elevation Offset:** Ground elevation vs. Model grid elevation
- **Timestamp of Acquisition:** ISO-8601 UTC timestamp
- **Uncertainty Note:** Gridded reanalysis data carries inherent spatial smoothing uncertainty.
