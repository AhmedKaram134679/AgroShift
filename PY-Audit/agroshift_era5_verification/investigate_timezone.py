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

# Regression checks against preserved evidence (original API precision)
EXPECTED_CAIRO_E5 = [7.89, 7.75, 7.76, 7.43, 7.60]
EXPECTED_GMT3_E5 = [7.89, 7.82, 7.76, 7.43, 7.60]
EXPECTED_GMT3_E6 = [7.89, 7.82, 7.76, 7.43, 7.59]
EXPECTED_FIXTURE = [7.89, 7.82, 7.76, 7.43, 7.59]

EXPECTED_TIMEZONE_DIFFERENCE = [0.0, 0.07, 0.0, 0.0, 0.0]
EXPECTED_ELEVATION_DIFFERENCE = [0.0, 0.0, 0.0, 0.0, -0.01]
EXPECTED_CONFIG3_FIXTURE_DIFFERENCE = [0.0, 0.0, 0.0, 0.0, 0.0]

EXPECTED_BOUNDARY_VALUES = {
    "2024-06-01T21:00": 0.09,
    "2024-06-02T21:00": 0.03,
    "2024-06-01T22:00": 0.07,
    "2024-06-02T22:00": 0.02,
    "2024-06-04T21:00": 0.03,
    "2024-06-05T21:00": 0.03,
    "2024-06-04T22:00": 0.02,
    "2024-06-05T22:00": 0.02,
}

EXPECTED_C1_UTC2 = [7.90, 7.76, 7.77, 7.44, 7.59]
EXPECTED_C1_UTC3 = [7.91, 7.82, 7.77, 7.44, 7.59]
EXPECTED_C1_DIFFERENCE = [0.01, 0.06, 0.00, 0.00, 0.00]

EXPECTED_C2_UTC2 = [7.89, 7.71, 7.76, 7.45, 7.59]
EXPECTED_C2_UTC3 = [7.90, 7.76, 7.77, 7.44, 7.59]
EXPECTED_C2_DIFFERENCE = [0.01, 0.05, 0.01, -0.01, 0.00]


