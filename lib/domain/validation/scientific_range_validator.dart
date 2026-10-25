import '../../core/constants/agro_constants.dart';
import '../../core/error/failures.dart';
import '../../core/error/result.dart';

/// Validates raw scientific inputs before creating domain entities.
class ScientificRangeValidator {
  ScientificRangeValidator._();

  static Result<void, PhysicalRangeFailure> validateTemperature({
    required double tMax,
    required double tMin,
  }) {
    if (tMax.isNaN || tMax.isInfinite || tMin.isNaN || tMin.isInfinite) {
      return const FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'قيم درجات الحرارة غير عددية أو غير منتهية.',
          technicalMessage: 'Temperature value is NaN or Infinite.',
          variableName: 'temperature',
          actualValue: null,
        ),
      );
    }

    if (tMax < AgroConstants.minAcceptableTempC ||
        tMax > AgroConstants.maxAcceptableTempC) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'درجة الحرارة العظمى ($tMax°C) خارج النطاق المناخي الممكن في مصر.',
          technicalMessage: 'tMax ($tMax) is outside physical range.',
          variableName: 'tMax',
          actualValue: tMax,
        ),
      );
    }

    if (tMin < AgroConstants.minAcceptableTempC ||
        tMin > AgroConstants.maxAcceptableTempC) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'درجة الحرارة الصغرى ($tMin°C) خارج النطاق المناخي الممكن في مصر.',
          technicalMessage: 'tMin ($tMin) is outside physical range.',
          variableName: 'tMin',
          actualValue: tMin,
        ),
      );
    }

    if (tMax < tMin) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'خطأ في اتساق درجات الحرارة: العظمى ($tMax°C) أقل من الصغرى ($tMin°C).',
          technicalMessage: 'tMax cannot be strictly less than tMin.',
          variableName: 'tMax_less_than_tMin',
          actualValue: '$tMax < $tMin',
        ),
      );
    }

    return const Success(null);
  }

  static Result<void, PhysicalRangeFailure> validateEt0(double? et0) {
    if (et0 == null) return const Success(null); // Missing is allowed as null
    if (et0.isNaN || et0.isInfinite) {
      return const FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'قيمة البخر نتح المرجعي غير عددية.',
          technicalMessage: 'ET0 is NaN or Infinite.',
          variableName: 'et0',
          actualValue: null,
        ),
      );
    }
    if (et0 < AgroConstants.minAcceptableEt0Mm ||
        et0 > AgroConstants.maxAcceptableEt0Mm) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'قيمة البخر نتح المرجعي ($et0 مم/يوم) غير واقعية وغير مقبولة زراعياً.',
          technicalMessage: 'ET0 ($et0) is outside physical limits.',
          variableName: 'et0',
          actualValue: et0,
        ),
      );
    }
    return const Success(null);
  }

  static Result<void, PhysicalRangeFailure> validatePrecipitation(double? p) {
    if (p == null) return const Success(null); // Missing is allowed as null
    if (p.isNaN || p.isInfinite) {
      return const FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'قيمة هطول الأمطار غير عددية.',
          technicalMessage: 'Precipitation is NaN or Infinite.',
          variableName: 'precipitation',
          actualValue: null,
        ),
      );
    }
    if (p < AgroConstants.minAcceptablePrecipitationMm ||
        p > AgroConstants.maxAcceptablePrecipitationMm) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'قيمة هطول الأمطار ($p مم/يوم) خارج النطاق الفيزيائي المقبول.',
          technicalMessage: 'Precipitation ($p) is outside physical limits.',
          variableName: 'precipitation',
          actualValue: p,
        ),
      );
    }
    return const Success(null);
  }
}
