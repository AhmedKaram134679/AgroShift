/// Base failure class for the AgroShift application.
sealed class Failure {
  final String userMessageAr;
  final String technicalMessage;

  const Failure({required this.userMessageAr, required this.technicalMessage});

  @override
  String toString() =>
      '$runtimeType(ar: $userMessageAr, tech: $technicalMessage)';
}

/// Network failure (connection refused, timeout, offline).
final class NetworkFailure extends Failure {
  final int? statusCode;

  const NetworkFailure({
    required super.userMessageAr,
    required super.technicalMessage,
    this.statusCode,
  });
}

/// Parsing failure when response schema does not match expectation.
final class ParsingFailure extends Failure {
  const ParsingFailure({
    required super.userMessageAr,
    required super.technicalMessage,
  });
}

/// Validation failure when a value violates configured operational screening envelopes or physical consistency constraints.
final class PhysicalRangeFailure extends Failure {
  final String variableName;
  final dynamic actualValue;

  const PhysicalRangeFailure({
    required super.userMessageAr,
    required super.technicalMessage,
    required this.variableName,
    required this.actualValue,
  });
}

/// Geographic coordinate outside approved boundaries (Egypt).
final class CoordinateOutOfBoundsFailure extends Failure {
  final double latitude;
  final double longitude;

  const CoordinateOutOfBoundsFailure({
    required super.userMessageAr,
    required super.technicalMessage,
    required this.latitude,
    required this.longitude,
  });
}

/// Insufficient evidence failure: triggered when missingness > 10% or critical variables are absent.
final class InsufficientEvidenceFailure extends Failure {
  final double missingRatio;
  final String? variableName;
  final int? missingCount;
  final int? totalCount;

  const InsufficientEvidenceFailure({
    required super.userMessageAr,
    required super.technicalMessage,
    required this.missingRatio,
    this.variableName,
    this.missingCount,
    this.totalCount,
  });
}
