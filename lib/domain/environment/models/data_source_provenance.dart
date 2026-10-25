/// Preserves full scientific traceability of any observation or model output.
class DataSourceProvenance {
  final String providerName;
  final String datasetName;
  final double requestedLatitude;
  final double requestedLongitude;
  final double gridLatitude;
  final double gridLongitude;
  final double? gridElevationMeters;
  final DateTime acquisitionTimestamp;
  final String scientificDisclaimerAr;
  final bool isStaleFallback;
  final int? expectedPeriodDays;

  const DataSourceProvenance({
    required this.providerName,
    required this.datasetName,
    required this.requestedLatitude,
    required this.requestedLongitude,
    required this.gridLatitude,
    required this.gridLongitude,
    this.gridElevationMeters,
    required this.acquisitionTimestamp,
    this.scientificDisclaimerAr = 'البيانات مستمدة من نماذج شبكية مُعاد تحليلها وتخضع لعدم يقين التقدير المكاني ولا تمثل قياسات محطة أرضية دقيقة.',
    this.isStaleFallback = false,
    this.expectedPeriodDays,
  });

  @override
  String toString() =>
      'DataSourceProvenance(provider: $providerName, dataset: $datasetName, grid: ($gridLatitude, $gridLongitude))';
}
