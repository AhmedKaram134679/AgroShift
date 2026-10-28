import 'crop.dart';

/// Standard benchmark crop dataset for Egypt's Nile Delta and Valley.
///
/// Source Traceability & Scientific Validation Disclosure:
/// - Baseline crop coefficients (kcIni, kcMid, kcEnd) are aligned with FAO Irrigation and Drainage Paper No. 56
///   (Table 12: Single crop coefficients, sub-humid climate RHmin ≈ 45%, u2 ≈ 2 m/s) and regional agronomic bulletins
///   from the Egyptian Agricultural Research Center (ARC):
///   * Wheat (Winter wheat): FAO-56 Table 12 (Small grains - Winter wheat: kcIni=0.40, kcMid=1.15, kcEnd=0.25-0.40 -> 0.35 adopted).
///   * Berseem Clover (Trifolium alexandrinum): ARC regional guidelines and FAO-56 Table 12 (Forage crops - Clover/Alfalfa cutting cycles).
///   * Faba Bean (Broad bean): FAO-56 Table 12 (Legumes - Fresh/Dry beans: kcIni=0.50, kcMid=1.15, kcEnd=0.30).
///   * Maize (Field corn): FAO-56 Table 12 (Grain maize: kcIni=0.30, kcMid=1.20, kcEnd=0.60, Tcutoff=30°C).
///   * Rice (Paddy rice): FAO-56 Table 12 (Rice paddy: kcIni=1.05, kcMid=1.20, kcEnd=0.90; reflects inundated standing water).
///   * Cotton: FAO-56 Table 12 (Cotton: kcIni=0.35, kcMid=1.15-1.20 -> 1.20, kcEnd=0.65-0.70 -> 0.65).
/// - LIMITATION: These coefficients represent unadjusted nominal values under standard sub-humid reference conditions.
///   Local micro-climatic adjustments for wind speed, minimum relative humidity (RHmin), wetting frequency, and
///   ground-truth lysimeter calibration across specific Egyptian governorates (e.g., Upper Egypt vs. North Delta)
///   are not empirically integrated in this catalog and remain DEFERRED.
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
