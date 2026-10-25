import '../models/crop_catalog.dart';
import 'rotation_evaluator.dart';

/// Predefined representative Egyptian rotation archetypes for the Nile Delta & Valley.
class RotationPresets {
  RotationPresets._();

  /// Traditional Delta Balanced Rotation: Berseem Clover -> Summer Maize
  static const RotationSequence berseemToMaize = RotationSequence(
    id: 'berseem_maize',
    titleAr: 'دورة البرسيم المسقاوي ثم الذرة الشامية',
    firstCrop: EgyptianCropsCatalog.berseemClover,
    secondCrop: EgyptianCropsCatalog.maize,
    agronomicRationaleAr: 'الدورة المثالية للتربة الطينية: البرسيم يثبت النيتروجين ويفكك التربة، مما يدعم النمو الخضري للذرة الشامية ويقلل التسميد الآزوتي.',
  );

  /// Cereal Intensive Rotation: Wheat -> Summer Maize
  static const RotationSequence wheatToMaize = RotationSequence(
    id: 'wheat_maize',
    titleAr: 'دورة القمح ثم الذرة الشامية (حبوب مكثفة)',
    firstCrop: EgyptianCropsCatalog.wheat,
    secondCrop: EgyptianCropsCatalog.maize,
    agronomicRationaleAr: 'شائعة جداً لتأمين الحبوب والسيلاج، لكنها مستنزفة للنيتروجين والمادة العضوية في التربة وتتطلب تسميداً تعويضياً مدروساً.',
  );

  /// Water Intensive Rice Rotation: Wheat -> Summer Rice
  static const RotationSequence wheatToRice = RotationSequence(
    id: 'wheat_rice',
    titleAr: 'دورة القمح ثم الأرز (استهلاك مائي عالٍ)',
    firstCrop: EgyptianCropsCatalog.wheat,
    secondCrop: EgyptianCropsCatalog.rice,
    agronomicRationaleAr: 'تُطبق أساساً في شمال الدلتا لغسيل الأملاح المتراكمة وصد التداخل المالح للبحر المتوسط، مع استهلاك مائي يفوق 7000 م³ / فدان.',
  );

  /// Food Legume Rotation: Faba Bean -> Summer Maize
  static const RotationSequence fabaBeanToMaize = RotationSequence(
    id: 'faba_maize',
    titleAr: 'دورة الفول البلدي ثم الذرة الشامية',
    firstCrop: EgyptianCropsCatalog.fabaBean,
    secondCrop: EgyptianCropsCatalog.maize,
    agronomicRationaleAr: 'توازن غذائي واقتصادي عالي: توفير بروتين نباتي للمائدة وتسميد حيوي عضوي يدعم محصول الذرة الصيفي.',
  );

  static List<RotationSequence> get standardSequences => [
    berseemToMaize,
    wheatToMaize,
    wheatToRice,
    fabaBeanToMaize,
  ];
}
