# Open-Meteo Historical Weather API Model Compatibility Validation

**Observation Date:** 2026-10-25T18:55:20Z (2026-10-25T21:55:20+03:00)  
**Target Domain:** Arab Republic of Egypt (Nile Delta — Kafr El-Sheikh)  
**Coordinate:** Requested Latitude 31.10°N, Longitude 30.95°E  
**Date Range:** 2024-06-01 to 2024-06-05 (5 days)  
**Timezone:** `Africa/Cairo`  
**Required Variables (4 daily variables):**
1. `temperature_2m_max`
2. `temperature_2m_min`
3. `et0_fao_evapotranspiration`
4. `precipitation_sum`

---

## 1. Objective and Authority

To provide reproducible, empirical evidence comparing model compatibility on the live Open-Meteo Historical Weather API (`https://archive-api.open-meteo.com/v1/archive`) against official provider documentation across four configurations:
1. `models=era5` (ECMWF ERA5 Reanalysis, nominal 0.25° grid)
2. `models=era5_seamless` (ECMWF ERA5 with seamless forecast/reanalysis blending)
3. `models=era5_land` (ECMWF ERA5-Land high-resolution land-surface dataset, nominal 0.1° grid)
4. Default (no `models` parameter specified, IFS/ERA5 best match baseline)

### Official Open-Meteo Documentation Reconcilement
According to official Open-Meteo Historical Weather API documentation (`https://open-meteo.com/en/docs/historical-weather-api`):
- `era5` provides global historical weather data at ~25 km resolution from 1940 to present (with a 5-day publication delay), including integrated atmospheric calculations such as reference evapotranspiration ($ET_0$) and accumulated precipitation.
- `era5_land` is a specialized land-surface reanalysis dataset forced by ERA5 atmospheric conditions at ~9 km resolution. However, on Open-Meteo's historical endpoint, several secondary diagnostics (specifically FAO-56 reference evapotranspiration `et0_fao_evapotranspiration` and daily total precipitation `precipitation_sum`) are **not generated or populated** for the standalone ERA5-Land model selection, resulting in null arrays for those daily variables.
- Therefore, requesting `models=era5_land` returns HTTP 200 OK, but produces empty / null arrays for $ET_0$ and precipitation. This demonstrates why an HTTP 200 response alone does not guarantee variable completeness.

---

## 2. Experimental Execution and Results Summary

All four configurations were queried live on **2026-10-25T18:55:20Z** using `scripts/validate_historical_models.ps1` with identical parameters.

| Model Configuration | HTTP Status | Returned Grid (Lat, Lon, Elev) | $T_{2m,\max}$ Array (°C) | $T_{2m,\min}$ Array (°C) | $ET_{0,\text{FAO}}$ Array (mm) | Precip Array (mm) | Null Count | Compatibility Assessment |
|---|---|---|---|---|---|---|---|---|
| `models=era5` | **200 OK** | 31.0°N, 31.0°E, 6.0m | `[37.8, 35.2, 35.4, 36.6, 37.5]` | `[20.8, 21.3, 21.5, 21.4, 22.1]` | `[7.89, 7.82, 7.76, 7.43, 7.59]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | 0 / 20 | **PASS** — Complete numeric readings across all 4 variables. |
| `models=era5_seamless` | **200 OK** | 31.1°N, 31.0°E, 6.0m | `[38.3, 36.1, 36.0, 37.5, 38.6]` | `[20.6, 20.0, 20.4, 20.0, 21.1]` | `[7.91, 7.89, 7.90, 7.54, 7.73]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | 0 / 20 | **PASS** — Complete numeric readings across all 4 variables. |
| `models=era5_land` | **200 OK** | 31.1°N, 31.0°E, 6.0m | `[38.3, 36.1, 36.0, 37.5, 38.6]` | `[20.6, 20.0, 20.4, 20.0, 21.1]` | `[null, null, null, null, null]` | `[null, null, null, null, null]` | 10 / 20 | **FAIL** — $ET_0$ and precipitation are completely omitted. |
| Default (no model) | **200 OK** | 31.107°N, 30.998°E, 6.0m | `[40.7, 38.0, 36.8, 38.5, 39.4]` | `[20.9, 21.1, 21.0, 20.6, 20.9]` | `[8.23, 8.20, 8.38, 7.89, 8.15]` | `[0.0, 0.0, 0.0, 0.0, 0.0]` | 0 / 20 | **PASS** — Populated, but dataset identity is ambiguous and blended. |

---

## 3. Full Raw Response Fixtures

Raw JSON responses for each configuration are saved in `docs/fixtures/historical_api/`.

### 3.1 Configuration 1: `models=era5`
**Request:**
`GET https://archive-api.open-meteo.com/v1/archive?latitude=31.10&longitude=30.95&start_date=2024-06-01&end_date=2024-06-05&daily=temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum&timezone=Africa%2FCairo&models=era5`

