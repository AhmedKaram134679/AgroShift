import 'package:agro_shift/domain/environment/models/coordinate.dart';

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

  const FarmField({
    required this.id,
    required this.nameAr,
    required this.governorateAr,
    required this.coordinate,
    required this.areaInFeddan,
    required this.soilType,
    this.activeCropId,
  });

  String get soilTypeNameAr => switch (soilType) {
    SoilType.clay => 'طينية ثقيلة (دلتا قديمة)',
    SoilType.clayLoam => 'طميية طينية (وادي النيل)',
    SoilType.sandyLoam => 'طميية رملية (أراضي جديدة)',
    SoilType.sandy => 'رملية صحراوية',
  };
}
