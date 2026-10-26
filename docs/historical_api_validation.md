# Open-Meteo Historical Weather API Model Compatibility Validation

**Observation Date:** 2026-10-25T18:55:20Z (2026-10-25T21:55:20+03:00)\
**Target Domain:** Arab Republic of Egypt (Nile Delta — Kafr El-Sheikh)\
**Coordinate:** Requested Latitude 31.10°N, Longitude 30.95°E\
**Date Range:** 2024-06-01 to 2024-06-05 (5 days)\
**Timezone:** `Africa/Cairo`\
**Required Variables (4 daily variables):**

1. `temperature_2m_max`
2. `temperature_2m_min`
3. `et0_fao_evapotranspiration`
4. `precipitation_sum`

---

## 1. Objective and Authority

To provide reproducible, empirical evidence comparing model compatibility on the
live Open-Meteo Historical Weather API
(`https://archive-api.open-meteo.com/v1/archive`) against official provider
documentation across four configurations:

1. `models=era5` (ECMWF ERA5 Reanalysis, nominal 0.25° grid)
2. `models=era5_seamless` (ECMWF ERA5 with seamless forecast/reanalysis
   blending)
3. `models=era5_land` (ECMWF ERA5-Land high-resolution land-surface dataset,
   nominal 0.1° grid)
4. Default (no `models` parameter specified, IFS/ERA5 best match baseline)

### Official Open-Meteo Documentation vs. Empirical Project Observations

A critical distinction must be maintained between official provider documentation
and observed project responses:

