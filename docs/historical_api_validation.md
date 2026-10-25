# Open-Meteo Historical Weather API Model Compatibility Validation

**Observation Date:** 2026-10-25T14:45:00+03:00  
**Target Domain:** Arab Republic of Egypt (Nile Delta — Kafr El-Sheikh)  
**Coordinate:** Latitude 31.10°N, Longitude 30.95°E  
**Date Range:** 2024-06-01 to 2024-06-05 (5 days)  
**Timezone:** Africa/Cairo  
**Required Variables (4 daily variables):**
1. `temperature_2m_max`
2. `temperature_2m_min`
3. `et0_fao_evapotranspiration`
4. `precipitation_sum`

---

## 1. Objective

To provide reproducible empirical evidence testing model compatibility on the live Open-Meteo Historical Weather API (`https://archive-api.open-meteo.com/v1/archive`) across four model selections:
- `models=era5` (ECMWF ERA5 Reanalysis, nominal 0.25°)
- `models=era5_seamless` (ECMWF ERA5 with multi-model seamless integration)
- `models=era5_land` (ECMWF ERA5-Land high-resolution 0.1°)
- Default / unassigned (IFS/ERA5 best match baseline)

---

## 2. Experimental Results Summary

| Model Configuration | HTTP Status | Returned Grid (Lat, Lon, Elev) | $T_{2m,\max}$ Array | $T_{2m,\min}$ Array | $ET_{0,\text{FAO}}$ Array | Precipitation Sum Array | Compatibility Assessment |
|---|---|---|---|---|---|---|---|
| `models=era5` | **200 OK** | 31.0°N, 31.0°E, 6.0m | `[37.8, 35.2, 35.4, 36.6, 37.5]` | `[20.8, 21.3, 21.5, 21.4, 22.1]` | `[7.89, 7.82, 7.76, 7.43, 7.59]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | **PASS** — All 4 variables fully populated with valid numeric readings. |
| `models=era5_seamless` | **200 OK** | 31.1°N, 31.0°E, 6.0m | `[38.3, 36.1, 36.0, 37.5, 38.6]` | `[20.6, 20.0, 20.4, 20.0, 21.1]` | `[7.91, 7.89, 7.90, 7.54, 7.73]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | **PASS** — All 4 variables fully populated with valid numeric readings. |
| `models=era5_land` | **200 OK** | 31.1°N, 31.0°E, 6.0m | `[37.1, 34.6, 34.5, 36.2, 37.3]` | `[21.2, 20.9, 21.3, 20.8, 21.8]` | `[null, null, null, null, null]` | `[null, null, null, null, null]` | **FAIL** — $ET_0$ and precipitation are completely omitted (null arrays). |
| Default (no model) | **200 OK** | 31.107°N, 30.998°E, 6.0m | `[38.1, 35.8, 35.7, 37.1, 38.2]` | `[20.7, 20.4, 20.8, 20.4, 21.5]` | `[7.90, 7.85, 7.82, 7.49, 7.66]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | **PASS** — Populated, but model identity is ambiguous / blended. |

---

## 3. Representative Raw Response Fixture (`models=era5`)

### Request
```http
GET /v1/archive?latitude=31.10&longitude=30.95&start_date=2024-06-01&end_date=2024-06-05&daily=temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum&timezone=Africa/Cairo&models=era5 HTTP/1.1
Host: archive-api.open-meteo.com
```

### Response
```json
{
  "latitude": 31.0,
  "longitude": 31.0,
  "generationtime_ms": 0.3540515899658203,
  "utc_offset_seconds": 10800,
  "timezone": "Africa/Cairo",
  "timezone_abbreviation": "EEST",
  "elevation": 6.0,
  "daily_units": {
    "time": "iso8601",
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm"
  },
  "daily": {
    "time": ["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"],
    "temperature_2m_max": [37.8, 35.2, 35.4, 36.6, 37.5],
    "temperature_2m_min": [20.8, 21.3, 21.5, 21.4, 22.1],
    "et0_fao_evapotranspiration": [7.89, 7.82, 7.76, 7.43, 7.59],
    "precipitation_sum": [0.0, 0.0, 0.0, 0.0, 0.0]
  }
}
```

---

## 4. Architectural Selection and Rationale

1. **`models=era5` Selected as Verified Baseline:**
   - Both `era5` and `era5_seamless` supply all four variables without nulls.
   - `models=era5` represents the clean, canonical ECMWF ERA5 global reanalysis dataset without intermediate blending heuristics.
   - The selected model is centralized as `OpenMeteoRemoteDataSource.historicalModel = 'era5'`.
2. **Definitive Rejection of `era5_land`:**
   - `era5_land` on Open-Meteo returns null arrays for `et0_fao_evapotranspiration` and `precipitation_sum`. It cannot be used for agricultural water requirement calculations.
3. **Traceability:**
   - Provenance records `datasetName: 'ERA5 Reanalysis Archive'` and grid coordinates `(31.0°N, 31.0°E)`, matching the actual returned reanalysis grid resolution cell.
