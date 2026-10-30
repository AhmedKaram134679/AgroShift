#!/usr/bin/env python3
"""
Reproducible AgroShift ET0 cross-check:
Open-Meteo ERA5 daily ET0 versus an independent FAO-56 Penman-Monteith
calculation from daily Tmax/Tmin, mean dew point, mean 10 m wind, shortwave
radiation, and grid elevation.

Run:
    py -m pip install requests
    py .\agroshift_et0_independent_check.py

Outputs:
    agroshift_et0_validation/daily_comparison.csv
    agroshift_et0_validation/summary.json

Important:
- The independent calculation uses daily aggregates, so it is a methodological
  cross-check, not a promise of bit-for-bit agreement with Open-Meteo's ET0.
- No app source files are modified.
"""

from __future__ import annotations

import csv
import json
import math
import time
from datetime import date, timedelta
from pathlib import Path
from typing import Any

import requests

START = date(2025, 1, 1)
END = date(2025, 12, 31)
TIMEZONE = "Africa/Cairo"
MODEL = "era5"
OUT = Path("agroshift_et0_validation")
API_URL = "https://archive-api.open-meteo.com/v1/archive"

SITES = {
    "minya": (28.11, 30.75),
    "kafr_el_sheikh": (31.11, 30.94),
}

DAILY_VARIABLES = [
    "temperature_2m_max",
    "temperature_2m_min",
    "dew_point_2m_mean",
    "wind_speed_10m_mean",
    "shortwave_radiation_sum",
    "et0_fao_evapotranspiration",
    "precipitation_sum",
]

EXPECTED_UNITS = {
    "temperature_2m_max": "°C",
    "temperature_2m_min": "°C",
    "dew_point_2m_mean": "°C",
    "wind_speed_10m_mean": "m/s",
    "shortwave_radiation_sum": "MJ/m²",
    "et0_fao_evapotranspiration": "mm",
    "precipitation_sum": "mm",
}


def fetch_json(params: dict[str, Any], attempts: int = 3) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            response = requests.get(API_URL, params=params, timeout=90)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict) or payload.get("error"):
                raise ValueError(payload.get("reason", "Unexpected API response"))
            return payload
        except Exception as exc:
            last_error = exc
            if attempt + 1 < attempts:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Open-Meteo request failed after {attempts} attempts: {last_error}")


def finite_number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def saturation_vapour_pressure(temp_c: float) -> float:
    return 0.6108 * math.exp((17.27 * temp_c) / (temp_c + 237.3))


def extraterrestrial_radiation(latitude_deg: float, day_of_year: int) -> float:
    """FAO-56 Ra in MJ m-2 day-1."""
    phi = math.radians(latitude_deg)
    dr = 1.0 + 0.033 * math.cos(2.0 * math.pi * day_of_year / 365.0)
    solar_declination = 0.409 * math.sin(2.0 * math.pi * day_of_year / 365.0 - 1.39)
    argument = -math.tan(phi) * math.tan(solar_declination)
    sunset_angle = math.acos(max(-1.0, min(1.0, argument)))
    gsc = 0.0820
    return (24.0 * 60.0 / math.pi) * gsc * dr * (
        sunset_angle * math.sin(phi) * math.sin(solar_declination)
        + math.cos(phi) * math.cos(solar_declination) * math.sin(sunset_angle)
    )


