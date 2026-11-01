"""Reproducible audit and boundary investigation of June 2024 ERA5 ET0 differences.

Investigates:
1. Hourly UTC observations and their mapping to local calendar days under UTC+2 and UTC+3.
2. Boundary contributions entering and leaving local days (June 2 and June 5).
3. Sum of hourly values vs Open-Meteo reported daily values.
4. Elevation sensitivity (5.0m vs 6.0m) and its effect across the June 2024 period.
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

# Paths for saving raw evidence
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

    # Validate returned structure
    if "hourly" not in data or "time" not in data["hourly"] or "et0_fao_evapotranspiration" not in data["hourly"]:
        raise ValueError("Hourly response missing required 'hourly' keys")
    times = data["hourly"]["time"]
    et0_series = data["hourly"]["et0_fao_evapotranspiration"]
    if len(times) != len(et0_series) or len(times) == 0:
        raise ValueError(f"Hourly series length mismatch: time={len(times)}, et0={len(et0_series)}")

    # Check for missing / non-finite values
    for idx, (t, val) in enumerate(zip(times, et0_series)):
        if val is None or not isinstance(val, (int, float)):
            raise ValueError(f"Missing or non-numeric hourly ET0 observation at index {idx} ({t}): {val}")

    # Save exact raw JSON
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
    print("AGROSHIFT ERA5 TIMEZONE & LOCAL-DAY BOUNDARY INVESTIGATION (JUNE 2024)")
    print("================================================================================\n")

    fixture, saved = load_local_files()

    print("1. LOCAL FILES METADATA & JUNE 2 / JUNE 5 DAILY VALUES")
    print("--------------------------------------------------------------------------------")
    print(f"Fixture:      {FIXTURE_PATH.relative_to(REPO_ROOT)}")
    print(f"  utc_offset_seconds: {fixture.get('utc_offset_seconds')} ({fixture.get('timezone_abbreviation')})")
    print(f"  elevation:          {fixture.get('elevation')} m")
    print(f"  ET0 series:         {fixture['daily']['et0_fao_evapotranspiration']}")
    print(f"Saved Resp:   {SAVED_RESP_PATH.relative_to(REPO_ROOT)}")
    print(f"  utc_offset_seconds: {saved.get('utc_offset_seconds')} ({saved.get('timezone_abbreviation')})")
    print(f"  elevation:          {saved.get('elevation')} m")
    print(f"  ET0 series:         {saved['daily']['et0_fao_evapotranspiration']}")

    print("\n2. HOURLY UTC EVIDENCE INGESTION & VALIDATION")
    print("--------------------------------------------------------------------------------")
    hourly_utc_data, hourly_params = fetch_and_save_hourly_utc()
    print(f"Saved raw hourly evidence to: {HOURLY_RAW_PATH.name}")
    print(f"  Request parameters: {hourly_params}")
    print(f"  Response utc_offset_seconds: {hourly_utc_data.get('utc_offset_seconds')} ({hourly_utc_data.get('timezone_abbreviation')})")

    t_utc = hourly_utc_data["hourly"]["time"]
    e_utc = hourly_utc_data["hourly"]["et0_fao_evapotranspiration"]
    print(f"  Validated observations count: {len(t_utc)} hourly records from {t_utc[0]} to {t_utc[-1]}")

    t_map = {t[:16]: e for t, e in zip(t_utc, e_utc)}

    dates = ["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"]

    print("\n3. RECOMPUTED DAILY TOTALS FROM HOURLY OBSERVATIONS")
    print("--------------------------------------------------------------------------------")
    print(f"{'Date':<10} | {'UTC+2 Hours':<11} | {'UTC+2 Sum':<11} | {'UTC+3 Hours':<11} | {'UTC+3 Sum':<11} | {'Sum Diff':<10} | {'Fixture - Saved':<16}")
    print("-" * 95)
    hourly_sums_utc2 = {}
    hourly_sums_utc3 = {}

    for d in dates:
        dt_start_utc2 = datetime.fromisoformat(d + "T00:00") - timedelta(hours=2)
        dt_end_utc2 = datetime.fromisoformat(d + "T23:00") - timedelta(hours=2)
        dt_start_utc3 = datetime.fromisoformat(d + "T00:00") - timedelta(hours=3)
        dt_end_utc3 = datetime.fromisoformat(d + "T23:00") - timedelta(hours=3)

        hours_utc2 = []
        curr = dt_start_utc2
        while curr <= dt_end_utc2:
            key = curr.strftime("%Y-%m-%dT%H:%M")
            if key not in t_map:
                raise KeyError(f"Missing expected UTC observation key {key} for date {d} (UTC+2)")
            hours_utc2.append(t_map[key])
            curr += timedelta(hours=1)

        hours_utc3 = []
        curr = dt_start_utc3
        while curr <= dt_end_utc3:
            key = curr.strftime("%Y-%m-%dT%H:%M")
            if key not in t_map:
                raise KeyError(f"Missing expected UTC observation key {key} for date {d} (UTC+3)")
            hours_utc3.append(t_map[key])
            curr += timedelta(hours=1)

        if len(hours_utc2) != 24 or len(hours_utc3) != 24:
            raise ValueError(f"Incomplete 24-hour interval for date {d}: UTC+2={len(hours_utc2)}, UTC+3={len(hours_utc3)}")

        s_utc2 = sum(hours_utc2)
        s_utc3 = sum(hours_utc3)
        hourly_sums_utc2[d] = s_utc2
        hourly_sums_utc3[d] = s_utc3
        diff_s = s_utc3 - s_utc2

        f_d = fixture["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        s_d = saved["daily"]["et0_fao_evapotranspiration"][dates.index(d)]
        diff_api = f_d - s_d

        print(f"{d:<10} | {len(hours_utc2):<11} | {s_utc2:<11.6f} | {len(hours_utc3):<11} | {s_utc3:<11.6f} | {diff_s:<+10.6f} | {diff_api:<+16.2f}")

    print("\n4. DETAILED BOUNDARY OBSERVATIONS FOR JUNE 2 AND JUNE 5")
    print("--------------------------------------------------------------------------------")
    # June 2 Boundary
    entering_j2_key = "2024-06-01T21:00"
    leaving_j2_key = "2024-06-02T21:00"
    entering_j2_val = t_map[entering_j2_key]
    leaving_j2_val = t_map[leaving_j2_key]
    net_boundary_j2 = entering_j2_val - leaving_j2_val

    print("June 2 Boundary Observations:")
    print(f"  Entering hour: UTC {entering_j2_key} (Local UTC+2: 2024-06-01 23:00 [Day 1] -> Local UTC+3: 2024-06-02 00:00 [Day 2])")
    print(f"    Value: {entering_j2_val:.6f} mm")
    print(f"  Leaving hour:  UTC {leaving_j2_key} (Local UTC+2: 2024-06-02 23:00 [Day 2] -> Local UTC+3: 2024-06-03 00:00 [Day 3])")
    print(f"    Value: {leaving_j2_val:.6f} mm")
    print(f"  Calculated net boundary contribution: {entering_j2_val:.6f} - {leaving_j2_val:.6f} = {net_boundary_j2:+.6f} mm")
    print(f"  Recomputed June 2 total under UTC+2: {hourly_sums_utc2['2024-06-02']:.6f} mm")
    print(f"  Recomputed June 2 total under UTC+3: {hourly_sums_utc3['2024-06-02']:.6f} mm")
    print(f"  Exact difference in recomputed totals: {hourly_sums_utc3['2024-06-02'] - hourly_sums_utc2['2024-06-02']:+.6f} mm")

    # June 5 Boundary
    entering_j5_key = "2024-06-04T21:00"
    leaving_j5_key = "2024-06-05T21:00"
    entering_j5_val = t_map[entering_j5_key]
    leaving_j5_val = t_map[leaving_j5_key]
    net_boundary_j5 = entering_j5_val - leaving_j5_val

    print("\nJune 5 Boundary Observations:")
    print(f"  Entering hour: UTC {entering_j5_key} (Local UTC+2: 2024-06-04 23:00 [Day 4] -> Local UTC+3: 2024-06-05 00:00 [Day 5])")
    print(f"    Value: {entering_j5_val:.6f} mm")
    print(f"  Leaving hour:  UTC {leaving_j5_key} (Local UTC+2: 2024-06-05 23:00 [Day 5] -> Local UTC+3: 2024-06-06 00:00 [Day 6])")
    print(f"    Value: {leaving_j5_val:.6f} mm")
    print(f"  Calculated net boundary contribution: {entering_j5_val:.6f} - {leaving_j5_val:.6f} = {net_boundary_j5:+.6f} mm")
    print(f"  Recomputed June 5 total under UTC+2: {hourly_sums_utc2['2024-06-05']:.6f} mm")
    print(f"  Recomputed June 5 total under UTC+3: {hourly_sums_utc3['2024-06-05']:.6f} mm")
    print(f"  Exact difference in recomputed totals: {hourly_sums_utc3['2024-06-05'] - hourly_sums_utc2['2024-06-05']:+.6f} mm")

    print("\n5. CONTROLLED DAILY API COMPARISON (THREE CONFIGURATIONS)")
    print("--------------------------------------------------------------------------------")
    cairo_e5_data, cairo_e5_params = fetch_and_save_daily_config("Africa/Cairo", 5.0, RESP_CAIRO_ELEV5_PATH)
    gmt3_e5_data, gmt3_e5_params = fetch_and_save_daily_config("GMT+3", 5.0, RESP_GMT3_ELEV5_PATH)
    gmt3_e6_data, gmt3_e6_params = fetch_and_save_daily_config("GMT+3", 6.0, RESP_GMT3_ELEV6_PATH)

    print(f"Config 1 (Africa/Cairo, elev=5.0m): saved to {RESP_CAIRO_ELEV5_PATH.name}")
    print(f"  utc_offset_seconds: {cairo_e5_data.get('utc_offset_seconds')}, elevation: {cairo_e5_data.get('elevation')}m")
    print(f"Config 2 (GMT+3,        elev=5.0m): saved to {RESP_GMT3_ELEV5_PATH.name}")
    print(f"  utc_offset_seconds: {gmt3_e5_data.get('utc_offset_seconds')}, elevation: {gmt3_e5_data.get('elevation')}m")
    print(f"Config 3 (GMT+3,        elev=6.0m): saved to {RESP_GMT3_ELEV6_PATH.name}")
    print(f"  utc_offset_seconds: {gmt3_e6_data.get('utc_offset_seconds')}, elevation: {gmt3_e6_data.get('elevation')}m")

    cairo_e5_daily = cairo_e5_data["daily"]["et0_fao_evapotranspiration"]
    gmt3_e5_daily = gmt3_e5_data["daily"]["et0_fao_evapotranspiration"]
    gmt3_e6_daily = gmt3_e6_data["daily"]["et0_fao_evapotranspiration"]
    fixture_daily = fixture["daily"]["et0_fao_evapotranspiration"]

    print("\nDaily ET0 Values Comparison:")
    print(f"{'Date':<10} | {'Config 1 (Cairo, 5m)':<20} | {'Config 2 (GMT+3, 5m)':<20} | {'Config 3 (GMT+3, 6m)':<20} | {'Fixture (GMT+3, 6m)':<20}")
    print("-" * 100)
    for i, d in enumerate(dates):
        print(f"{d:<10} | {cairo_e5_daily[i]:<20.2f} | {gmt3_e5_daily[i]:<20.2f} | {gmt3_e6_daily[i]:<20.2f} | {fixture_daily[i]:<20.2f}")

    # Verify series comparisons mathematically
    cairo_vs_gmt3_e5_diffs = [round(b - a, 4) for a, b in zip(cairo_e5_daily, gmt3_e5_daily)]
    gmt3_e5_vs_e6_diffs = [round(b - a, 4) for a, b in zip(gmt3_e5_daily, gmt3_e6_daily)]
    gmt3_e6_vs_fixture_diffs = [round(b - a, 4) for a, b in zip(gmt3_e6_daily, fixture_daily)]

    print("\nCalculated Series Differences:")
    print(f"  Timezone effect (Config 2 - Config 1, elevation held at 5.0m): {cairo_vs_gmt3_e5_diffs}")
    print(f"  Elevation effect (Config 3 - Config 2, timezone held at GMT+3): {gmt3_e5_vs_e6_diffs}")
    print(f"  Config 3 vs Fixture diffs: {gmt3_e6_vs_fixture_diffs}")

    full_identity_with_fixture = (gmt3_e6_daily == fixture_daily)
    print(f"\n  Does Config 3 match Fixture with bit-for-bit identity across all 5 days? {full_identity_with_fixture}")

    print("\n6. RECONCILIATION OF RECOMPUTED HOURLY SUMS VS REPORTED DAILY API VALUES")
    print("--------------------------------------------------------------------------------")
    print(f"{'Date':<10} | {'UTC+2 Local Sum':<16} | {'Config 1 Daily API':<18} | {'Local - Daily API':<17} | {'UTC+3 Local Sum':<16} | {'Config 2 Daily API':<18} | {'Local - Daily API':<17}")
    print("-" * 110)
    for i, d in enumerate(dates):
        sum_u2 = hourly_sums_utc2[d]
        api_u2 = cairo_e5_daily[i]
        diff_u2 = sum_u2 - api_u2

        sum_u3 = hourly_sums_utc3[d]
        api_u3 = gmt3_e5_daily[i]
        diff_u3 = sum_u3 - api_u3
        print(f"{d:<10} | {sum_u2:<16.6f} | {api_u2:<18.2f} | {diff_u2:<+17.6f} | {sum_u3:<16.6f} | {api_u3:<18.2f} | {diff_u3:<+17.6f}")

    print("\n================================================================================")
    print("INVESTIGATION COMPLETE")
    print("================================================================================")


if __name__ == "__main__":
    run_investigation()
