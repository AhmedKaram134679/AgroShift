/// Egypt national boundaries and agronomic physical limits.
class AgroConstants {
  AgroConstants._();

  // Geographic Bounding Box for Egypt
  static const double egyptMinLatitude = 22.0;
  static const double egyptMaxLatitude = 31.8;
  static const double egyptMinLongitude = 25.0;
  static const double egyptMaxLongitude = 37.0;

  // Temperature physical limits for Egypt (°C)
  static const double minAcceptableTempC = -5.0;
  static const double maxAcceptableTempC = 55.0;

  // FAO-56 Reference ET0 limits (mm/day)
  static const double minAcceptableEt0Mm = 0.0;
  static const double maxAcceptableEt0Mm = 25.0;

  // Precipitation limits (mm/day)
  static const double minAcceptablePrecipitationMm = 0.0;
  static const double maxAcceptablePrecipitationMm = 250.0;

  // Volumetric conversion: 1 mm depth over 1 Feddan (4200.83 m²) = 4.20083 m³
  // Standard Egyptian agricultural engineering convention: 1 mm = 4.2 m³/feddan
  static const double cubicMetersPerFeddanPerMm = 4.2;

  // Missing data tolerance: if > 10% data is missing, refuse recommendation
  static const double maxAcceptableMissingDataRatio = 0.10;
}