def is_finite_numeric(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def load_evidence_file(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Required evidence file not found: {path}")
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def expected_utc_timestamps(
    date_str: str,
    convention: int,
    utc_offset_hours: int,
) -> list[str]:
    """Generate the 24 expected UTC timestamp strings for a date, convention, and offset."""
    start_hour = 0 if convention == 1 else 1
    local_start = datetime.fromisoformat(f"{date_str}T{start_hour:02d}:00").replace(tzinfo=timezone.utc)
    utc_start = local_start - timedelta(hours=utc_offset_hours)
    return [(utc_start + timedelta(hours=i)).strftime("%Y-%m-%dT%H:%M") for i in range(24)]


def run_investigation():
    executed_assertions: list[str] = []

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

    # 2. Automated Validation of Hourly Evidence Arrays and Timestamps
    print("\n2. AUTOMATED VALIDATION OF HOURLY EVIDENCE ARRAYS AND TIMESTAMPS")
    print("--------------------------------------------------------------------------------")
    run_assert("hourly" in hourly_raw, "Hourly raw payload contains 'hourly' key")
    h_data = hourly_raw["hourly"]
    run_assert(isinstance(h_data, dict), "Hourly raw 'hourly' is a dictionary")

    times = h_data.get("time", [])
    run_assert(isinstance(times, list), "Hourly 'time' is a list")
    run_assert(len(times) == 168, f"Expected exactly 168 hourly timestamps, found {len(times)}")

    for var_name in ["et0_fao_evapotranspiration", "temperature_2m", "precipitation"]:
        run_assert(var_name in h_data, f"Hourly raw payload contains array '{var_name}'")
        arr = h_data[var_name]
        run_assert(isinstance(arr, list), f"Hourly array '{var_name}' is a list")
        run_assert(
            len(arr) == len(times),
            f"Array '{var_name}' length ({len(arr)}) matches timestamps length ({len(times)})",
        )

    # Validate timestamps: parseable, timezone normalization, uniqueness, ordering, consecutive spacing
    parsed_dts: list[datetime] = []
    seen_timestamps: set[str] = set()
    for idx, t_str in enumerate(times):
        run_assert(isinstance(t_str, str), f"Timestamp at index {idx} is a string")
        run_assert(t_str not in seen_timestamps, f"Timestamp '{t_str}' at index {idx} is unique")
        seen_timestamps.add(t_str)

        dt = datetime.fromisoformat(t_str)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        run_assert(dt.tzinfo == timezone.utc, f"Timestamp '{t_str}' normalized to UTC")
        parsed_dts.append(dt)

    for i in range(len(parsed_dts) - 1):
        run_assert(
            parsed_dts[i + 1] > parsed_dts[i],
            f"Timestamps strictly increasing at index {i} ({times[i]} < {times[i+1]})",
        )
        delta = parsed_dts[i + 1] - parsed_dts[i]
        run_assert(
            delta == timedelta(hours=1),
            f"Cadence between {times[i]} and {times[i+1]} is strictly 1 hour",
        )

    run_assert(
        times[0] == "2024-05-31T00:00" and times[-1] == "2024-06-06T23:00",
        f"Hourly range spans expected window [2024-05-31T00:00 to 2024-06-06T23:00], got [{times[0]} to {times[-1]}]",
    )

    # Validate numeric and finite values for hourly variables
    et0_values = h_data["et0_fao_evapotranspiration"]
    t2m_values = h_data["temperature_2m"]
    precip_values = h_data["precipitation"]

    for idx, (t_str, val) in enumerate(zip(times, et0_values)):
        run_assert(val is not None, f"Hourly ET0 at index {idx} ({t_str}) is not null")
        run_assert(
            is_finite_numeric(val),
            f"Hourly ET0 at index {idx} ({t_str}) is finite numeric (got {val!r})",
        )

    for idx, (t_str, val) in enumerate(zip(times, t2m_values)):
        run_assert(
            is_finite_numeric(val),
            f"Hourly temperature_2m at index {idx} ({t_str}) is finite numeric (got {val!r})",
        )

    for idx, (t_str, val) in enumerate(zip(times, precip_values)):
        run_assert(
            is_finite_numeric(val),
            f"Hourly precipitation at index {idx} ({t_str}) is finite numeric (got {val!r})",
        )

    t_map = {
        dt.strftime("%Y-%m-%dT%H:%M"): value
        for dt, value in zip(parsed_dts, et0_values)
    }
    print(f"Validated {len(times)} consecutive, unique, finite hourly observations from {times[0]} to {times[-1]}.")

    dates = ["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"]

    # 3. Validation of Temporal Conventions across All Combinations
    print("\n3. VALIDATION OF ALL FOUR CONVENTION / OFFSET COMBINATIONS")
    print("--------------------------------------------------------------------------------")
    combinations = [
        (1, 2, "Convention 1, UTC+2"),
        (1, 3, "Convention 1, UTC+3"),
        (2, 2, "Convention 2, UTC+2"),
        (2, 3, "Convention 2, UTC+3"),
    ]

    slices_by_combo: dict[tuple[int, int], dict[str, list[float]]] = {}
    timestamps_by_combo: dict[tuple[int, int], dict[str, list[str]]] = {}

    for convention, offset, combo_name in combinations:
        slices_by_combo[(convention, offset)] = {}
        timestamps_by_combo[(convention, offset)] = {}

        for d_str in dates:
            exp_ts = expected_utc_timestamps(d_str, convention, offset)
            run_assert(
                len(exp_ts) == 24,
                f"{combo_name}, date {d_str}: expected 24 timestamps, got {len(exp_ts)}",
            )
            timestamps_by_combo[(convention, offset)][d_str] = exp_ts

            daily_obs = []
            for t_req in exp_ts:
                run_assert(
                    t_req in t_map,
                    f"{combo_name}, date {d_str}: expected timestamp {t_req} exists in hourly evidence",
                )
                daily_obs.append(t_map[t_req])

            slices_by_combo[(convention, offset)][d_str] = daily_obs

        # Validate adjacent-day continuity across all adjacent pairs
        for i in range(len(dates) - 1):
            d_curr = dates[i]
            d_next = dates[i + 1]
            curr_last_ts_str = timestamps_by_combo[(convention, offset)][d_curr][-1]
            next_first_ts_str = timestamps_by_combo[(convention, offset)][d_next][0]

            curr_last_dt = datetime.fromisoformat(curr_last_ts_str).replace(tzinfo=timezone.utc)
            next_first_dt = datetime.fromisoformat(next_first_ts_str).replace(tzinfo=timezone.utc)

            run_assert(
                curr_last_dt + timedelta(hours=1) == next_first_dt,
                f"Contiguous adjacent partitioning for {d_curr} -> {d_next}, {combo_name} "
                f"({curr_last_ts_str} + 1h == {next_first_ts_str})",
            )

    print("Validated 24-observation completeness, chronological continuity, and adjacent boundary continuity for all 4 combinations.")

    # Recompute daily sums
    c1_sums_utc2 = {d: sum(slices_by_combo[(1, 2)][d]) for d in dates}
    c1_sums_utc3 = {d: sum(slices_by_combo[(1, 3)][d]) for d in dates}
    c2_sums_utc2 = {d: sum(slices_by_combo[(2, 2)][d]) for d in dates}
    c2_sums_utc3 = {d: sum(slices_by_combo[(2, 3)][d]) for d in dates}

    # 4. Explicit Assertions on Expected Daily Sums and Differences
    print("\n4. NUMERICAL VALIDATION OF DAILY SUMS AND DIFFERENCES")
    print("--------------------------------------------------------------------------------")
    # Verify Convention 1 rounded daily sums and differences
    for idx, d in enumerate(dates):
        u2_sum = c1_sums_utc2[d]
        u3_sum = c1_sums_utc3[d]
        diff = u3_sum - u2_sum
        run_assert(
            math.isclose(round(u2_sum, 2), EXPECTED_C1_UTC2[idx], abs_tol=1e-9),
            f"Convention 1, date {d}: UTC+2 sum {u2_sum:.6f} rounds to expected {EXPECTED_C1_UTC2[idx]}",
        )
        run_assert(
            math.isclose(round(u3_sum, 2), EXPECTED_C1_UTC3[idx], abs_tol=1e-9),
            f"Convention 1, date {d}: UTC+3 sum {u3_sum:.6f} rounds to expected {EXPECTED_C1_UTC3[idx]}",
        )
        run_assert(
            math.isclose(round(diff, 2), EXPECTED_C1_DIFFERENCE[idx], abs_tol=1e-9),
            f"Convention 1, date {d}: difference {diff:.6f} rounds to expected {EXPECTED_C1_DIFFERENCE[idx]}",
        )

    # Verify Convention 2 rounded daily sums and differences
    for idx, d in enumerate(dates):
        u2_sum = c2_sums_utc2[d]
        u3_sum = c2_sums_utc3[d]
        diff = u3_sum - u2_sum
        run_assert(
            math.isclose(round(u2_sum, 2), EXPECTED_C2_UTC2[idx], abs_tol=1e-9),
            f"Convention 2, date {d}: UTC+2 sum {u2_sum:.6f} rounds to expected {EXPECTED_C2_UTC2[idx]}",
        )
        run_assert(
            math.isclose(round(u3_sum, 2), EXPECTED_C2_UTC3[idx], abs_tol=1e-9),
            f"Convention 2, date {d}: UTC+3 sum {u3_sum:.6f} rounds to expected {EXPECTED_C2_UTC3[idx]}",
        )
        run_assert(
            math.isclose(round(diff, 2), EXPECTED_C2_DIFFERENCE[idx], abs_tol=1e-9),
            f"Convention 2, date {d}: difference {diff:.6f} rounds to expected {EXPECTED_C2_DIFFERENCE[idx]}",
        )

    print("Convention 1 (Timestamp Calendar-Day Grouping: 00:00 to 23:00 local):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C1 Diff (U3 - U2)':<18}")
    print("-" * 56)
    for d in dates:
        print(f"{d:<10} | {c1_sums_utc2[d]:<12.6f} | {c1_sums_utc3[d]:<12.6f} | {c1_sums_utc3[d] - c1_sums_utc2[d]:<+18.6f}")

    print("\nConvention 2 (Physical Preceding-Hour Attribution: 01:00 to 00:00 next day):")
    print(f"{'Date':<10} | {'UTC+2 Sum':<12} | {'UTC+3 Sum':<12} | {'C2 Diff (U3 - U2)':<18}")
    print("-" * 56)
    for d in dates:
        print(f"{d:<10} | {c2_sums_utc2[d]:<12.6f} | {c2_sums_utc3[d]:<12.6f} | {c2_sums_utc3[d] - c2_sums_utc2[d]:<+18.6f}")

    # 5. Boundary Observations and Arithmetic Assertions
    print("\n5. BOUNDARY OBSERVATIONS AND ARITHMETIC ASSERTIONS")
    print("--------------------------------------------------------------------------------")
    for ts_key, exp_val in EXPECTED_BOUNDARY_VALUES.items():
        run_assert(ts_key in t_map, f"Boundary timestamp '{ts_key}' exists in hourly evidence")
        act_val = t_map[ts_key]
        run_assert(
            math.isclose(act_val, exp_val, abs_tol=1e-9),
            f"Boundary observation at {ts_key}: expected {exp_val}, got {act_val}",
        )

    # Recomputed boundary relationships
    c1_j2_entering = t_map["2024-06-01T21:00"]
    c1_j2_leaving = t_map["2024-06-02T21:00"]
    c1_j2_shift = c1_j2_entering - c1_j2_leaving

    c2_j2_entering = t_map["2024-06-01T22:00"]
    c2_j2_leaving = t_map["2024-06-02T22:00"]
    c2_j2_shift = c2_j2_entering - c2_j2_leaving

    c1_j5_entering = t_map["2024-06-04T21:00"]
    c1_j5_leaving = t_map["2024-06-05T21:00"]
    c1_j5_shift = c1_j5_entering - c1_j5_leaving

    c2_j5_entering = t_map["2024-06-04T22:00"]
    c2_j5_leaving = t_map["2024-06-05T22:00"]
    c2_j5_shift = c2_j5_entering - c2_j5_leaving

    run_assert(
        math.isclose(c1_j2_shift, 0.06, abs_tol=1e-9),
        f"Convention 1 June 2 boundary difference: expected 0.06, got {c1_j2_shift:.6f}",
    )
    run_assert(
        math.isclose(c2_j2_shift, 0.05, abs_tol=1e-9),
        f"Convention 2 June 2 boundary difference: expected 0.05, got {c2_j2_shift:.6f}",
    )
    run_assert(
        math.isclose(c1_j5_shift, 0.00, abs_tol=1e-9),
        f"Convention 1 June 5 boundary difference: expected 0.00, got {c1_j5_shift:.6f}",
    )
    run_assert(
        math.isclose(c2_j5_shift, 0.00, abs_tol=1e-9),
        f"Convention 2 June 5 boundary difference: expected 0.00, got {c2_j5_shift:.6f}",
    )

    # Invariance: slice differences match boundary differences
    run_assert(
        math.isclose(c1_sums_utc3["2024-06-02"] - c1_sums_utc2["2024-06-02"], c1_j2_shift, abs_tol=1e-9),
        "June 2 Convention 1 slice difference equals entering - leaving boundary difference",
    )
    run_assert(
        math.isclose(c2_sums_utc3["2024-06-02"] - c2_sums_utc2["2024-06-02"], c2_j2_shift, abs_tol=1e-9),
        "June 2 Convention 2 slice difference equals entering - leaving boundary difference",
    )
    run_assert(
        math.isclose(c1_sums_utc3["2024-06-05"] - c1_sums_utc2["2024-06-05"], c1_j5_shift, abs_tol=1e-9),
        "June 5 Convention 1 slice difference equals entering - leaving boundary difference",
    )
    run_assert(
        math.isclose(c2_sums_utc3["2024-06-05"] - c2_sums_utc2["2024-06-05"], c2_j5_shift, abs_tol=1e-9),
        "June 5 Convention 2 slice difference equals entering - leaving boundary difference",
    )

    print("Boundary arithmetic and slice difference invariance verified across June 2 and June 5.")

    # 6. Validation of Daily Date Arrays and Controlled Daily Responses
    print("\n6. VALIDATION OF DAILY DATE ARRAYS AND DAILY RESPONSES")
    print("--------------------------------------------------------------------------------")
    daily_payloads = [
        ("Config 1 (Africa/Cairo, 5m)", cairo_e5),
        ("Config 2 (GMT+3, 5m)", gmt3_e5),
        ("Config 3 (GMT+3, 6m)", gmt3_e6),
        ("Historical Fixture", fixture),
    ]

    for label, payload in daily_payloads:
        run_assert("daily" in payload, f"{label} contains 'daily' key")
        daily_obj = payload["daily"]
        run_assert(isinstance(daily_obj, dict), f"{label} 'daily' is a dictionary")

        run_assert("time" in daily_obj, f"{label} contains 'daily.time'")
        d_times = daily_obj["time"]
        run_assert(isinstance(d_times, list), f"{label} 'daily.time' is a list")
        run_assert(len(d_times) == len(dates), f"{label} 'daily.time' length is {len(dates)}")

        # Parseable, unique, chronological, matches expected dates
        seen_d = set()
        for idx, ds in enumerate(d_times):
            run_assert(isinstance(ds, str), f"{label} date string at index {idx} is a string")
            run_assert(ds not in seen_d, f"{label} date string '{ds}' is unique")
            seen_d.add(ds)
            # Parseable ISO date
            parsed_d = datetime.fromisoformat(ds).date()
            run_assert(ds == parsed_d.isoformat(), f"{label} date '{ds}' is valid ISO format")

        run_assert(
            d_times == dates,
            f"{label} 'daily.time' ({d_times}) matches expected dates exactly ({dates})",
        )

        run_assert("et0_fao_evapotranspiration" in daily_obj, f"{label} contains 'et0_fao_evapotranspiration'")
        et0_arr = daily_obj["et0_fao_evapotranspiration"]
        run_assert(isinstance(et0_arr, list), f"{label} ET0 array is a list")
        run_assert(len(et0_arr) == len(d_times), f"{label} ET0 array length matches date array length")

        for idx, val in enumerate(et0_arr):
            run_assert(val is not None, f"{label} daily ET0 at index {idx} ({d_times[idx]}) is not null")
            run_assert(
                is_finite_numeric(val),
                f"{label} daily ET0 at index {idx} ({d_times[idx]}) is finite numeric (got {val!r})",
            )

    d_cairo_e5 = cairo_e5["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e5 = gmt3_e5["daily"]["et0_fao_evapotranspiration"]
    d_gmt3_e6 = gmt3_e6["daily"]["et0_fao_evapotranspiration"]
    d_fixture = fixture["daily"]["et0_fao_evapotranspiration"]

    # Explicit sequence checks against expected values
    def assert_numeric_sequence(actual: list, expected: list, description: str):
        run_assert(len(actual) == len(expected), f"{description}: expected length {len(expected)}, got {len(actual)}")
        for idx, (act_val, exp_val) in enumerate(zip(actual, expected)):
            run_assert(
                is_finite_numeric(act_val) and math.isclose(act_val, exp_val, rel_tol=0.0, abs_tol=1e-9),
                f"{description}[{idx}]: expected {exp_val}, got {act_val}",
            )

    assert_numeric_sequence(d_cairo_e5, EXPECTED_CAIRO_E5, "Config 1 (Cairo, 5m)")
    assert_numeric_sequence(d_gmt3_e5, EXPECTED_GMT3_E5, "Config 2 (GMT+3, 5m)")
    assert_numeric_sequence(d_gmt3_e6, EXPECTED_GMT3_E6, "Config 3 (GMT+3, 6m)")
    assert_numeric_sequence(d_fixture, EXPECTED_FIXTURE, "Historical Fixture")

    # Verify daily differences
    # Timezone difference = GMT+3, elevation 5 m - Cairo, elevation 5 m
    diff_tz = [round(b - a, 4) for a, b in zip(d_cairo_e5, d_gmt3_e5)]
    # Elevation difference = GMT+3, elevation 6 m - GMT+3, elevation 5 m
    diff_elev = [round(b - a, 4) for a, b in zip(d_gmt3_e5, d_gmt3_e6)]
    # Config 3 versus fixture = historical fixture - Config 3
    diff_fixture_cfg3 = [round(b - a, 4) for a, b in zip(d_gmt3_e6, d_fixture)]

    assert_numeric_sequence(diff_tz, EXPECTED_TIMEZONE_DIFFERENCE, "Timezone difference (GMT+3, 5m - Cairo, 5m)")
    assert_numeric_sequence(diff_elev, EXPECTED_ELEVATION_DIFFERENCE, "Elevation difference (GMT+3, 6m - GMT+3, 5m)")
    assert_numeric_sequence(diff_fixture_cfg3, EXPECTED_CONFIG3_FIXTURE_DIFFERENCE, "Fixture - Config 3 difference")

    # Precise equality claim (Correction E)
    run_assert(
        all(
            math.isclose(a, b, rel_tol=0.0, abs_tol=1e-9)
            for a, b in zip(d_gmt3_e6, d_fixture)
        ),
        "Config 3 and the historical fixture agree within an absolute tolerance of 1e-9",
    )
    run_assert(
        all(a == b for a, b in zip(d_gmt3_e6, d_fixture)),
        "Config 3 and the historical fixture have exactly equal parsed numeric values",
    )

    print(f"{'Date':<10} | {'Config 1 (Cairo, 5m)':<20} | {'Config 2 (GMT+3, 5m)':<20} | {'Config 3 (GMT+3, 6m)':<20} | {'Fixture (GMT+3, 6m)':<20}")
    print("-" * 100)
    for i, d in enumerate(dates):
        print(f"{d:<10} | {d_cairo_e5[i]:<20.2f} | {d_gmt3_e5[i]:<20.2f} | {d_gmt3_e6[i]:<20.2f} | {d_fixture[i]:<20.2f}")

    # 7. Hourly-Sum-versus-Daily Residuals & Precision Limitations
    print("\n7. HOURLY-SUM-VERSUS-DAILY RESIDUALS & SCIENTIFIC UNCERTAINTY")
    print("--------------------------------------------------------------------------------")
    print(f"{'Date':<10} | {'C1 UTC+2 Sum':<14} | {'Cairo API':<12} | {'Residual (C1 - API)':<20} | {'C1 UTC+3 Sum':<14} | {'GMT+3 API':<12} | {'Residual (C1 - API)':<20}")
    print("-" * 105)
    for i, d in enumerate(dates):
        res_u2 = c1_sums_utc2[d] - d_cairo_e5[i]
        res_u3 = c1_sums_utc3[d] - d_gmt3_e5[i]
        print(f"{d:<10} | {c1_sums_utc2[d]:<14.6f} | {d_cairo_e5[i]:<12.2f} | {res_u2:<+20.6f} | {c1_sums_utc3[d]:<14.6f} | {d_gmt3_e5[i]:<12.2f} | {res_u3:<+20.6f}")

    print("\nResidual interpretation: UNRESOLVED.")
    print("The preserved hourly values have limited decimal precision, so rounding may contribute")
    print("to the residuals. The available evidence does not establish rounding as the cause.")
    print("The API's internal daily aggregation convention has not been independently verified.")
    print("Elevation sensitivity is an observed parameter effect, not proof of the historical cause.")

    actual_assertion_count = len(executed_assertions)
    print("\nExecuted Assertions Summary:")
    print(f"Total Assertions Passed: {actual_assertion_count}")
    print("Status: SUCCESS (Offline verification completed with zero errors)")


if __name__ == "__main__":
    run_investigation()
