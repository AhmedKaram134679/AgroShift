"""Reproducible audit and boundary investigation of June 2024 ERA5 ET0 differences.

Temporal Attribution Analysis:
- Evaluation of interval conventions:
  1. Standard API Attribution: The API returns timestamps [00:00, ..., 23:00] for each
     requested local date. When aggregated over the local day [00:00, 24:00), the 24 intervals
     stamped [00:00, 23:00] correspond directly to the API's daily aggregation window.
  2. Preceding-Hour End-Stamp Attribution: If each timestamp T is defined strictly as the
     preceding-hour sum (T-1, T], then the 24 intervals of calendar day [00:00, 24:00] would be
     stamped [01:00, 24:00] (i.e. 01:00 through 00:00 of the following day).
- Numerical validation:
  Both conventions are computed, evaluated, and tested against returned API daily observations.
"""

from __future__ import annotations

import json
from pathlib import Path
from datetime import datetime, timezone, timedelta
import requests

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parents[1]
FIXTURE_PATH = REPO_ROOT / "docs" / "fixtures" / "historical_api" / "era5_raw.json"
SAVED_RESP_PATH = BASE_DIR / "era5_api_response.json"

API_URL = "https://archive-api.open-meteo.com/v1/archive"

# Paths for saved evidence
HOURLY_RAW_PATH = BASE_DIR / "era5_hourly_raw_2024-05-31_2024-06-06.json"
RESP_CAIRO_ELEV5_PATH = BASE_DIR / "era5_daily_cairo_elev5.json"
RESP_GMT3_ELEV5_PATH = BASE_DIR / "era5_daily_gmt3_elev5.json"
RESP_GMT3_ELEV6_PATH = BASE_DIR / "era5_daily_gmt3_elev6.json"


def load_local_files():
    if not FIXTURE_PATH.exists():
        raise FileNotFoundError(f"Historical fixture not found at {FIXTURE_PATH}")
    if not SAVED_RESP_PATH.exists():
        raise FileNotFoundError(f"Saved response not found at {SAVED_RESP_PATH}")

    with open(FIXTURE_PATH, "r", encoding="utf-8-sig") as f:
        fixture = json.load(f)
    with open(SAVED_RESP_PATH, "r", encoding="utf-8-sig") as f:
        saved = json.load(f)

    return fixture, saved