def fao56_daily_et0(
    day: date,
    latitude_deg: float,
    elevation_m: float,
    tmax: float,
    tmin: float,
    dewpoint_mean: float,
    wind10_m_s: float,
    solar_radiation_mj_m2: float,
) -> float:
    """Daily FAO-56 Penman-Monteith estimate using documented daily inputs."""
    if tmax < tmin:
        raise ValueError(f"{day}: Tmax is below Tmin")
    tmean = (tmax + tmin) / 2.0
    delta = 4098.0 * saturation_vapour_pressure(tmean) / ((tmean + 237.3) ** 2)

    # FAO-56 atmospheric pressure and psychrometric constant.
    pressure_kpa = 101.3 * (((293.0 - 0.0065 * elevation_m) / 293.0) ** 5.26)
    gamma = 0.000665 * pressure_kpa

    # Dew point is used to estimate actual vapour pressure.
    actual_vapour_pressure = saturation_vapour_pressure(dewpoint_mean)
    es = (
        saturation_vapour_pressure(tmax) + saturation_vapour_pressure(tmin)
    ) / 2.0
    vapour_pressure_deficit = max(0.0, es - actual_vapour_pressure)

    # Open-Meteo reports wind at 10 m; FAO-56 requires 2 m.
    wind2 = max(0.0, wind10_m_s) * 4.87 / math.log(67.8 * 10.0 - 5.42)

    ra = extraterrestrial_radiation(latitude_deg, day.timetuple().tm_yday)
    rso = (0.75 + 2e-5 * elevation_m) * ra
    rs = max(0.0, solar_radiation_mj_m2)
    if rso <= 0.0:
        ratio = 0.3
    else:
        ratio = min(1.0, max(0.3, rs / rso))

    # FAO-56 daily grass-reference radiation balance.
    rns = (1.0 - 0.23) * rs
    tmax_k = tmax + 273.16
    tmin_k = tmin + 273.16
    rnl = (
        4.903e-9
        * ((tmax_k**4 + tmin_k**4) / 2.0)
        * (0.34 - 0.14 * math.sqrt(max(0.0, actual_vapour_pressure)))
        * (1.35 * ratio - 0.35)
    )
    rn = rns - rnl
    soil_heat_flux = 0.0

    numerator = (
        0.408 * delta * (rn - soil_heat_flux)
        + gamma * (900.0 / (tmean + 273.0)) * wind2 * vapour_pressure_deficit
    )
    denominator = delta + gamma * (1.0 + 0.34 * wind2)
    return max(0.0, numerator / denominator)


