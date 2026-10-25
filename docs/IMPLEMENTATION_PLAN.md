# AgroShift — Phased Implementation Plan & Acceptance Gates

**Document Version:** 1.0.0  
**Methodology:** Incremental Clean Architecture with Automated Test Verification

---

## Phase Overview and Gate Structure

```
[Phase 1: Docs & Feasibility] ──▶ [Phase 2: Core Domain & Tests] ──▶ [Phase 3: Data Layer & API]
                                                                                │
                                                                                ▼
[Phase 6: Final Audit & APK]  ◀── [Phase 5: Feature Screens]     ◀── [Phase 4: App Shell & RTL UI]
```

---

## Phase 1: Specifications & Feasibility Gate *(Current)*
- **Deliverables:**
  - `docs/PRODUCT_REQUIREMENTS.md`
  - `docs/TECHNICAL_ARCHITECTURE.md`
  - `docs/DATA_SOURCES_AND_VALIDATION.md`
  - `docs/AGRICULTURAL_METHODS_AND_EVIDENCE.md`
  - `docs/IMPLEMENTATION_PLAN.md`
  - Live probe testing of Open-Meteo archive & forecast endpoints for Egypt coordinates.
- **Verification Command:** `ls docs/*.md` & `curl` verification.
- **Gate:** All documentation written and approved; APIs verified without error.

---

## Phase 2: Domain Layer & Unit Test Suite
- **Deliverables:**
  - Core domain models: `Coordinate`, `DailyAgroRecord`, `Crop`, `RotationPlan`, `WaterRequirement`.
  - Scientific calculators (pure Dart):
    - `GddCalculator` (Growing Degree Days with base & cutoff thresholds)
    - `EtcCalculator` (Crop evapotranspiration and $m^3/\text{feddan}$ conversion)
    - `HeatStressEvaluator` (Thermal critical threshold exceedances)
    - `RotationEvaluator` (Multi-crop sequence water balance & soil nitrogen impact)
  - Validation rules: `CoordinateValidator`, `ScientificRangeValidator`.
  - Comprehensive unit test suite in `test/domain/`.
- **Verification Command:** `flutter test test/domain/`
- **Gate:** 100% pass rate on all scientific calculation and boundary tests.

---

## Phase 3: Data Infrastructure & Adapters
- **Deliverables:**
  - Core error failure types: `Failure`, `NetworkFailure`, `DataParsingFailure`, `PhysicalRangeFailure`.
  - HTTP client integration (`dio`) with timeout configurations.
  - `OpenMeteoRemoteDataSource` querying actual ERA5-Land reanalysis and short-term forecast.
  - `WeatherRepositoryImpl` with model adapter normalizing vendor fields into domain entities.
  - In-memory / persistent caching layer for offline resilience.
  - Integration/Mock tests for data sources in `test/data/`.
- **Verification Command:** `flutter test test/data/`
- **Gate:** Repository tests verify correct parsing, provenance tagging, and non-fabrication of missing data.

---

## Phase 4: Application Foundation, RTL Theme & Navigation
- **Deliverables:**
  - Dependencies installed in `pubspec.yaml` (`flutter_riverpod`, `dio`, `intl`, `fl_chart`).
  - Egyptian Agricultural Theme:
    - Forest green / Nile fertile silt palette (Material 3).
    - Native Arabic typography and RTL layout enforcement.
    - Standardized Egyptian agricultural units ($m^3/\text{feddan}$, °C, mm).
  - Riverpod provider wiring and dependency injection.
  - Clean navigation shell (Bottom Navigation Bar with Arabic labels).
- **Verification Command:** `flutter test`
- **Gate:** App shell builds cleanly and renders in native RTL.

---

## Phase 5: Feature Screens & Presentation
- **Deliverables:**
  1. **Dashboard Screen:** Active field status, heat stress badge, 7-day cumulative $ET_0$, quick rotation recommendation preview.
  2. **Field Management Screen:** Register, list, and switch Egyptian governorate fields with coordinate validation.
  3. **Environmental Analysis Screen:** Interactive historical & forecast trend charts (`fl_chart`), $ET_0$ vs temperature vs rainfall, missing data indicators, and provenance drawer.
  4. **Crop-Rotation Laboratory Screen:** Interactive rotation comparison workbench. Compare scenarios (e.g., Clover-Maize vs. Wheat-Maize vs. Wheat-Rice) across water consumption ($m^3/\text{feddan}$), soil nitrogen delta, and heat stress risks.
  5. **Scientific Provenance Screen:** Full methodology disclosure, FAO-56 citations, equation viewer, and provider status.
- **Verification Command:** `flutter test` & static analysis.
- **Gate:** All screens tested, responsive, and free of widget overflow or calculation logic.

---

## Phase 6: Code Formatting, Static Analysis & Android Build
- **Deliverables:**
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug` (or release verification)
- **Verification Command:** Full CLI verification pipeline.
- **Gate:** Zero lint errors, zero test failures, verified Android build artifact.
