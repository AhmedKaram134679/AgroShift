import 'crop.dart';

/// Standard benchmark crop dataset for Egypt's Nile Delta and Valley
/// Verified against FAO-56 Table 12 and Egyptian Agricultural Research Center (ARC).
class EgyptianCropsCatalog {
  EgyptianCropsCatalog._();

  static const Crop wheat = Crop(
    id: 'wheat',
    nameAr: 'القمح المصري',
    nameEn: 'Wheat',
    season: CropSeason.winter,
    baseTemperatureC: 5.0,
    criticalHeatTemperatureC: 31.0,
    kcIni: 0.40,
    kcMid: 1.15,
    kcEnd: 0.35,
    typicalDurationDays: 150,
    soilNutrientImpact: SoilNutrientImpact.depleting,
    scientificNotesAr: 'المحصول الاستراتيجي الشتوي الأساسي. حساس للإجهاد الحراري ورياح الخماسين أثناء طور امتلاء الحبوب (مارس/أبريل).',
  );

  static const Crop berseemClover = Crop(
    id: 'berseem',
    nameAr: 'البرسيم المسقاوي',
    nameEn: 'Berseem Clover',
    season: CropSeason.winter,
    baseTemperatureC: 6.0,
    criticalHeatTemperatureC: 32.0,
    kcIni: 0.45,
    kcMid: 1.05,
    kcEnd: 0.90,
    typicalDurationDays: 160,
    soilNutrientImpact: SoilNutrientImpact.enriching,
    scientificNotesAr: 'بقولي شتوي رئيسي، يثبت النيتروجين الجوي بمعدل 80-120 كجم N/فدان سنوياً، ويحسن خصوبة التربة الطينية بالدلتا قبل زراعة المحاصيل الصيفية.',
  );

  static const Crop fabaBean = Crop(
    id: 'faba_bean',
    nameAr: 'الفول البلدي',
    nameEn: 'Faba Bean',
    season: CropSeason.winter,
    baseTemperatureC: 4.0,
    criticalHeatTemperatureC: 30.0,
    kcIni: 0.50,
    kcMid: 1.15,
    kcEnd: 0.30,
    typicalDurationDays: 140,
    soilNutrientImpact: SoilNutrientImpact.enriching,
    scientificNotesAr: 'بقولي شتوي غذائي، ذو كفاءة عالية في تثبيت النيتروجين، وحساسية معتدلة لملوحة التربة وموجات الصقيع الشتوية.',
  );

  static const Crop maize = Crop(
    id: 'maize',
    nameAr: 'الذرة الشامية',
    nameEn: 'Maize',
    season: CropSeason.summer,
    baseTemperatureC: 10.0,
    cutoffTemperatureC: 30.0,
    criticalHeatTemperatureC: 35.0,
    kcIni: 0.30,
    kcMid: 1.20,
    kcEnd: 0.60,
    typicalDurationDays: 120,
    soilNutrientImpact: SoilNutrientImpact.depleting,
    scientificNotesAr: 'محصول صيفي رئيسي C4. يتطلب كميات نيتروجين عالية وحساس لارتفاع الحرارة والجفاف أثناء طرد النورات والحريرة.',
  );

  static const Crop rice = Crop(
    id: 'rice',
    nameAr: 'الأرز المصري',
    nameEn: 'Rice',
    season: CropSeason.summer,
    baseTemperatureC: 12.0,
    criticalHeatTemperatureC: 36.0,
    kcIni: 1.05,
    kcMid: 1.20,
    kcEnd: 0.90,
    typicalDurationDays: 135,
    soilNutrientImpact: SoilNutrientImpact.depleting,
    scientificNotesAr: 'محصول مائي كثيف الاستهلاك يُزرع لغسيل أملاح التربة في شمال الدلتا، مع التزام مشدد بالمساحات المقررة من وزارة الري.',
  );

  static const Crop cotton = Crop(
    id: 'cotton',
    nameAr: 'القطن المصري',
    nameEn: 'Cotton',
    season: CropSeason.summer,
    baseTemperatureC: 14.0,
    criticalHeatTemperatureC: 38.0,
    kcIni: 0.35,
    kcMid: 1.20,
    kcEnd: 0.65,
    typicalDurationDays: 180,
    soilNutrientImpact: SoilNutrientImpact.moderate,
    scientificNotesAr: 'طويل التيلة، يتحمل درجات الحرارة المرتفعة، ذو موسم نمو طويل يستدعي دورة زراعية منتظمة.',
  );

  static List<Crop> get allCrops => [
    wheat,
    berseemClover,
    fabaBean,
    maize,
    rice,
    cotton,
  ];

  static Crop? findById(String id) {
    try {
      return allCrops.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