def fetch_and_save_hourly_utc():
    params = {
        "latitude": 31.0,
        "longitude": 31.0,
        "start_date": "2024-05-31",
        "end_date": "2024-06-06",
        "hourly": "et0_fao_evapotranspiration,temperature_2m,precipitation",
        "timezone": "UTC",
        "models": "era5",
    }
    r = requests.get(API_URL, params=params, timeout=30)
    if r.status_code != 200:
        raise RuntimeError(f"Hourly API request failed with status {r.status_code}: {r.text}")
    data = r.json()

    # Validate structure
    if "hourly" not in data or "time" not in data["hourly"] or "et0_fao_evapotranspiration" not in data["hourly"]:
        raise ValueError("Hourly response missing required 'hourly' keys")
    times = data["hourly"]["time"]
    et0_series = data["hourly"]["et0_fao_evapotranspiration"]
    if len(times) != len(et0_series) or len(times) == 0:
        raise ValueError(f"Hourly series length mismatch: time={len(times)}, et0={len(et0_series)}")

    # Reject null, non-numeric, or non-finite values
    for idx, (t, val) in enumerate(zip(times, et0_series)):
        if val is None or not isinstance(val, (int, float)):
            raise ValueError(f"Missing or non-numeric hourly ET0 observation at index {idx} ({t}): {val}")

    # Verify timestamps are unique and consecutive hourly
    for i in range(len(times) - 1):
        dt1 = datetime.fromisoformat(times[i])
        dt2 = datetime.fromisoformat(times[i + 1])
        if dt2 - dt1 != timedelta(hours=1):
            raise ValueError(f"Hourly cadence break between {times[i]} and {times[i+1]}")

    with open(HOURLY_RAW_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    return data, params


def fetch_and_save_daily_config(timezone_str: str, elevation_val: float, output_path: Path):
    params = {
        "latitude": 31.0,
        "longitude": 31.0,
        "start_date": "2024-06-01",
        "end_date": "2024-06-05",
        "daily": "et0_fao_evapotranspiration",
        "timezone": timezone_str,
        "models": "era5",
        "elevation": elevation_val,
    }
    r = requests.get(API_URL, params=params, timeout=30)
    if r.status_code != 200:
        raise RuntimeError(f"Daily API request ({timezone_str}, elev={elevation_val}) failed: {r.status_code}: {r.text}")
    data = r.json()

    if "daily" not in data or "et0_fao_evapotranspiration" not in data["daily"]:
        raise ValueError(f"Daily response missing 'daily.et0_fao_evapotranspiration' for {timezone_str}")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    return data, params


def run_investigation():
    print("================================================================================")
    print("AGROSHIFT ERA5 TIMEZONE & INTERVAL ATTRIBUTION INVESTIGATION (JUNE 2024)")
    print("================================================================================\n")

    fixture, saved = load_local_files()

    print("1. LOCAL FILES BASELINE")
    print("--------------------------------------------------------------------------------")
    print(f"Fixture:      {FIXTURE_PATH.relative_to(REPO_ROOT)}")
    print(f"  utc_offset_seconds: {fixture.get('utc_offset_seconds')} ({fixture.get('timezone_abbreviation')})")
    print(f"  elevation:          {fixture.get('elevation')} m")
    print(f"  ET0 series:         {fixture['daily']['et0_fao_evapotranspiration']}")
    print(f"Saved Resp:   {SAVED_RESP_PATH.relative_to(REPO_ROOT)}")
    print(f"  utc_offset_seconds: {saved.get('utc_offset_seconds')} ({saved.get('timezone_abbreviation')})")
    print(f"  elevation:          {saved.get('elevation')} m")
    print(f"  ET0 series:         {saved['daily']['et0_fao_evapotranspiration']}")

    print("\n2. HOURLY UTC EVIDENCE INGESTION & TEMPORAL ATTRIBUTION VALIDATION")
    print("--------------------------------------------------------------------------------")
    hourly_utc_data, hourly_params = fetch_and_save_hourly_utc()
    t_utc = hourly_utc_data["hourly"]["time"]
    e_utc = hourly_utc_data["hourly"]["et0_fao_evapotranspiration"]
    print(f"Saved raw hourly evidence to: {HOURLY_RAW_PATH.name}")
    print(f"  Validated observations count: {len(t_utc)} hourly records from {t_utc[0]} to {t_utc[-1]}")

    t_map = {t[:16]: e for t, e in zip(t_utc, e_utc)}

    dates = ["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"]

    print("\n3. RECOMPUTED DAILY TOTALS UNDER BOTH INTERVAL CONVENTIONS")
    print("--------------------------------------------------------------------------------")
    # Convention 1: API Standard Local Interval [00:00 local to 23:00 local]
    # For UTC+2: Local 00:00 to 23:00 -> UTC (Day-1) 22:00 to (Day) 21:00
    # For UTC+3: Local 00:00 to 23:00 -> UTC (Day-1) 21:00 to (Day) 20:00
    #
    # Convention 2: Preceding-Hour End-Stamp Attribution [01:00 local to 24:00 local (00:00 next day)]
    # For UTC+2: Local 01:00 to 24:00 -> UTC (Day-1) 23:00 to (Day) 22:00
    # For UTC+3: Local 01:00 to 24:00 -> UTC (Day-1) 22:00 to (Day) 21:00

    c1_sums_utc2 = {}
    c1_sums_utc3 = {}
    c2_sums_utc2 = {}
    c2_sums_utc3 = {}

    for d in dates:
        # Convention 1
        dt_start_c1_u2 = datetime.fromisoformat(d + "T00:00") - timedelta(hours=2)
        dt_start_c1_u3 = datetime.fromisoformat(d + "T00:00") - timedelta(hours=3)

        c1_u2 = [t_map[(dt_start_c1_u2 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c1_u3 = [t_map[(dt_start_c1_u3 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c1_sums_utc2[d] = sum(c1_u2)
        c1_sums_utc3[d] = sum(c1_u3)

        # Convention 2
        dt_start_c2_u2 = datetime.fromisoformat(d + "T01:00") - timedelta(hours=2)
        dt_start_c2_u3 = datetime.fromisoformat(d + "T01:00") - timedelta(hours=3)

        c2_u2 = [t_map[(dt_start_c2_u2 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c2_u3 = [t_map[(dt_start_c2_u3 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c2_sums_utc2[d] = sum(c2_u2)
        c2_sums_utc3[d] = sum(c2_u3)

    print("Convention 1 (Standard API Local Calendar Day: 00:00 to 23:00):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C1 Diff (U3 - U2)':<18} | {'Saved API Diff (F - S)':<22}")
    print("-" * 80)
    for d in dates:
        diff_c1 = c1_sums_utc3[d] - c1_sums_utc2[d]
        f_val = fixture["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        s_val = saved["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        print(f"{d:<10} | {c1_sums_utc2[d]:<12.6f} | {c1_sums_utc3[d]:<12.6f} | {diff_c1:<+18.6f} | {f_val - s_val:<+22.2f}")

    print("\nConvention 2 (Preceding-Hour End-Stamp: 01:00 to 00:00 next day):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C2 Diff (U3 - U2)':<18} | {'Saved API Diff (F - S)':<22}")
    print("-" * 80)
    for d in dates:
        diff_c2 = c2_sums_utc3[d] - c2_sums_utc2[d]
        f_val = fixture["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        s_val = saved["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        print(f"{d:<10} | {c2_sums_utc2[d]:<12.6f} | {c2_sums_utc3[d]:<12.6f} | {diff_c2:<+18.6f} | {f_val - s_val:<+22.2f}")

    print("\n4. JUNE 2 AND JUNE 5 BOUNDARY CONTRIBUTIONS")
    print("--------------------------------------------------------------------------------")
    print("Under Convention 1 (Standard API Day: 00:00 to 23:00):")
    print(f"  June 2 Entering Hour (2024-06-01T21:00 UTC): {t_map['2024-06-01T21:00']:.6f} mm")
    print(f"  June 2 Leaving Hour  (2024-06-02T21:00 UTC): {t_map['2024-06-02T21:00']:.6f} mm")
    print(f"  June 2 Net Boundary Shift: {t_map['2024-06-01T21:00'] - t_map['2024-06-02T21:00']:+.6f} mm")
    print(f"  June 5 Entering Hour (2024-06-04T21:00 UTC): {t_map['2024-06-04T21:00']:.6f} mm")
    print(f"  June 5 Leaving Hour  (2024-06-05T21:00 UTC): {t_map['2024-06-05T21:00']:.6f} mm")
    print(f"  June 5 Net Boundary Shift: {t_map['2024-06-04T21:00'] - t_map['2024-06-05T21:00']:+.6f} mm")

    print("\nUnder Convention 2 (Preceding-Hour End-Stamp: 01:00 to 00:00 next day):")
    print(f"  June 2 Entering Hour (2024-06-01T22:00 UTC): {t_map['2024-06-01T22:00']:.6f} mm")
    print(f"  June 2 Leaving Hour  (2024-06-02T22:00 UTC): {t_map['2024-06-02T22:00']:.6f} mm")
    print(f"  June 2 Net Boundary Shift: {t_map['2024-06-01T22:00'] - t_map['2024-06-02T22:00']:+.6f} mm")
    print(f"  June 5 Entering Hour (2024-06-04T22:00 UTC): {t_map['2024-06-04T22:00']:.6f} mm")
    print(f"  June 5 Leaving Hour  (2024-06-05T22:00 UTC): {t_map['2024-06-05T22:00']:.6f} mm")
    print(f"  June 5 Net Boundary Shift: {t_map['2024-06-04T22:00'] - t_map['2024-06-05T22:00']:+.6f} mm")

    print("\n5. CONTROLLED DAILY API COMPARISON")
    print("--------------------------------------------------------------------------------")
    cairo_e5_data, _ = fetch_and_save_daily_config("Africa/Cairo", 5.0, RESP_CAIRO_ELEV5_PATH)
    gmt3_e5_data, _ = fetch_and_save_daily_config("GMT+3", 5.0, RESP_GMT3_ELEV5_PATH)
    gmt3_e6_data, _ = fetch_and_save_daily_config("GMT+3", 6.0, RESP_GMT3_ELEV6_PATH)

    d_cairo_e5 = cairo_e5_data["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e5 = gmt3_e5_data["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e6 = gmt3_e6_data["daily"]["et0_fao_evapotranspiration"]
    d_fixture = fixture["daily"]["et0_fao_evapotranspiration"]

    print(f"{'Date':<10} | {'Config 1 (Cairo, 5m)':<20} | {'Config 2 (GMT+3, 5m)':<20} | {'Config 3 (GMT+3, 6m)':<20} | {'Fixture (GMT+3, 6m)':<20}")
    print("-" * 100)
    for i, d in enumerate(dates):
        print(f"{d:<10} | {d_cairo_e5[i]:<20.2f} | {d_gmt3_e5[i]:<20.2f} | {d_gmt3_e6[i]:<20.2f} | {d_fixture[i]:<20.2f}")

    print("\nEmpirical Attribution Match with Open-Meteo Daily API:")
    print("  Comparing June 2 hourly sum vs Daily API:")
    print(f"    Convention 1 (UTC+2): {c1_sums_utc2['2024-06-02']:.2f} mm vs Daily API: {d_cairo_e5[1]:.2f} mm (diff: {c1_sums_utc2['2024-06-02'] - d_cairo_e5[1]:+.2f} mm)")
    print(f"    Convention 2 (UTC+2): {c2_sums_utc2['2024-06-02']:.2f} mm vs Daily API: {d_cairo_e5[1]:.2f} mm (diff: {c2_sums_utc2['2024-06-02'] - d_cairo_e5[1]:+.2f} mm)")
    print(f"    Convention 1 (UTC+3): {c1_sums_utc3['2024-06-02']:.2f} mm vs Daily API: {d_gmt3_e5[1]:.2f} mm (diff: {c1_sums_utc3['2024-06-02'] - d_gmt3_e5[1]:+.2f} mm)")
    print(f"    Convention 2 (UTC+3): {c2_sums_utc3['2024-06-02']:.2f} mm vs Daily API: {d_gmt3_e5[1]:.2f} mm (diff: {c2_sums_utc3['2024-06-02'] - d_gmt3_e5[1]:+.2f} mm)")

    # Assertions validating data integrity
    assert len(t_utc) == 168, "Must have exactly 168 hourly observations"
    assert (d_gmt3_e6 == d_fixture), "Config 3 must match fixture exactly"
    print("\nAll programmatic assertions passed successfully.")


if __name__ == "__main__":
    run_investigation()
