"""Reproducible offline audit and boundary investigation of June 2024 ERA5 ET0 differences.

This script operates strictly OFFLINE against preserved evidence files:
- docs/fixtures/historical_api/era5_raw.json
- PY-Audit/agroshift_era5_verification/era5_api_response.json
- PY-Audit/agroshift_era5_verification/era5_hourly_raw_2024-05-31_2024-06-06.json
- PY-Audit/agroshift_era5_verification/era5_daily_cairo_elev5.json
- PY-Audit/agroshift_era5_verification/era5_daily_gmt3_elev5.json
- PY-Audit/agroshift_era5_verification/era5_daily_gmt3_elev6.json

Temporal Semantics & Interval Attribution:
- Open-Meteo documents hourly et0_fao_evapotranspiration as a preceding-hour sum.
- Two distinct attribution conventions are evaluated:
  * Convention 1 (Timestamp Calendar-Day Grouping): Groups the 24 hourly timestamps
    labeled [00:00, 23:00] for each local calendar date. For UTC+2, local [00:00, 23:00]
    corresponds to UTC timestamps [2024-06-01T22:00, ..., 2024-06-02T21:00].
  * Convention 2 (Physical Preceding-Hour Attribution): Assigns each observation to the
    physical one-hour interval (T - 1h, T] it represents. To cover the physical calendar day
    interval [00:00, 24:00], the required hourly observations are those stamped
    [01:00, ..., 24:00 (00:00 next day)].
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from datetime import datetime, timezone, timedelta

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parents[1]
FIXTURE_PATH = REPO_ROOT / "docs" / "fixtures" / "historical_api" / "era5_raw.json"
SAVED_RESP_PATH = BASE_DIR / "era5_api_response.json"

HOURLY_RAW_PATH = BASE_DIR / "era5_hourly_raw_2024-05-31_2024-06-06.json"
RESP_CAIRO_ELEV5_PATH = BASE_DIR / "era5_daily_cairo_elev5.json"
RESP_GMT3_ELEV5_PATH = BASE_DIR / "era5_daily_gmt3_elev5.json"
RESP_GMT3_ELEV6_PATH = BASE_DIR / "era5_daily_gmt3_elev6.json"


def load_evidence_file(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Required evidence file not found: {path}")
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def run_investigation():
    executed_assertions = []

    def run_assert(condition: bool, description: str):
        if not condition:
            raise AssertionError(f"FAILED ASSERTION: {description}")
        executed_assertions.append(description)

    print("================================================================================")
    print("AGROSHIFT ERA5 TIMEZONE & INTERVAL ATTRIBUTION OFFLINE AUDIT")
    print("================================================================================\n")

    # 1. Load Preserved Evidence Files
    fixture = load_evidence_file(FIXTURE_PATH)
    saved = load_evidence_file(SAVED_RESP_PATH)
    hourly_raw = load_evidence_file(HOURLY_RAW_PATH)
    cairo_e5 = load_evidence_file(RESP_CAIRO_ELEV5_PATH)
    gmt3_e5 = load_evidence_file(RESP_GMT3_ELEV5_PATH)
    gmt3_e6 = load_evidence_file(RESP_GMT3_ELEV6_PATH)

    print("1. PRESERVED EVIDENCE FILES LOADED")
    print("--------------------------------------------------------------------------------")
    print(f"Fixture:      {FIXTURE_PATH.relative_to(REPO_ROOT)} (utc_offset={fixture.get('utc_offset_seconds')}, elev={fixture.get('elevation')}m)")
    print(f"Saved API:    {SAVED_RESP_PATH.relative_to(REPO_ROOT)} (utc_offset={saved.get('utc_offset_seconds')}, elev={saved.get('elevation')}m)")
    print(f"Hourly Raw:   {HOURLY_RAW_PATH.relative_to(REPO_ROOT)}")
    print(f"Daily Cairo:  {RESP_CAIRO_ELEV5_PATH.relative_to(REPO_ROOT)}")
    print(f"Daily GMT+3:  {RESP_GMT3_ELEV5_PATH.relative_to(REPO_ROOT)}")
    print(f"Daily GMT+3*: {RESP_GMT3_ELEV6_PATH.relative_to(REPO_ROOT)}")

    # 2. Automated Validation of Hourly Evidence Arrays
    print("\n2. AUTOMATED VALIDATION OF HOURLY EVIDENCE ARRAYS")
    print("--------------------------------------------------------------------------------")
    run_assert("hourly" in hourly_raw, "Hourly raw payload contains 'hourly' key")
    h_data = hourly_raw["hourly"]

    times = h_data.get("time", [])
    run_assert(len(times) == 168, f"Expected 168 hourly timestamps, found {len(times)}")

    for var_name in ["et0_fao_evapotranspiration", "temperature_2m", "precipitation"]:
        run_assert(var_name in h_data, f"Hourly raw payload contains array '{var_name}'")
        arr = h_data[var_name]
        run_assert(len(arr) == len(times), f"Array '{var_name}' length ({len(arr)}) matches timestamps length ({len(times)})")

    # Validate consecutive, unique hourly timestamps
    parsed_dts = []
    seen_timestamps = set()
    for t_str in times:
        run_assert(t_str not in seen_timestamps, f"Timestamp {t_str} is unique in hourly series")
        seen_timestamps.add(t_str)
        # Parse ISO string with explicit UTC awareness
        dt = datetime.fromisoformat(t_str).replace(tzinfo=timezone.utc)
        parsed_dts.append(dt)

    for i in range(len(parsed_dts) - 1):
        delta = parsed_dts[i + 1] - parsed_dts[i]
        run_assert(delta == timedelta(hours=1), f"Cadence between {times[i]} and {times[i+1]} is strictly 1 hour")

    # Reject null, non-numeric, NaN, infinite ET0 values
    et0_values = h_data["et0_fao_evapotranspiration"]
    for idx, (t_str, val) in enumerate(zip(times, et0_values)):
        run_assert(val is not None, f"ET0 at index {idx} ({t_str}) is not null")
        run_assert(isinstance(val, (int, float)) and not isinstance(val, bool), f"ET0 at index {idx} ({t_str}) is numeric")
        run_assert(math.isfinite(val), f"ET0 at index {idx} ({t_str}) is finite (not NaN or Infinite)")

    t_map = {t[:16]: v for t, v in zip(times, et0_values)}
    print(f"Validated {len(times)} consecutive, unique, finite hourly observations from {times[0]} to {times[-1]}.")

    dates = ["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"]

    # 3. Recomputed Daily Slices & Boundary Attribution
    print("\n3. RECOMPUTED DAILY SUMS UNDER BOTH TEMPORAL CONVENTIONS")
    print("--------------------------------------------------------------------------------")
    c1_sums_utc2 = {}
    c1_sums_utc3 = {}
    c2_sums_utc2 = {}
    c2_sums_utc3 = {}

    for d in dates:
        # Convention 1: Timestamp Calendar-Day Grouping [00:00 to 23:00 local]
        # In UTC:
        # UTC+2: local 00:00 is (Day-1) 22:00 UTC, local 23:00 is (Day) 21:00 UTC
        # UTC+3: local 00:00 is (Day-1) 21:00 UTC, local 23:00 is (Day) 20:00 UTC
        dt_start_c1_u2 = datetime.fromisoformat(d + "T00:00").replace(tzinfo=timezone.utc) - timedelta(hours=2)
        dt_start_c1_u3 = datetime.fromisoformat(d + "T00:00").replace(tzinfo=timezone.utc) - timedelta(hours=3)

        c1_slice_u2 = [t_map[(dt_start_c1_u2 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c1_slice_u3 = [t_map[(dt_start_c1_u3 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]

        run_assert(len(c1_slice_u2) == 24, f"Convention 1 slice for {d} (UTC+2) contains exactly 24 observations")
        run_assert(len(c1_slice_u3) == 24, f"Convention 1 slice for {d} (UTC+3) contains exactly 24 observations")

        c1_sums_utc2[d] = sum(c1_slice_u2)
        c1_sums_utc3[d] = sum(c1_slice_u3)

        # Convention 2: Physical Preceding-Hour Attribution [01:00 local to 24:00 local (00:00 next day)]
        # In UTC:
        # UTC+2: local 01:00 is (Day-1) 23:00 UTC, local 24:00 is (Day) 22:00 UTC
        # UTC+3: local 01:00 is (Day-1) 22:00 UTC, local 24:00 is (Day) 21:00 UTC
        dt_start_c2_u2 = datetime.fromisoformat(d + "T01:00").replace(tzinfo=timezone.utc) - timedelta(hours=2)
        dt_start_c2_u3 = datetime.fromisoformat(d + "T01:00").replace(tzinfo=timezone.utc) - timedelta(hours=3)

        c2_slice_u2 = [t_map[(dt_start_c2_u2 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]
        c2_slice_u3 = [t_map[(dt_start_c2_u3 + timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M")] for h in range(24)]

        run_assert(len(c2_slice_u2) == 24, f"Convention 2 slice for {d} (UTC+2) contains exactly 24 observations")
        run_assert(len(c2_slice_u3) == 24, f"Convention 2 slice for {d} (UTC+3) contains exactly 24 observations")

        c2_sums_utc2[d] = sum(c2_slice_u2)
        c2_sums_utc3[d] = sum(c2_slice_u3)

    # Check non-overlap / contiguous partitioning
    for i in range(len(dates) - 1):
        d_curr = dates[i]
        d_next = dates[i + 1]
        # End of d_curr + 1h must equal start of d_next
        dt_end_c1_u2 = datetime.fromisoformat(d_curr + "T23:00").replace(tzinfo=timezone.utc) - timedelta(hours=2)
        dt_start_next_c1_u2 = datetime.fromisoformat(d_next + "T00:00").replace(tzinfo=timezone.utc) - timedelta(hours=2)
        run_assert(dt_end_c1_u2 + timedelta(hours=1) == dt_start_next_c1_u2, f"Contiguous adjacent partitioning for {d_curr} -> {d_next}")

    print("Convention 1 (Timestamp Calendar-Day Grouping: 00:00 to 23:00 local):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C1 Diff (U3 - U2)':<18} | {'Daily API Diff (GMT+3 - Cairo)':<30}")
    print("-" * 88)
    for i, d in enumerate(dates):
        diff_c1 = c1_sums_utc3[d] - c1_sums_utc2[d]
        api_cairo_val = cairo_e5["daily"]["et0_fao_evapotranspiration"][i]
        api_gmt3_val = gmt3_e5["daily"]["et0_fao_evapotranspiration"][i]
        diff_api = api_gmt3_val - api_cairo_val
        print(f"{d:<10} | {c1_sums_utc2[d]:<12.6f} | {c1_sums_utc3[d]:<12.6f} | {diff_c1:<+18.6f} | {diff_api:<+30.2f}")

    print("\nConvention 2 (Physical Preceding-Hour Attribution: 01:00 to 00:00 next day):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C2 Diff (U3 - U2)':<18} | {'Daily API Diff (GMT+3 - Cairo)':<30}")
    print("-" * 88)
    for i, d in enumerate(dates):
        diff_c2 = c2_sums_utc3[d] - c2_sums_utc2[d]
        api_cairo_val = cairo_e5["daily"]["et0_fao_evapotranspiration"][i]
        api_gmt3_val = gmt3_e5["daily"]["et0_fao_evapotranspiration"][i]
        diff_api = api_gmt3_val - api_cairo_val
        print(f"{d:<10} | {c2_sums_utc2[d]:<12.6f} | {c2_sums_utc3[d]:<12.6f} | {diff_c2:<+18.6f} | {diff_api:<+30.2f}")

    # 4. Boundary Timestamp Observations and Differences
    print("\n4. BOUNDARY TIMESTAMPS & RECOMPUTED DIFFERENCES (JUNE 2 AND JUNE 5)")
    print("--------------------------------------------------------------------------------")
    # June 2 Boundary under Convention 1
    j2_c1_enter_ts = "2024-06-01T21:00"
    j2_c1_leave_ts = "2024-06-02T21:00"
    j2_c1_enter_val = t_map[j2_c1_enter_ts]
    j2_c1_leave_val = t_map[j2_c1_leave_ts]
    j2_c1_boundary_diff = j2_c1_enter_val - j2_c1_leave_val

    # Verify that the slice sum difference equals the boundary difference
    run_assert(
        math.isclose(c1_sums_utc3["2024-06-02"] - c1_sums_utc2["2024-06-02"], j2_c1_boundary_diff, abs_tol=1e-9),
        "June 2 Convention 1 sum difference matches entering - leaving boundary difference",
    )

    print("June 2 under Convention 1:")
    print(f"  Entering observation: UTC {j2_c1_enter_ts} = {j2_c1_enter_val:.6f} mm")
    print(f"  Leaving observation:  UTC {j2_c1_leave_ts} = {j2_c1_leave_val:.6f} mm")
    print(f"  Recomputed boundary difference: {j2_c1_enter_val:.6f} - {j2_c1_leave_val:.6f} = {j2_c1_boundary_diff:+.6f} mm")

    # June 5 Boundary under Convention 1
    j5_c1_enter_ts = "2024-06-04T21:00"
    j5_c1_leave_ts = "2024-06-05T21:00"
    j5_c1_enter_val = t_map[j5_c1_enter_ts]
    j5_c1_leave_val = t_map[j5_c1_leave_ts]
    j5_c1_boundary_diff = j5_c1_enter_val - j5_c1_leave_val

    run_assert(
        math.isclose(c1_sums_utc3["2024-06-05"] - c1_sums_utc2["2024-06-05"], j5_c1_boundary_diff, abs_tol=1e-9),
        "June 5 Convention 1 sum difference matches entering - leaving boundary difference",
    )

    print("\nJune 5 under Convention 1:")
    print(f"  Entering observation: UTC {j5_c1_enter_ts} = {j5_c1_enter_val:.6f} mm")
    print(f"  Leaving observation:  UTC {j5_c1_leave_ts} = {j5_c1_leave_val:.6f} mm")
    print(f"  Recomputed boundary difference: {j5_c1_enter_val:.6f} - {j5_c1_leave_val:.6f} = {j5_c1_boundary_diff:+.6f} mm")

    # 5. Controlled Daily API Comparison Across Three Configurations
    print("\n5. CONTROLLED DAILY API RESPONSES COMPARISON")
    print("--------------------------------------------------------------------------------")
    d_cairo_e5 = cairo_e5["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e5 = gmt3_e5["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e6 = gmt3_e6["daily"]["et0_fao_evapotranspiration"]
    d_fixture = fixture["daily"]["et0_fao_evapotranspiration"]

    run_assert(len(d_cairo_e5) == 5, "Config 1 daily ET0 has 5 values")
    run_assert(len(d_gmt3_e5) == 5, "Config 2 daily ET0 has 5 values")
    run_assert(len(d_gmt3_e6) == 5, "Config 3 daily ET0 has 5 values")
    run_assert(len(d_fixture) == 5, "Fixture daily ET0 has 5 values")

    print(f"{'Date':<10} | {'Config 1 (Cairo, 5m)':<20} | {'Config 2 (GMT+3, 5m)':<20} | {'Config 3 (GMT+3, 6m)':<20} | {'Fixture (GMT+3, 6m)':<20}")
    print("-" * 100)
    for i, d in enumerate(dates):
        print(f"{d:<10} | {d_cairo_e5[i]:<20.2f} | {d_gmt3_e5[i]:<20.2f} | {d_gmt3_e6[i]:<20.2f} | {d_fixture[i]:<20.2f}")

    # Differences
    diff_tz_e5 = [round(b - a, 4) for a, b in zip(d_cairo_e5, d_gmt3_e5)]
    diff_elev_gmt3 = [round(b - a, 4) for a, b in zip(d_gmt3_e5, d_gmt3_e6)]
    diff_cfg3_fixture = [round(b - a, 4) for a, b in zip(d_gmt3_e6, d_fixture)]

    print("\nObserved Differences:")
    print(f"  Timezone difference (Config 2 - Config 1, elevation held at 5.0m): {diff_tz_e5}")
    print(f"  Elevation difference (Config 3 - Config 2, timezone held at GMT+3): {diff_elev_gmt3}")
    print(f"  Config 3 vs Fixture difference: {diff_cfg3_fixture}")

    run_assert(diff_tz_e5 == [0.0, 0.07, 0.0, 0.0, 0.0], "Timezone shift alters exactly June 2 by +0.07 mm")
    run_assert(diff_elev_gmt3 == [0.0, 0.0, 0.0, 0.0, -0.01], "Elevation shift alters exactly June 5 by -0.01 mm")
    run_assert(diff_cfg3_fixture == [0.0, 0.0, 0.0, 0.0, 0.0], "Config 3 matches historical fixture bit-for-bit across all 5 dates")

    # 6. Hourly Sum vs Daily API Residuals & Precision Limitations
    print("\n6. HOURLY-SUM-VERSUS-DAILY RESIDUALS & PRECISION LIMITATION")
    print("--------------------------------------------------------------------------------")
    print(f"{'Date':<10} | {'C1 UTC+2 Sum':<14} | {'Cairo API':<12} | {'Residual (C1 - API)':<20} | {'C1 UTC+3 Sum':<14} | {'GMT+3 API':<12} | {'Residual (C1 - API)':<20}")
    print("-" * 105)
    for i, d in enumerate(dates):
        res_u2 = c1_sums_utc2[d] - d_cairo_e5[i]
        res_u3 = c1_sums_utc3[d] - d_gmt3_e5[i]
        print(f"{d:<10} | {c1_sums_utc2[d]:<14.6f} | {d_cairo_e5[i]:<12.2f} | {res_u2:<+20.6f} | {c1_sums_utc3[d]:<14.6f} | {d_gmt3_e5[i]:<12.2f} | {res_u3:<+20.6f}")

    print("\nExecuted Assertions Summary:")
    for idx, desc in enumerate(executed_assertions, 1):
        print(f"  {idx}. [PASS] {desc}")

    print(f"\nTotal Assertions Passed: {len(executed_assertions)} / {len(executed_assertions)}")
    print("Status: SUCCESS (Offline verification completed with zero errors)")


if __name__ == "__main__":
    run_investigation()
