import 'package:agro_shift/core/constants/agro_constants.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';

/// Immutable geographic coordinate representing a field location.
class Coordinate {
  final double latitude;
  final double longitude;
  final String? governorateName;

  const Coordinate({
    required this.latitude,
    required this.longitude,
    this.governorateName,
  });

  /// Validates whether the coordinate is within Egypt's approximate operational bounding box envelope.
  Result<Coordinate, CoordinateOutOfBoundsFailure> validate() {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < AgroConstants.egyptMinLatitude ||
        latitude > AgroConstants.egyptMaxLatitude ||
        longitude < AgroConstants.egyptMinLongitude ||
        longitude > AgroConstants.egyptMaxLongitude) {
      return FailureResult(
        CoordinateOutOfBoundsFailure(
          userMessageAr:
              'الإحداثيات المدخلة تقع خارج النطاق الجغرافي المعتمد لجمهورية مصر العربية '
              '(نطاق تقريبي: خط العرض 22.0 إلى 31.8 شمالاً، خط الطول 25.0 إلى 37.0 شرقاً).',
          technicalMessage:
              'Coordinate ($latitude, $longitude) is outside Egypt operational bounding box envelope.',
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
    return Success(this);
  }

  bool get isWithinEgypt =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= AgroConstants.egyptMinLatitude &&
      latitude <= AgroConstants.egyptMaxLatitude &&
      longitude >= AgroConstants.egyptMinLongitude &&
      longitude <= AgroConstants.egyptMaxLongitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinate &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'Coordinate(lat: $latitude, lon: $longitude, gov: $governorateName)';
}