1. **Officially Documented Availability:**
   - Primary Reference:
     [Open-Meteo Historical Weather API Documentation](https://open-meteo.com/en/docs/historical-weather-api).
   - In the official documentation's historical model availability matrix:
     - `models=era5` lists reference evapotranspiration
       (`et0_fao_evapotranspiration`) and precipitation (`precipitation_sum`) as
       available.
     - `models=era5_seamless` is documented as providing seamless
       forecast/reanalysis blending.
     - `models=era5_land` explicitly lists reference evapotranspiration ($ET_0$)
       as available.
     - `models=era5_land` does **not** list precipitation (`precipitation_sum`)
       as an available variable in the relevant compatibility table.
     - Default configuration (no `models` parameter specified) is documented by
       the provider as a Best Match dataset combining multiple models
       seamlessly (such as ECMWF IFS, ERA5, and national weather services),
       rather than a single fixed standalone dataset.

2. **Empirical Project Observations:**
   - **Kafr El-Sheikh, Nile Delta (5 requested days):**
     - Target: Lat 31.10°N, Lon 30.95°E (returned cell: 31.1°N, 31.0°E, 6.0m
       elevation).
     - Period: 2024-06-01 to 2024-06-05.
     - Result: Returned HTTP 200 OK. $T_{2m,\max}$ and $T_{2m,\min}$ were fully
       populated with finite numbers. However, both the
       `et0_fao_evapotranspiration` and `precipitation_sum` daily arrays
       contained exclusively `null` values (5 nulls / 5 requested days for each
       array).
   - **Cairo (3 requested days):**
     - Target: Lat 30.04°N, Lon 31.23°E (returned cell: 30.0°N, 31.2°E).
     - Period: 2024-07-01 to 2024-07-03.
     - Result: Returned HTTP 200 OK. $T_{2m,\max}$ and $T_{2m,\min}$ were
       populated with valid numbers (`[37.9, 37.4, 38.1]` and
       `[23.1, 21.0, 20.3]`). However, both `et0_fao_evapotranspiration` and
       `precipitation_sum` daily arrays again contained 100% `null` values (3
       nulls / 3 days).

3. **Interpretation and Unresolved Scientific Questions:**
   - For both recorded ERA5-Land requests, the reported HTTP status was 200,
     temperature arrays contained numeric values, and $ET_0$ and precipitation
     arrays contained null values.
   - The available evidence does not establish why $ET_0$ returned null in
     these ERA5-Land responses despite being listed as available in the official
     compatibility table. These observations reflect the specific saved requests
     and date ranges and must not be generalized to all locations, dates, or
     ERA5-Land requests.
   - For precipitation under ERA5-Land, the observed null values are consistent
     with the official compatibility table, which does not list precipitation
     as available for ERA5-Land.
   - In the recorded experiment, complete numeric values for the required
     variables were returned by `era5`, `era5_seamless`, and the default model
     configuration.

---

## 2. Experimental Execution and Results Summary

All four configurations were queried live on **2026-10-25T18:55:20Z** using
`scripts/validate_historical_models.ps1` with identical parameters.

| Model Configuration    | HTTP Status | Returned Grid (Lat, Lon, Elev) | $T_{2m,\max}$ Array (°C)         | $T_{2m,\min}$ Array (°C)         | $ET_{0,\text{FAO}}$ Array (mm)   | Precip Array (mm)                | Null Count | Compatibility Assessment                                                              |
| ---------------------- | ----------- | ------------------------------ | -------------------------------- | -------------------------------- | -------------------------------- | -------------------------------- | ---------- | ------------------------------------------------------------------------------------- |
| `models=era5`          | **200 OK**  | 31.0°N, 31.0°E, 6.0m           | `[37.8, 35.2, 35.4, 36.6, 37.5]` | `[20.8, 21.3, 21.5, 21.4, 22.1]` | `[7.89, 7.82, 7.76, 7.43, 7.59]` | `[0.0, 0.0, 0.0, 0.0, 0.0]`      | 0 / 20     | **PASS** — Returned numeric values for all 4 required variables in tested requests.  |
| `models=era5_seamless` | **200 OK**  | 31.1°N, 31.0°E, 6.0m           | `[38.3, 36.1, 36.0, 37.5, 38.6]` | `[20.6, 20.0, 20.4, 20.0, 21.1]` | `[7.91, 7.89, 7.90, 7.54, 7.73]` | `[0.0, 0.0, 0.0, 0.0, 0.0]`      | 0 / 20     | **PASS** — Returned numeric values for all 4 required variables in tested requests.  |
| `models=era5_land`     | **200 OK**  | 31.1°N, 31.0°E, 6.0m           | `[38.3, 36.1, 36.0, 37.5, 38.6]` | `[20.6, 20.0, 20.4, 20.0, 21.1]` | `[null, null, null, null, null]` | `[null, null, null, null, null]` | 10 / 20    | **INCOMPATIBLE** — $ET_0$ and precipitation returned null arrays in tested requests.  |
| Default (no model)     | **200 OK**  | 31.107°N, 30.998°E, 6.0m       | `[40.7, 38.0, 36.8, 38.5, 39.4]` | `[20.9, 21.1, 21.0, 20.6, 20.9]` | `[8.23, 8.20, 8.38, 7.89, 8.15]` | `[0.0, 0.0, 0.0, 0.0, 0.0]`      | 0 / 20     | **PASS** — Returned numeric values for all 4 required variables in tested requests.  |

---

## 3. Full Raw Response Fixtures

Raw JSON responses for each configuration are saved in
`docs/fixtures/historical_api/`.

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

1. **Model Selection Rationale:**
   - ERA5 was selected as the application's primary historical data source because
     it returned the required variables in the recorded tests and aligns with
     the project's preference for a consistent historical reanalysis dataset.
   - ERA5-Seamless and the default configuration also returned complete data in
     the recorded experiment. These observations do not establish that ERA5 is
     the only compatible option or that it is scientifically more accurate for
     agricultural decisions.
   - Returning numeric values for the required variables in the tested requests
     demonstrates compatibility with the application's input parser; it does
     not prove physical consistency or agricultural accuracy across all
     conditions.
   - The selected model remains centralized in
     `lib/data/datasources/remote/open_meteo_remote_data_source.dart`:
     ```dart
     static const String historicalModel = 'era5';
     ```
2. **Exclusion of `era5_land` for Operational Requirements:**
   - In the recorded tests for Egyptian coordinates, `era5_land` returned null
     values for $ET_0$ and precipitation.
   - Because AgroShift requires numeric values for all four daily variables
     ($T_{\max}$, $T_{\min}$, $ET_0$, and precipitation) to compute crop
     irrigation demands, `era5_land` did not satisfy the operational input
     requirements in the evaluated cases.
3. **Traceability and Provenance Accuracy:**
   - Provenance records `datasetName: 'ERA5 Reanalysis Archive'` and grid
     coordinates `(31.0°N, 31.0°E)`, matching the actual returned reanalysis
     grid resolution cell.
   - Requested coordinates `(31.10°N, 30.95°E)` are preserved distinctly from
     grid coordinates in all database rows and UI displays.

---

## 5. Local Reproduction Instructions

To reproduce these observations directly from PowerShell on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate_historical_models.ps1
```
