"""Unit tests for the metrics() calculation in PY-Audit/agroshift_et0_independent_check.py.

Verifies:
1. Behavior on empty input lists (returns 0 count and None for all metrics).
2. Behavior on ordinary paired values (MAE, bias, RMSE, mean relative difference).
3. Behavior when API values are zero (safe from ZeroDivisionError, excluded from relative difference).
4. Behavior when API values are negative (excluded from relative difference).
5. Behavior with mixtures of valid and invalid denominators.
6. Behavior with non-finite values (NaN, +Inf, -Inf in both positions raise ValueError).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path
import unittest

# Ensure the parent directory is on sys.path so agroshift_et0_independent_check can be imported
sys.path.insert(0, str(Path(__file__).resolve().parent))

from agroshift_et0_independent_check import metrics


class MetricsCalculationTests(unittest.TestCase):
    """Test suite covering edge cases and arithmetic guarantees of metrics()."""

    def test_empty_list_returns_zero_count_and_none_metrics(self) -> None:
        """An empty observation list must return paired_days=0 and None for all metrics."""
        result = metrics([])
        self.assertEqual(result["paired_days"], 0)
        self.assertIsNone(result["mean_api_et0_mm_day"])
        self.assertIsNone(result["mean_independent_et0_mm_day"])
        self.assertIsNone(result["mae_mm_day"])
        self.assertIsNone(result["bias_independent_minus_api_mm_day"])
        self.assertIsNone(result["rmse_mm_day"])
        self.assertIsNone(result["mean_absolute_relative_difference_percent"])

    def test_ordinary_paired_values_calculation(self) -> None:
        """Ordinary finite pairs must yield exact arithmetic values."""
        # Pair 1: ind=3.0, api=2.5 -> diff=+0.5, rel_diff = 0.5/2.5 * 100 = 20.0%
        # Pair 2: ind=4.5, api=5.0 -> diff=-0.5, rel_diff = 0.5/5.0 * 100 = 10.0%
        pairs = [(3.0, 2.5), (4.5, 5.0)]
        result = metrics(pairs)

        self.assertEqual(result["paired_days"], 2)
        self.assertAlmostEqual(result["mean_api_et0_mm_day"], 3.75, places=7)
        self.assertAlmostEqual(result["mean_independent_et0_mm_day"], 3.75, places=7)
        self.assertAlmostEqual(result["mae_mm_day"], 0.5, places=7)
        self.assertAlmostEqual(result["bias_independent_minus_api_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["rmse_mm_day"], 0.5, places=7)
        self.assertAlmostEqual(result["mean_absolute_relative_difference_percent"], 15.0, places=7)

    def test_single_identical_pair_yields_zero_error(self) -> None:
        """When independent matches api perfectly, error and relative difference must be 0."""
        pairs = [(5.25, 5.25)]
        result = metrics(pairs)

        self.assertEqual(result["paired_days"], 1)
        self.assertAlmostEqual(result["mean_api_et0_mm_day"], 5.25, places=7)
        self.assertAlmostEqual(result["mean_independent_et0_mm_day"], 5.25, places=7)
        self.assertAlmostEqual(result["mae_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["bias_independent_minus_api_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["rmse_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["mean_absolute_relative_difference_percent"], 0.0, places=7)

    def test_zero_api_denominator_does_not_raise_and_excludes_rel_diff(self) -> None:
        """API values equal to 0.0 must not raise ZeroDivisionError and must be excluded from relative diff."""
        pairs = [(3.0, 0.0), (4.0, 0.0)]
        result = metrics(pairs)

        self.assertEqual(result["paired_days"], 2)
        self.assertAlmostEqual(result["mean_api_et0_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["mean_independent_et0_mm_day"], 3.5, places=7)
        self.assertAlmostEqual(result["mae_mm_day"], 3.5, places=7)
        self.assertAlmostEqual(result["bias_independent_minus_api_mm_day"], 3.5, places=7)
        self.assertAlmostEqual(result["rmse_mm_day"], math.sqrt(12.5), places=7)
        # Because all API denominators are 0.0, no valid relative difference can be computed
        self.assertIsNone(result["mean_absolute_relative_difference_percent"])

    def test_negative_api_denominator_excluded_from_relative_difference(self) -> None:
        """Negative API values (unphysical ET0) must be excluded from relative diff calculation."""
        pairs = [(2.0, -1.0)]
        result = metrics(pairs)

        self.assertEqual(result["paired_days"], 1)
        self.assertAlmostEqual(result["mean_api_et0_mm_day"], -1.0, places=7)
        self.assertAlmostEqual(result["mean_independent_et0_mm_day"], 2.0, places=7)
        self.assertAlmostEqual(result["mae_mm_day"], 3.0, places=7)
        self.assertAlmostEqual(result["bias_independent_minus_api_mm_day"], 3.0, places=7)
        self.assertAlmostEqual(result["rmse_mm_day"], 3.0, places=7)
        self.assertIsNone(result["mean_absolute_relative_difference_percent"])

    def test_mixed_valid_and_invalid_denominators(self) -> None:
        """Relative difference must only average across strictly positive finite denominators."""
        # Pair 1: api=0.0 -> excluded from rel_diff
        # Pair 2: api=2.0, ind=3.0 -> rel_diff = |3 - 2| / 2 * 100 = 50.0%
        # Pair 3: api=-2.0 -> excluded from rel_diff
        pairs = [(2.0, 0.0), (3.0, 2.0), (4.0, -2.0)]
        result = metrics(pairs)

        self.assertEqual(result["paired_days"], 3)
        self.assertAlmostEqual(result["mean_api_et0_mm_day"], 0.0, places=7)
        self.assertAlmostEqual(result["mean_independent_et0_mm_day"], 3.0, places=7)
        # differences: 2.0, 1.0, 6.0 -> MAE = 9.0 / 3 = 3.0
        self.assertAlmostEqual(result["mae_mm_day"], 3.0, places=7)
        # bias: (2 + 1 + 6) / 3 = 3.0
        self.assertAlmostEqual(result["bias_independent_minus_api_mm_day"], 3.0, places=7)
        # RMSE: sqrt((4 + 1 + 36) / 3) = sqrt(41/3)
        self.assertAlmostEqual(result["rmse_mm_day"], math.sqrt(41.0 / 3.0), places=7)
        # Mean rel diff: only pair 2 is valid -> exactly 50.0%
        self.assertAlmostEqual(result["mean_absolute_relative_difference_percent"], 50.0, places=7)

    def test_non_finite_independent_values_raise_value_error(self) -> None:
        """NaN, +Inf, -Inf in the independent position must raise ValueError."""
        non_finites = [float("nan"), float("inf"), float("-inf")]
        for val in non_finites:
            with self.subTest(independent=val):
                with self.assertRaises(ValueError) as ctx:
                    metrics([(val, 3.0)])
                self.assertIn("Non-finite", str(ctx.exception))

    def test_non_finite_api_values_raise_value_error(self) -> None:
        """NaN, +Inf, -Inf in the API position must raise ValueError."""
        non_finites = [float("nan"), float("inf"), float("-inf")]
        for val in non_finites:
            with self.subTest(api=val):
                with self.assertRaises(ValueError) as ctx:
                    metrics([(3.0, val)])
                self.assertIn("Non-finite", str(ctx.exception))

    def test_non_numeric_values_raise_value_error(self) -> None:
        """Non-numeric types in tuple positions must raise ValueError."""
        with self.assertRaises(ValueError):
            metrics([(None, 3.0)])  # type: ignore[arg-type]
        with self.assertRaises(ValueError):
            metrics([(3.0, "string")])  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()

