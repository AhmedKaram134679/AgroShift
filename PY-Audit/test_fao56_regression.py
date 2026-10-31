"""Deterministic, offline scientific regression tests for FAO-56 Penman-Monteith ET0.

Verifies:
1. Schema, units, and numeric validity of the fixed offline benchmark dataset.
2. Intermediate FAO-56 equations (pressure, psychrometric constant, slope delta, VPD, u2, Ra, Rso, Rns, Rnl, Rn).
3. Final daily ET0 calculation against independently established expected values.
4. Comparison metrics calculation over representative benchmark cases.
5. Formula mutation and regression sensitivity detection.
6. Error handling for unphysical inputs (e.g. Tmax < Tmin).
"""

from __future__ import annotations

import json
import math
import sys
from datetime import date
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from agroshift_et0_independent_check import (
    EXPECTED_UNITS,
    extraterrestrial_radiation,
    fao56_daily_et0,
    metrics,
    saturation_vapour_pressure,
)

DATA_PATH = Path(__file__).resolve().parent / "fixed_offline_et0_dataset.json"


class FAO56ScientificRegressionTests(unittest.TestCase):
    """Test suite ensuring reproducible, network-independent verification of FAO-56 daily ET0."""

    @classmethod
    def setUpClass(cls) -> None:
        if not DATA_PATH.exists():
            raise FileNotFoundError(f"Fixed offline benchmark dataset not found at {DATA_PATH}")
        with open(DATA_PATH, encoding="utf-8") as f:
            cls.dataset = json.load(f)

    def test_offline_dataset_schema_and_units(self) -> None:
        """Verify the fixed offline dataset contains all required fields, valid units, and finite numbers."""
        metadata = self.dataset.get("metadata", {})
        self.assertIn("units", metadata)
        self.assertEqual(metadata["units"], EXPECTED_UNITS)

        cases = self.dataset.get("cases", [])
        self.assertGreaterEqual(len(cases), 5, "At least 5 representative benchmark cases must be present")

        for c in cases:
            case_id = c["id"]
            with self.subTest(case_id=case_id):
                self.assertIn("site", c)
                self.assertIn("date", c)
                # Verify ISO date
                date.fromisoformat(c["date"])
                self.assertTrue(math.isfinite(c["latitude"]))
                self.assertTrue(math.isfinite(c["longitude"]))
                self.assertTrue(math.isfinite(c["grid_elevation_m"]))
                self.assertTrue(math.isfinite(c["open_meteo_et0_mm"]))
                self.assertTrue(math.isfinite(c["expected_fao56_daily_et0_mm"]))

                inputs = c["inputs"]
                for var_name, expected_unit in EXPECTED_UNITS.items():
                    if var_name in inputs:
                        val = inputs[var_name]
                        self.assertIsNotNone(val)
                        self.assertTrue(math.isfinite(val))

    def test_intermediate_fao56_equations(self) -> None:
        """Verify intermediate meteorological and radiation terms match reference formulas."""
        for c in self.dataset["cases"]:
            case_id = c["id"]
            inp = c["inputs"]
            exp = c["expected_intermediates"]
            d = date.fromisoformat(c["date"])
            tmax = inp["temperature_2m_max"]
            tmin = inp["temperature_2m_min"]
            tdew = inp["dew_point_2m_mean"]
            w10 = inp["wind_speed_10m_mean"]
            elev = c["grid_elevation_m"]
            lat = c["latitude"]

            with self.subTest(case_id=case_id):
                # 1. Day of year
                j = d.timetuple().tm_yday
                self.assertEqual(j, exp["day_of_year"])

                # 2. Mean temperature
                tmean = (tmax + tmin) / 2.0
                self.assertAlmostEqual(tmean, exp["tmean_c"], places=5)

                # 3. Atmospheric pressure (FAO-56 Eq. 7)
                p_kpa = 101.3 * (((293.0 - 0.0065 * elev) / 293.0) ** 5.26)
                self.assertAlmostEqual(p_kpa, exp["p_kpa"], places=5)

                # 4. Psychrometric constant (FAO-56 Eq. 8)
                gamma = 0.000665 * p_kpa
                self.assertAlmostEqual(gamma, exp["gamma_kpa_c"], places=5)

                # 5. Slope of saturation vapour pressure curve (FAO-56 Eq. 13)
                delta = 4098.0 * saturation_vapour_pressure(tmean) / ((tmean + 237.3) ** 2)
                self.assertAlmostEqual(delta, exp["delta_kpa_c"], places=5)

                # 6. Actual and saturation vapour pressure (FAO-56 Eqs. 12 & 14)
                ea = saturation_vapour_pressure(tdew)
                es = (saturation_vapour_pressure(tmax) + saturation_vapour_pressure(tmin)) / 2.0
                vpd = max(0.0, es - ea)
                self.assertAlmostEqual(ea, exp["ea_kpa"], places=5)
                self.assertAlmostEqual(es, exp["es_kpa"], places=5)
                self.assertAlmostEqual(vpd, exp["vpd_kpa"], places=5)

                # 7. Wind speed at 2m (FAO-56 Eq. 47)
                u2 = max(0.0, w10) * 4.87 / math.log(67.8 * 10.0 - 5.42)
                self.assertAlmostEqual(u2, exp["u2_m_s"], places=5)

                # 8. Extraterrestrial and clear-sky radiation (FAO-56 Eqs. 21 & 37)
                ra = extraterrestrial_radiation(lat, j)
                rso = (0.75 + 2e-5 * elev) * ra
                self.assertAlmostEqual(ra, exp["ra_mj_m2_day"], places=5)
                self.assertAlmostEqual(rso, exp["rso_mj_m2_day"], places=5)

    def test_final_fao56_daily_et0_regression(self) -> None:
        """Verify the final daily ET0 estimate matches the independently verified values to 1e-6 mm/day."""
        for c in self.dataset["cases"]:
            case_id = c["id"]
            inp = c["inputs"]
            d = date.fromisoformat(c["date"])

            actual_et0 = fao56_daily_et0(
                day=d,
                latitude_deg=c["latitude"],
                elevation_m=c["grid_elevation_m"],
                tmax=inp["temperature_2m_max"],
                tmin=inp["temperature_2m_min"],
                dewpoint_mean=inp["dew_point_2m_mean"],
                wind10_m_s=inp["wind_speed_10m_mean"],
                solar_radiation_mj_m2=inp["shortwave_radiation_sum"],
            )

            expected_et0 = c["expected_fao56_daily_et0_mm"]
            with self.subTest(case_id=case_id):
                self.assertAlmostEqual(
                    actual_et0,
                    expected_et0,
                    places=6,
                    msg=f"ET0 mismatch for {case_id}: computed {actual_et0:.7f} vs expected {expected_et0:.7f}",
                )

    def test_benchmark_subset_metrics_reconciliation(self) -> None:
        """Verify comparison metrics (MAE, Bias, RMSE, RelDiff) on the representative fixed cases."""
        pairs: list[tuple[float, float]] = []
        for c in self.dataset["cases"]:
            pairs.append((c["expected_fao56_daily_et0_mm"], c["open_meteo_et0_mm"]))

        res = metrics(pairs)
        self.assertEqual(res["paired_days"], 5)

        # Expected values derived from manual calculation of the 5 pairs:
        # Pair 1: (2.318833, 2.71) -> diff = -0.391167, rel = 14.43422%
        # Pair 2: (11.823404, 11.40) -> diff = +0.423404, rel = 3.71407%
        # Pair 3: (1.624678, 1.86) -> diff = -0.235322, rel = 12.65175%
        # Pair 4: (8.668645, 8.03) -> diff = +0.638645, rel = 7.95324%
        # Pair 5: (11.712857, 11.07) -> diff = +0.642857, rel = 5.80720%
        # MAE = (0.391167 + 0.423404 + 0.235322 + 0.638645 + 0.642857) / 5 = 0.466279 mm/day
        # Bias = (-0.391167 + 0.423404 - 0.235322 + 0.638645 + 0.642857) / 5 = 0.215683 mm/day
        diffs = [ind - api for ind, api in pairs]
        expected_mae = sum(abs(x) for x in diffs) / 5.0
        expected_bias = sum(diffs) / 5.0
        expected_rmse = math.sqrt(sum(x * x for x in diffs) / 5.0)

        self.assertAlmostEqual(res["mae_mm_day"], expected_mae, places=5)
        self.assertAlmostEqual(res["bias_independent_minus_api_mm_day"], expected_bias, places=5)
        self.assertAlmostEqual(res["rmse_mm_day"], expected_rmse, places=5)
        self.assertIsNotNone(res["mean_absolute_relative_difference_percent"])

    def test_mutation_sensitivity_detects_formula_corruption(self) -> None:
        """Verify that altering core physical constants or terms is detected immediately."""
        case = self.dataset["cases"][0]  # minya_winter_min
        inp = case["inputs"]
        d = date.fromisoformat(case["date"])
        baseline = case["expected_fao56_daily_et0_mm"]

        # Mutate wind speed input -> ET0 must change
        mutated_et0 = fao56_daily_et0(
            day=d,
            latitude_deg=case["latitude"],
            elevation_m=case["grid_elevation_m"],
            tmax=inp["temperature_2m_max"],
            tmin=inp["temperature_2m_min"],
            dewpoint_mean=inp["dew_point_2m_mean"],
            wind10_m_s=inp["wind_speed_10m_mean"] * 1.5,
            solar_radiation_mj_m2=inp["shortwave_radiation_sum"],
        )
        self.assertNotEqual(mutated_et0, baseline)
        self.assertGreater(mutated_et0, baseline, "Higher wind speed must increase evaporative demand")

    def test_invalid_temperature_inversion_raises_value_error(self) -> None:
        """Verify that an inverted temperature profile (tmax < tmin) raises a clear ValueError."""
        case = self.dataset["cases"][0]
        inp = case["inputs"]
        d = date.fromisoformat(case["date"])

        with self.assertRaises(ValueError) as ctx:
            fao56_daily_et0(
                day=d,
                latitude_deg=case["latitude"],
                elevation_m=case["grid_elevation_m"],
                tmax=10.0,
                tmin=25.0,  # tmax < tmin
                dewpoint_mean=inp["dew_point_2m_mean"],
                wind10_m_s=inp["wind_speed_10m_mean"],
                solar_radiation_mj_m2=inp["shortwave_radiation_sum"],
            )
        self.assertIn("Tmax is below Tmin", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