def metrics(values: list[tuple[float, float]]) -> dict[str, float | int | None]:
    """Calculate summary diagnostic metrics comparing independent daily FAO-56 to API ET0.
    
    Mean absolute relative difference is computed as:
        mean(|independent - api| / api * 100)
    where the API reference ET0 serves as the denominator. Denominators that are
    zero, negative, or non-finite are guarded against and excluded explicitly to
    prevent division-by-zero or undefined arithmetic.

    All input observation pairs must contain finite numeric values. Any non-finite value
    (NaN, positive infinity, negative infinity) or non-numeric value (including booleans)
    raises a ValueError to prevent silent contamination of summary diagnostic metrics.
    """
    if not values:
        return {
            "paired_days": 0,
            "mean_api_et0_mm_day": None,
            "mean_independent_et0_mm_day": None,
            "mae_mm_day": None,
            "bias_independent_minus_api_mm_day": None,
            "rmse_mm_day": None,
            "mean_absolute_relative_difference_percent": None,
        }

    for independent, api in values:
        if isinstance(independent, bool) or not (isinstance(independent, (int, float)) and math.isfinite(independent)):
            raise ValueError(f"Non-finite or non-numeric independent ET0 value encountered: {independent!r}")
        if isinstance(api, bool) or not (isinstance(api, (int, float)) and math.isfinite(api)):
            raise ValueError(f"Non-finite or non-numeric API ET0 value encountered: {api!r}")

    differences = [independent - api for independent, api in values]
    api_values = [api for _, api in values]
    independent_values = [independent for independent, _ in values]

    # Explicitly guard denominator (must be finite and > 0.0)
    valid_rel_diffs = [
        abs(independent - api) / api * 100.0
        for independent, api in values
        if api > 0.0
    ]
    mean_rel_diff = (
        sum(valid_rel_diffs) / len(valid_rel_diffs)
        if valid_rel_diffs
        else None
    )

    return {
        "paired_days": len(values),
        "mean_api_et0_mm_day": sum(api_values) / len(api_values),
        "mean_independent_et0_mm_day": sum(independent_values) / len(independent_values),
        "mae_mm_day": sum(abs(x) for x in differences) / len(differences),
        "bias_independent_minus_api_mm_day": sum(differences) / len(differences),
        "rmse_mm_day": math.sqrt(sum(x * x for x in differences) / len(differences)),
        "mean_absolute_relative_difference_percent": mean_rel_diff,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []
    site_summaries: dict[str, Any] = {}

    expected_dates = [
        START + timedelta(days=i) for i in range((END - START).days + 1)
    ]

    for site, (latitude, longitude) in SITES.items():
        print(f"Fetching {site} ({latitude}, {longitude}) ...")
        payload = fetch_json({
            "latitude": latitude,
            "longitude": longitude,
            "start_date": START.isoformat(),
            "end_date": END.isoformat(),
            "daily": ",".join(DAILY_VARIABLES),
            "timezone": TIMEZONE,
            "models": MODEL,
            "wind_speed_unit": "ms",
        })

        daily = payload.get("daily")
        units = payload.get("daily_units")
        if not isinstance(daily, dict) or not isinstance(units, dict):
            raise ValueError(f"{site}: response is missing daily or daily_units objects")

        unit_errors = {
            variable: {"expected": expected, "actual": units.get(variable)}
            for variable, expected in EXPECTED_UNITS.items()
            if units.get(variable) != expected
        }
        if unit_errors:
            raise ValueError(f"{site}: unexpected API units: {json.dumps(unit_errors, ensure_ascii=False)}")

        api_dates = daily.get("time")
        if not isinstance(api_dates, list):
            raise ValueError(f"{site}: daily.time is missing or not a list")
        if [str(x) for x in api_dates] != [d.isoformat() for d in expected_dates]:
            raise ValueError(f"{site}: returned dates are not the exact requested continuous period")

        for variable in DAILY_VARIABLES:
            values = daily.get(variable)
            if not isinstance(values, list) or len(values) != len(api_dates):
                raise ValueError(f"{site}: {variable} is missing or has a mismatched length")

        elevation = finite_number(payload.get("elevation"))
        if elevation is None:
            raise ValueError(f"{site}: API did not return grid elevation")

        paired: list[tuple[float, float]] = []
        missing_days = 0
        for i, day in enumerate(expected_dates):
            values = {
                key: finite_number(daily[key][i])
                for key in DAILY_VARIABLES
            }
            required = [
                values["temperature_2m_max"], values["temperature_2m_min"],
                values["dew_point_2m_mean"], values["wind_speed_10m_mean"],
                values["shortwave_radiation_sum"], values["et0_fao_evapotranspiration"],
            ]
            independent = None
            if all(value is not None for value in required):
                independent = fao56_daily_et0(
                    day=day,
                    latitude_deg=latitude,
                    elevation_m=elevation,
                    tmax=values["temperature_2m_max"],  # type: ignore[arg-type]
                    tmin=values["temperature_2m_min"],  # type: ignore[arg-type]
                    dewpoint_mean=values["dew_point_2m_mean"],  # type: ignore[arg-type]
                    wind10_m_s=values["wind_speed_10m_mean"],  # type: ignore[arg-type]
                    solar_radiation_mj_m2=values["shortwave_radiation_sum"],  # type: ignore[arg-type]
                )
                paired.append((independent, values["et0_fao_evapotranspiration"]))  # type: ignore[arg-type]
            else:
                missing_days += 1

            rows.append({
                "site": site,
                "date": day.isoformat(),
                "latitude": latitude,
                "longitude": longitude,
                "grid_elevation_m": elevation,
                **values,
                "et0_fao56_daily_derived_mm": independent,
                "independent_minus_open_meteo_mm": (
                    independent - values["et0_fao_evapotranspiration"]
                    if independent is not None and values["et0_fao_evapotranspiration"] is not None
                    else None
                ),
            })

        site_summaries[site] = {
            "coordinates": {"latitude": latitude, "longitude": longitude},
            "api_grid_elevation_m": elevation,
            "model": MODEL,
            "timezone": payload.get("timezone"),
            "period": [START.isoformat(), END.isoformat()],
            "returned_days": len(api_dates),
            "paired_days": len(paired),
            "days_with_missing_required_inputs": missing_days,
            "daily_units": units,
            "comparison": metrics(paired),
            "interpretation": (
                "Daily-aggregate FAO-56 estimate versus API ET0. Differences are expected "
                "because the independent calculation uses daily aggregates and cannot exactly "
                "reproduce an hourly model pipeline. This is a diagnostic comparison, not ground truth."
            ),
        }

    output_csv = OUT / "daily_comparison.csv"
    with output_csv.open("w", newline="", encoding="utf-8-sig") as handle:
        fieldnames = list(dict.fromkeys(key for row in rows for key in row))
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    summary = {
        "purpose": "Independent daily FAO-56 ET0 diagnostic comparison",
        "period": [START.isoformat(), END.isoformat()],
        "source": API_URL,
        "model": MODEL,
        "timezone": TIMEZONE,
        "method": "FAO-56 daily Penman-Monteith using Tmax/Tmin, mean dew point, 10m wind converted to 2m, daily shortwave radiation and grid elevation",
        "limitations": [
            "Daily aggregates can differ from an ET0 series computed from hourly inputs.",
            "Reanalysis grid data are estimates, not local station ground truth.",
            "The script validates units and date continuity before calculating comparisons.",
        ],
        "sites": site_summaries,
    }
    output_json = OUT / "summary.json"
    output_json.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSaved: {output_csv.resolve()}")
    print(f"Saved: {output_json.resolve()}")
    print(json.dumps(site_summaries, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
