"""Deterministic, offline scientific regression tests for FAO-56 Penman-Monteith ET0.

Verifies:
1. Schema, units, and numeric validity of the fixed offline benchmark dataset.
2. Intermediate FAO-56 equations (pressure, psychrometric constant, slope delta, VPD, u2, Ra, Rso, Rns, Rnl, Rn, rad_term, aero_term, numerator, denominator).
3. Final daily ET0 calculation against independently established expected values.
4. Five-case comparison metrics reconciliation (MAE, MBE, RMSE, MARD) against independently computed constants.
5. Input sensitivity response under physically verified positive VPD and net radiation.
6. Formula mutation sensitivity detecting corruption of core physical constants and coefficients.
7. Error handling for unphysical temperature inversions (Tmax < Tmin).
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
        self.assertEqual(len(cases), 5, "Exactly 5 representative benchmark cases must be present")

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
        """Verify intermediate meteorological, radiation, aerodynamic, numerator, and denominator terms."""
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
            rs = inp["shortwave_radiation_sum"]

            with self.subTest(case_id=case_id):
                # 1. Day of year
                j = d.timetuple().tm_yday
                self.assertEqual(j, exp["day_of_year"])

                # 2. Mean temperature (FAO-56 Eq. 9)
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

                # 9. Radiation terms: Rns, Rnl, Rn (FAO-56 Eqs. 38, 39, 40)
                ratio = min(1.0, max(0.3, rs / rso))
                self.assertAlmostEqual(ratio, exp["rs_rso_ratio"], places=5)

                rns = (1.0 - 0.23) * rs
                self.assertAlmostEqual(rns, exp["rns_mj_m2_day"], places=5)

                tmax_k = tmax + 273.16
                tmin_k = tmin + 273.16
                rnl = (
                    4.903e-9
                    * ((tmax_k**4 + tmin_k**4) / 2.0)
                    * (0.34 - 0.14 * math.sqrt(ea))
                    * (1.35 * ratio - 0.35)
                )
                self.assertAlmostEqual(rnl, exp["rnl_mj_m2_day"], places=5)

                rn = rns - rnl
                self.assertAlmostEqual(rn, exp["rn_mj_m2_day"], places=5)

                # 10. Numerator terms (radiation term & aerodynamic term)
                rad_term = 0.408 * delta * rn
                aero_term = gamma * (900.0 / (tmean + 273.0)) * u2 * vpd
                num = rad_term + aero_term
                self.assertAlmostEqual(rad_term, exp["rad_term"], places=5)
                self.assertAlmostEqual(aero_term, exp["aero_term"], places=5)
                self.assertAlmostEqual(num, exp["numerator"], places=5)

                # 11. Denominator (FAO-56 Eq. 6 denominator)
                denom = delta + gamma * (1.0 + 0.34 * u2)
                self.assertAlmostEqual(denom, exp["denom"], places=5)

                # 12. Combined ET0 calculation
                et0 = max(0.0, num / denom)
                self.assertAlmostEqual(et0, c["expected_fao56_daily_et0_mm"], places=6)

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
        """Verify five-case comparison metrics (MAE, MBE, RMSE, MARD) against independently computed constants.

        Difference convention: difference = independent_et0 - open_meteo_et0
        Expected five-case metrics derived independently from the published pairs:
          - Pair 1: (2.318833, 2.71)  -> diff = -0.391167 mm/day, rel = 14.43422%
          - Pair 2: (11.823404, 11.40) -> diff = +0.423404 mm/day, rel = 3.71407%
          - Pair 3: (1.624678, 1.86)  -> diff = -0.235322 mm/day, rel = 12.65175%
          - Pair 4: (8.668645, 8.03)  -> diff = +0.638645 mm/day, rel = 7.95324%
          - Pair 5: (11.712857, 11.07) -> diff = +0.642857 mm/day, rel = 5.80720%

        MAE  = (0.391167 + 0.423404 + 0.235322 + 0.638645 + 0.642857) / 5 = 0.466279 mm/day
        MBE  = (-0.391167 + 0.423404 - 0.235322 + 0.638645 + 0.642857) / 5 = +0.215683 mm/day
        RMSE = sqrt((0.391167^2 + 0.423404^2 + 0.235322^2 + 0.638645^2 + 0.642857^2) / 5) = 0.491689 mm/day
        MARD = (14.43422 + 3.71407 + 12.65175 + 7.95324 + 5.80720) / 5 = 8.912093%
        """
        EXPECTED_5CASE_MAE = 0.466279
        EXPECTED_5CASE_MBE = 0.215683
        EXPECTED_5CASE_RMSE = 0.491689
        EXPECTED_5CASE_MARD = 8.912093

        pairs: list[tuple[float, float]] = []
        for c in self.dataset["cases"]:
            pairs.append((c["expected_fao56_daily_et0_mm"], c["open_meteo_et0_mm"]))

        res = metrics(pairs)
        self.assertEqual(res["paired_days"], 5, "Five cases must be paired in the subset")

        self.assertAlmostEqual(res["mae_mm_day"], EXPECTED_5CASE_MAE, places=5)
        self.assertAlmostEqual(res["bias_independent_minus_api_mm_day"], EXPECTED_5CASE_MBE, places=5)
        self.assertAlmostEqual(res["rmse_mm_day"], EXPECTED_5CASE_RMSE, places=5)
        self.assertAlmostEqual(res["mean_absolute_relative_difference_percent"], EXPECTED_5CASE_MARD, places=5)

    def test_input_sensitivity_response(self) -> None:
        """Verify input-sensitivity response under physically justified positive VPD and net radiation.

        In the Minya winter case (2025-01-11), vapor pressure deficit is positive (VPD = 0.728 kPa)
        and net radiation is positive (Rn = 5.400 MJ/m2/day).
        - Under VPD > 0, increasing wind speed increases the aerodynamic evaporative transfer rate.
        - Under Rn > 0, increasing shortwave radiation increases available energy for vaporization.
        Both input changes must monotonically increase reference ET0.
        """
        case = self.dataset["cases"][0]  # minya_winter_min
        inp = case["inputs"]
        d = date.fromisoformat(case["date"])
        baseline_et0 = case["expected_fao56_daily_et0_mm"]

        # 1. Higher wind speed input (+50%)
        higher_wind_et0 = fao56_daily_et0(
            day=d,
            latitude_deg=case["latitude"],
            elevation_m=case["grid_elevation_m"],
            tmax=inp["temperature_2m_max"],
            tmin=inp["temperature_2m_min"],
            dewpoint_mean=inp["dew_point_2m_mean"],
            wind10_m_s=inp["wind_speed_10m_mean"] * 1.5,
            solar_radiation_mj_m2=inp["shortwave_radiation_sum"],
        )
        self.assertGreater(
            higher_wind_et0,
            baseline_et0,
            "Higher wind speed under positive VPD must increase aerodynamic evaporative demand",
        )

        # 2. Higher solar radiation input (+5 MJ/m2/day)
        higher_solar_et0 = fao56_daily_et0(
            day=d,
            latitude_deg=case["latitude"],
            elevation_m=case["grid_elevation_m"],
            tmax=inp["temperature_2m_max"],
            tmin=inp["temperature_2m_min"],
            dewpoint_mean=inp["dew_point_2m_mean"],
            wind10_m_s=inp["wind_speed_10m_mean"],
            solar_radiation_mj_m2=inp["shortwave_radiation_sum"] + 5.0,
        )
        self.assertGreater(
            higher_solar_et0,
            baseline_et0,
            "Higher solar radiation under positive Rn must increase radiative energy available for ET0",
        )

    def test_formula_mutation_detection(self) -> None:
        """Verify that mutating core physical constants and coefficients in FAO-56 is detected.

        Tests mutated variants of the reference Penman-Monteith equation against baseline:
        - Mutant 1: Grass albedo changed from 0.23 to 0.10 (corrupts net shortwave radiation).
        - Mutant 2: Aerodynamic numerator constant changed from 900 to 800 (corrupts aerodynamic term).
        - Mutant 3: Aerodynamic denominator constant changed from 0.34 to 0.20 (corrupts aerodynamic resistance).
        - Mutant 4: Radiation term multiplier changed from 0.408 (1/lambda) to 0.500.
        - Mutant 5: Atmospheric pressure factor in gamma changed from 0.000665 to 0.000500.
        """
        case = self.dataset["cases"][0]  # minya_winter_min
        inp = case["inputs"]
        d = date.fromisoformat(case["date"])
        tmax = inp["temperature_2m_max"]
        tmin = inp["temperature_2m_min"]
        tdew = inp["dew_point_2m_mean"]
        w10 = inp["wind_speed_10m_mean"]
        elev = case["grid_elevation_m"]
        lat = case["latitude"]
        rs = inp["shortwave_radiation_sum"]

        baseline_et0 = case["expected_fao56_daily_et0_mm"]

        # Helper to compute ET0 with mutated parameters
        def compute_mutated_et0(
            albedo: float = 0.23,
            aero_num_const: float = 900.0,
            aero_denom_const: float = 0.34,
            rad_multiplier: float = 0.408,
            gamma_pressure_factor: float = 0.000665,
        ) -> float:
            tmean = (tmax + tmin) / 2.0
            p_kpa = 101.3 * (((293.0 - 0.0065 * elev) / 293.0) ** 5.26)
            gamma = gamma_pressure_factor * p_kpa
            delta = 4098.0 * saturation_vapour_pressure(tmean) / ((tmean + 237.3) ** 2)
            ea = saturation_vapour_pressure(tdew)
            es = (saturation_vapour_pressure(tmax) + saturation_vapour_pressure(tmin)) / 2.0
            vpd = max(0.0, es - ea)
            u2 = max(0.0, w10) * 4.87 / math.log(67.8 * 10.0 - 5.42)
            ra = extraterrestrial_radiation(lat, d.timetuple().tm_yday)
            rso = (0.75 + 2e-5 * elev) * ra
            ratio = min(1.0, max(0.3, rs / rso))
            rns = (1.0 - albedo) * rs
            tmax_k = tmax + 273.16
            tmin_k = tmin + 273.16
            rnl = (
                4.903e-9
                * ((tmax_k**4 + tmin_k**4) / 2.0)
                * (0.34 - 0.14 * math.sqrt(ea))
                * (1.35 * ratio - 0.35)
            )
            rn = rns - rnl
            rad_term = rad_multiplier * delta * rn
            aero_term = gamma * (aero_num_const / (tmean + 273.0)) * u2 * vpd
            num = rad_term + aero_term
            denom = delta + gamma * (1.0 + aero_denom_const * u2)
            return num / denom

        mutants = {
            "albedo_corrupted_to_0.10": compute_mutated_et0(albedo=0.10),
            "aero_numerator_corrupted_to_800": compute_mutated_et0(aero_num_const=800.0),
            "aero_denominator_corrupted_to_0.20": compute_mutated_et0(aero_denom_const=0.20),
            "radiation_factor_corrupted_to_0.500": compute_mutated_et0(rad_multiplier=0.500),
            "gamma_pressure_factor_corrupted_to_0.000500": compute_mutated_et0(gamma_pressure_factor=0.000500),
        }

        for mutant_name, mutated_val in mutants.items():
            with self.subTest(mutant=mutant_name):
                difference = abs(mutated_val - baseline_et0)
                self.assertGreater(
                    difference,
                    0.01,
                    f"Mutant {mutant_name} was not detected: diff={difference:.6f} mm/day",
                )

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
