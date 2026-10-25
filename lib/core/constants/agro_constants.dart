/// Egypt operational screening envelopes and agronomic constants.
class AgroConstants {
  AgroConstants._();

  // Approximate Geographic Bounding Box Envelope for Egypt.
  // Note: This defines an operational bounding screening box (lat: 22.0 to 31.8°N, lon: 25.0 to 37.0°E)
  // for geospatial screening and coordinate sanity checks. It does not constitute a legal or political
  // polygon boundary of the Arab Republic of Egypt.
  static const double egyptMinLatitude = 22.0;
  static const double egyptMaxLatitude = 31.8;
  static const double egyptMinLongitude = 25.0;
  static const double egyptMaxLongitude = 37.0;

  // Operational temperature screening envelope for Egypt (°C)
  // Screening limits encompassing Sinai frost (-5°C) to Western Desert summer peaks (+55°C).
  static const double minAcceptableTempC = -5.0;
  static const double maxAcceptableTempC = 55.0;

  // Operational FAO-56 Reference ET0 screening envelope (mm/day)
  // Non-negative lower physical limit up to hyper-arid summer advective peak demand (25 mm/day).
  static const double minAcceptableEt0Mm = 0.0;
  static const double maxAcceptableEt0Mm = 25.0;

  // Operational daily precipitation screening envelope (mm/day)
  // Non-negative lower physical limit up to extreme convective flash-flood burst ceiling (250 mm/day).
  static const double minAcceptablePrecipitationMm = 0.0;
  static const double maxAcceptablePrecipitationMm = 250.0;

  // Volumetric conversion: 1 mm depth over 1 Feddan (4200.83 m²) = 4.20083 m³
  // Standard Egyptian agricultural engineering convention: 1 mm = 4.2 m³/feddan
  static const double cubicMetersPerFeddanPerMm = 4.2;

  // Missing data tolerance: if > 10% data is missing, refuse recommendation
  static const double maxAcceptableMissingDataRatio = 0.10;
}
