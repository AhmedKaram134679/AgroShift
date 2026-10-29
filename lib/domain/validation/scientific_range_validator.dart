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
              'درجة الحرارة العظمى ($tMax°C) خارج نطاق الفحص التشغيلي المعتمد في مصر [${AgroConstants.minAcceptableTempC}°C إلى ${AgroConstants.maxAcceptableTempC}°C].',
          technicalMessage:
              'tMax ($tMax) is outside configured operational screening range [${AgroConstants.minAcceptableTempC}, ${AgroConstants.maxAcceptableTempC}].',
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
              'درجة الحرارة الصغرى ($tMin°C) خارج نطاق الفحص التشغيلي المعتمد في مصر [${AgroConstants.minAcceptableTempC}°C إلى ${AgroConstants.maxAcceptableTempC}°C].',
          technicalMessage:
              'tMin ($tMin) is outside configured operational screening range [${AgroConstants.minAcceptableTempC}, ${AgroConstants.maxAcceptableTempC}].',
          variableName: 'tMin',
          actualValue: tMin,
        ),
      );
    }

    if (tMax < tMin) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'خطأ في الاتساق الفيزيائي لدرجات الحرارة: العظمى ($tMax°C) أقل من الصغرى ($tMin°C).',
          technicalMessage: 'Physical consistency violation: tMax cannot be strictly less than tMin.',
          variableName: 'tMax_less_than_tMin',
          actualValue: '$tMax < $tMin',
        ),
      );
    }

    return const Success(null);
  }

  static Result<void, PhysicalRangeFailure> validateSingleTemperature(
    double? temp, {
    String variableName = 'temperature',
  }) {
    if (temp == null) return const Success(null);
    if (!temp.isFinite) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'قيم درجات الحرارة غير عددية أو غير منتهية.',
          technicalMessage: '$variableName value is NaN or Infinite.',
          variableName: variableName,
          actualValue: null,
        ),
      );
    }

    if (temp < AgroConstants.minAcceptableTempC ||
        temp > AgroConstants.maxAcceptableTempC) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'درجة الحرارة ($temp°C) خارج نطاق الفحص التشغيلي المعتمد في مصر [${AgroConstants.minAcceptableTempC}°C إلى ${AgroConstants.maxAcceptableTempC}°C].',
          technicalMessage:
              '$variableName ($temp) is outside configured operational screening range [${AgroConstants.minAcceptableTempC}, ${AgroConstants.maxAcceptableTempC}].',
          variableName: variableName,
          actualValue: temp,
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
              'قيمة البخر نتح المرجعي ($et0 مم/يوم) خارج نطاق الفحص التشغيلي المعتمد [${AgroConstants.minAcceptableEt0Mm} إلى ${AgroConstants.maxAcceptableEt0Mm} مم/يوم].',
          technicalMessage:
              'ET0 ($et0) is outside configured operational screening range [${AgroConstants.minAcceptableEt0Mm}, ${AgroConstants.maxAcceptableEt0Mm}].',
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
              'قيمة هطول الأمطار ($p مم/يوم) خارج نطاق الفحص التشغيلي المعتمد [${AgroConstants.minAcceptablePrecipitationMm} إلى ${AgroConstants.maxAcceptablePrecipitationMm} مم/يوم].',
          technicalMessage:
              'Precipitation ($p) is outside configured operational screening range [${AgroConstants.minAcceptablePrecipitationMm}, ${AgroConstants.maxAcceptablePrecipitationMm}].',
          variableName: 'precipitation',
          actualValue: p,
        ),
      );
    }
    return const Success(null);
  }

  /// Validates that a crop coefficient Kc is finite and non-negative.
  static Result<void, PhysicalRangeFailure> validateKc(
    double kc, {
    String variableName = 'kc',
  }) {
    if (!kc.isFinite) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'معامل المحصول ($variableName) غير عددي أو غير منتهٍ.',
          technicalMessage: '$variableName is NaN or Infinite.',
          variableName: variableName,
          actualValue: null,
        ),
      );
    }
    if (kc < 0.0) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'معامل المحصول ($variableName = $kc) لا يمكن أن يكون سالباً.',
          technicalMessage: '$variableName ($kc) cannot be negative.',
          variableName: variableName,
          actualValue: kc,
        ),
      );
    }
    return const Success(null);
  }

  /// Validates that a farm field area in feddan is finite and strictly greater than zero.
  static Result<void, PhysicalRangeFailure> validateAreaInFeddan(
    double area, {
    String variableName = 'areaInFeddan',
  }) {
    if (!area.isFinite) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'مساحة الحقل غير عددية أو غير منتهية.',
          technicalMessage: '$variableName is NaN or Infinite.',
          variableName: variableName,
          actualValue: null,
        ),
      );
    }
    if (area <= 0.0) {
      return FailureResult(
        PhysicalRangeFailure(
          userMessageAr: 'مساحة الحقل يجب أن تكون أكبر من الصفر.',
          technicalMessage:
              '$variableName ($area) must be strictly greater than zero.',
          variableName: variableName,
          actualValue: area,
        ),
      );
    }
    return const Success(null);
  }

  /// Evaluates composite missingness for calculations requiring multiple variables.
  /// Counts a date as incomplete if at least one required input is missing on that date.
  /// Refuses calculation if union of incomplete dates exceeds AgroConstants.maxAcceptableMissingDataRatio (> 10%).
  static Result<void, InsufficientEvidenceFailure>
  validateCompositeMissingness({
    required int totalRequestedDays,
    required Set<int> unionOfIncompleteDateIndices,
    required String calculationLabel,
    required List<String> requiredVariables,
  }) {
    if (totalRequestedDays <= 0) {
      return const FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr: 'لا يمكن إجراء الحساب لأن الفترة المطلوبة لا تحتوي على أيام صالحة.',
          technicalMessage: 'Composite missingness validation requires totalRequestedDays > 0.',
          missingRatio: 1.0,
          variableName: 'composite_inputs',
          missingCount: 0,
          totalCount: 0,
        ),
      );
    }
    final incompleteCount = unionOfIncompleteDateIndices.length;
    final ratio = incompleteCount / totalRequestedDays;
    if (ratio > AgroConstants.maxAcceptableMissingDataRatio) {
      return FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'نسبة الأيام غير المكتملة لعملية $calculationLabel (${(ratio * 100).toStringAsFixed(1)}%) تتجاوز الحد العلمي المقبول (10%).',
          technicalMessage:
              'Composite missing ratio for $calculationLabel across union of incomplete dates ($incompleteCount/$totalRequestedDays = ${(ratio * 100).toStringAsFixed(1)}%) exceeds 10% threshold. Required variables: ${requiredVariables.join(', ')}.',
          missingRatio: ratio,
          variableName: 'composite_$calculationLabel',
          missingCount: incompleteCount,
          totalCount: totalRequestedDays,
        ),
      );
    }
    return const Success(null);
  }
}
