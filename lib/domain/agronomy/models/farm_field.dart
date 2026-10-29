import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';

enum SoilType {
  clay, // طينية ثقيلة (الدلتا القديمة)
  clayLoam, // طميية طينية (وادي النيل)
  sandyLoam, // طميية رملية (الأراضي الجديدة)
  sandy, // رملية (الظهير الصحراوي)
}

/// Domain entity representing a registered Egyptian agricultural field parcel.
class FarmField {
  final String id;
  final String nameAr;
  final String governorateAr;
  final Coordinate coordinate;
  final double areaInFeddan;
  final SoilType soilType;
  final String? activeCropId;
  final DateTime? plantingDate;

  const FarmField({
    required this.id,
    required this.nameAr,
    required this.governorateAr,
    required this.coordinate,
    required this.areaInFeddan,
    required this.soilType,
    this.activeCropId,
    this.plantingDate,
  });

  /// Validates core physical invariants of the farm field parcel.
  Result<FarmField, Failure> validate() {
    final coordVal = coordinate.validate();
    if (coordVal.isFailure) {
      return FailureResult(coordVal.failureOrNull!);
    }
    final areaVal = ScientificRangeValidator.validateAreaInFeddan(areaInFeddan);
    if (areaVal.isFailure) {
      return FailureResult(areaVal.failureOrNull!);
    }
    return Success(this);
  }

  String get soilTypeNameAr => switch (soilType) {
    SoilType.clay => 'طينية ثقيلة (دلتا قديمة)',
    SoilType.clayLoam => 'طميية طينية (وادي النيل)',
    SoilType.sandyLoam => 'طميية رملية (أراضي جديدة)',
    SoilType.sandy => 'رملية صحراوية',
  };
}