**Response:**
```json
{
  "latitude": 31.0,
  "longitude": 31.0,
  "generationtime_ms": 0.2652406692504883,
  "utc_offset_seconds": 10800,
  "timezone": "Africa/Cairo",
  "timezone_abbreviation": "GMT+3",
  "elevation": 6.0,
  "daily_units": {
    "time": "iso8601",
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm"
  },
  "daily": {
    "time": [
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05"
    ],
    "temperature_2m_max": [
      37.8,
      35.2,
      35.4,
      36.6,
      37.5
    ],
    "temperature_2m_min": [
      20.8,
      21.3,
      21.5,
      21.4,
      22.1
    ],
    "et0_fao_evapotranspiration": [
      7.89,
      7.82,
      7.76,
      7.43,
      7.59
    ],
    "precipitation_sum": [
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ]
  }
}
```

### 3.2 Configuration 2: `models=era5_seamless`
**Request:**
`GET https://archive-api.open-meteo.com/v1/archive?latitude=31.10&longitude=30.95&start_date=2024-06-01&end_date=2024-06-05&daily=temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum&timezone=Africa%2FCairo&models=era5_seamless`

**Response:**
```json
{
  "latitude": 31.099998,
  "longitude": 31.0,
  "generationtime_ms": 0.21183490753173828,
  "utc_offset_seconds": 10800,
  "timezone": "Africa/Cairo",
  "timezone_abbreviation": "GMT+3",
  "elevation": 6.0,
  "daily_units": {
    "time": "iso8601",
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm"
  },
  "daily": {
    "time": [
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05"
    ],
    "temperature_2m_max": [
      38.3,
      36.1,
      36.0,
      37.5,
      38.6
    ],
    "temperature_2m_min": [
      20.6,
      20.0,
      20.4,
      20.0,
      21.1
    ],
    "et0_fao_evapotranspiration": [
      7.91,
      7.89,
      7.9,
      7.54,
      7.73
    ],
    "precipitation_sum": [
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ]
  }
}
```

### 3.3 Configuration 3: `models=era5_land`
**Request:**
`GET https://archive-api.open-meteo.com/v1/archive?latitude=31.10&longitude=30.95&start_date=2024-06-01&end_date=2024-06-05&daily=temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum&timezone=Africa%2FCairo&models=era5_land`

**Response:**
```json
{
  "latitude": 31.099998,
  "longitude": 31.0,
  "generationtime_ms": 0.4706382751464844,
  "utc_offset_seconds": 10800,
  "timezone": "Africa/Cairo",
  "timezone_abbreviation": "GMT+3",
  "elevation": 6.0,
  "daily_units": {
    "time": "iso8601",
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm"
  },
  "daily": {
    "time": [
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05"
    ],
    "temperature_2m_max": [
      38.3,
      36.1,
      36.0,
      37.5,
      38.6
    ],
    "temperature_2m_min": [
      20.6,
      20.0,
      20.4,
      20.0,
      21.1
    ],
    "et0_fao_evapotranspiration": [
      null,
      null,
      null,
      null,
      null
    ],
    "precipitation_sum": [
      null,
      null,
      null,
      null,
      null
    ]
  }
}
```

### 3.4 Configuration 4: Default (No models parameter)
**Request:**
`GET https://archive-api.open-meteo.com/v1/archive?latitude=31.10&longitude=30.95&start_date=2024-06-01&end_date=2024-06-05&daily=temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum&timezone=Africa%2FCairo`

**Response:**
```json
{
  "latitude": 31.107204,
  "longitude": 30.997625,
  "generationtime_ms": 0.2644062042236328,
  "utc_offset_seconds": 10800,
  "timezone": "Africa/Cairo",
  "timezone_abbreviation": "GMT+3",
  "elevation": 6.0,
  "daily_units": {
    "time": "iso8601",
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm"
  },
  "daily": {
    "time": [
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05"
    ],
    "temperature_2m_max": [
      40.7,
      38.0,
      36.8,
      38.5,
      39.4
    ],
    "temperature_2m_min": [
      20.9,
      21.1,
      21.0,
      20.6,
      20.9
    ],
    "et0_fao_evapotranspiration": [
      8.23,
      8.2,
      8.38,
      7.89,
      8.15
    ],
    "precipitation_sum": [
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ]
  }
}
```

---

## 4. Architectural Selection and Rationale

1. **`models=era5` Selected as Verified Production Baseline:**
   - Explicit selection `models=era5` guarantees an unblended, authoritative ECMWF global atmospheric reanalysis dataset.
   - All four required variables ($T_{\max}$, $T_{\min}$, $ET_0$, precipitation) are fully populated and physically consistent.
   - The selected model remains centralized in `lib/data/datasources/remote/open_meteo_remote_data_source.dart`:
     ```dart
     static const String historicalModel = 'era5';
     ```
2. **Definitive Rejection of `era5_land`:**
   - Both empirical testing and provider documentation confirm that Open-Meteo's `era5_land` configuration omits $ET_0$ and precipitation (`null` arrays). It cannot support AgroShift's irrigation requirement calculations.
3. **Traceability and Provenance Accuracy:**
   - Provenance records `datasetName: 'ERA5 Reanalysis Archive'` and grid coordinates `(31.0°N, 31.0°E)`, matching the actual returned reanalysis grid resolution cell.
   - Requested coordinates `(31.10°N, 30.95°E)` are preserved distinctly from grid coordinates in all database rows and UI displays.

---

## 5. Local Reproduction Instructions

To reproduce these observations directly from PowerShell on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate_historical_models.ps1
```
