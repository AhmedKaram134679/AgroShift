# AgroShift — Technical Architecture Specification

**Document Version:** 1.0.0  
**Target Platform:** Android (API level 21+)  
**Framework:** Flutter (Stable 3.47.x / Dart 3.13.x)  
**Architecture Pattern:** Clean Architecture with Riverpod & Functional Error Handling

---

## 1. Architectural Layers & Dependency Rule

The application follows strict inward dependency rules:

```
[ Presentation Layer ] (Flutter Widgets, Notifiers, State, Theme, RTL)
         │
         ▼
[ Domain Layer ] (Entities, Value Objects, Use Cases, Repository Contracts, Agronomic Formulas)
         ▲
         │
[ Infrastructure / Data Layer ] (API Clients, Providers, Repositories, Drift/SQLite Local DB)
```

### Dependency Rules:
1. **Domain Layer:** Pure Dart. Zero dependencies on Flutter UI (`dart:ui`, `package:flutter`), external HTTP clients, or local DB engines. Contains all scientific formulas, units, validation constraints, and repository interfaces.
2. **Data Layer:** Implements repository contracts defined in the Domain layer. Manages JSON parsing, network caching, local database transactions, and data adapter normalization.
3. **Presentation Layer:** Consumes Domain use cases and state notifiers. Implements Arabic-first responsive UI, Material Design 3, RTL localization, and user interaction. Strictly zero scientific calculations inside widgets.

---

## 2. Directory Structure

```
agro_shift/
├── docs/                               # Architectural and scientific specifications
├── lib/
│   ├── app/                            # Application bootstrap, routing, theme, localization
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   ├── core/                           # Cross-cutting foundational modules
│   │   ├── constants/                  # Geographical, unit, and validation constants
│   │   ├── error/                      # Failure types, exceptions, error mapper
│   │   ├── localization/               # Arabic & English strings, translations
│   │   └── utils/                      # Date/time formatting, number formatting (Arabic digits)
│   ├── domain/                         # Core enterprise & business logic (Pure Dart)
│   │   ├── agronomy/                   # Crop profiles, FAO-56 models, rotation rules
│   │   │   ├── models/                 # Crop, RotationPlan, WaterDemand, HeatStressIndex
│   │   │   └── science/                # Mathematical formulas: Penman-Monteith, GDD, Kc
│   │   ├── environment/                # Environmental metrics entities
│   │   │   ├── models/                 # DailyWeatherRecord, HistoricalTrend, Coordinate
│   │   │   └── repositories/           # IWeatherRepository, IFieldRepository
│   │   └── validation/                 # CoordinateValidator, ScientificRangeValidator
│   ├── data/                           # Data access and external adapters
│   │   ├── datasources/
│   │   │   ├── local/                  # Local database (Drift / In-memory cache)
│   │   │   └── remote/                 # Open-Meteo adapter, Future Competition API adapter
│   │   ├── models/                     # DTOs with strict JSON serialization
│   │   └── repositories/               # WeatherRepositoryImpl, FieldRepositoryImpl
│   └── presentation/                   # UI Layer
│       ├── providers/                  # Riverpod StateNotifier / AsyncNotifier providers
│       ├── screens/                    # Dashboard, Field, Environmental, RotationLab, Provenance
│       └── widgets/                    # Reusable RTL cards, badges, chart containers, error states
└── test/                               # Comprehensive unit, widget, and domain tests
```

---

## 3. Domain Model Contracts & Repository Interfaces

### 3.1 Geographic Coordinate Value Object
```dart
class Coordinate {
  final double latitude;
  final double longitude;
  final String? governorateName;

  const Coordinate({
    required this.latitude,
    required this.longitude,
    this.governorateName,
  });

  // Validates within Egypt bounds: Lat [22.0, 31.8], Lon [25.0, 37.0]
  bool get isWithinEgypt =>
      latitude >= 22.0 && latitude <= 31.8 &&
      longitude >= 25.0 && longitude <= 37.0;
}
```

### 3.2 Environmental Record Entity
```dart
class DailyAgroRecord {
  final DateTime date;
  final double maxTemperatureC;
  final double minTemperatureC;
  final double? precipitationMm; // Distinct 0.0 vs null
  final double? referenceEt0Mm;   // FAO-56 Penman-Monteith ET0
  final DataSourceProvenance provenance;

  const DailyAgroRecord({
    required this.date,
    required this.maxTemperatureC,
    required this.minTemperatureC,
    required this.precipitationMm,
    required this.referenceEt0Mm,
    required this.provenance,
  });
}
```

### 3.3 Abstract Weather Repository Contract
```dart
abstract class IWeatherRepository {
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalWeather({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Result<List<DailyAgroRecord>, Failure>> getForecastWeather({
    required Coordinate coordinate,
    required int days,
  });
}
```

---

## 4. External Data Source Adapter Strategy

To isolate external APIs (Open-Meteo, NASA POWER, and the future Space Apps competition API):
1. **Isolated Data Transfer Objects (DTOs):** `OpenMeteoDailyDto` parses vendor JSON into raw, unvalidated fields.
2. **Explicit Adapter Transformation:** `OpenMeteoAdapter.toDomain(dto)` converts DTO into domain `DailyAgroRecord`.
   - Validates that returned coordinates align with requested coordinates (within grid resolution tolerance).
   - Validates units (converts if necessary, ensuring temperature is Celsius and evapotranspiration is mm).
   - Attaches explicit `DataSourceProvenance` recording provider identity, fetch timestamp, elevation, and model identifier.
3. **Pluggable Architecture:** When the competition API is released, a new `CompetitionApiAdapter` will be implemented adhering to `IWeatherRepository` without modifying any presentation or domain logic.

---

## 5. State Management & Navigation

- **State Management:** Riverpod 2.x (`flutter_riverpod`). State is managed through typed `AsyncNotifier` classes, representing explicit loading, error, and loaded states with immutable domain models.
- **Navigation:** Declarative or robust lightweight routing (`GoRouter` or typed route table) with explicit path parameters.
- **RTL & Localization:** Flutter `MaterialApp` configured with `supportedLocales: [Locale('ar', 'EG'), Locale('en', 'US')]` and `locale: Locale('ar', 'EG')`. All layouts use `Directionality`-aware widgets (e.g. `EdgeInsetsDirectional`, `start`/`end` alignments).

---

## 6. Functional Error Handling

Errors are typed and returned explicitly via a functional `Result<T, E>` pattern (or `Either<Failure, T>`), avoiding unhandled exception crashes:

```dart
sealed class Failure {
  final String userMessageAr;
  final String technicalDetails;
  const Failure(this.userMessageAr, this.technicalDetails);
}

class NetworkFailure extends Failure { ... }
class PhysicalRangeFailure extends Failure { ... }
class InsufficientEvidenceFailure extends Failure { ... }
class CoordinateOutOfRangeFailure extends Failure { ... }
```

---

## 7. Build Configuration & Compatibility Gate

- **Platform Target:** Android only (Min SDK: 21, Target/Compile SDK: 34+).
- **Tooling:** Flutter 3.47.2 / Dart 3.13.2 stable.
- **Package Selection Policy:** Only actively maintained, stable packages with zero native iOS/macOS build requirements.
  - State: `flutter_riverpod`
  - Networking: `dio`
  - Persistence: SQLite / lightweight secure local storage
  - Visualization: `fl_chart`
