import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/domain/agronomy/models/crop_catalog.dart';
import 'package:agro_shift/domain/agronomy/science/heat_stress_evaluator.dart';
import 'package:agro_shift/domain/agronomy/science/etc_calculator.dart';
import 'package:agro_shift/presentation/widgets/provenance_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeField = ref.watch(selectedFieldProvider);
    final allFields = ref.watch(fieldListProvider);
    final forecastAsync = ref.watch(fieldForecastProvider);

    if (activeField == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('أجروشيفت — لوحة المتابعة الزراعية')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.nature_people_outlined,
                  size: 64,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا يوجد حقل زراعي مسجل أو نشط حالياً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى الانتقال إلى تبويب الحقول لإضافة حقل زراعي جديد لبدء المتابعة المناخية والاحتياجات المائية.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('إضافة حقل زراعي'),
                  onPressed: () {
                    // Navigate to fields tab (tab index 3 in MainNavigationShell)
                    ref.read(navigationTabIndexProvider.notifier).setTab(3);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeCrop = activeField.activeCropId != null
        ? EgyptianCropsCatalog.findById(activeField.activeCropId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أجروشيفت — لوحة المتابعة الزراعية'),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(fieldForecastProvider);
              ref.invalidate(fieldHistorical30DaysProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fieldForecastProvider);
          ref.invalidate(fieldHistorical30DaysProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Non-guarantee science alert
            _buildScientificDisclaimerBanner(),

            const SizedBox(height: 12),

            // 2. Active Field Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF1B5E20),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الحقل الزراعي النشط:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: activeField.id,
                            underline: const SizedBox(),
                            items: allFields.map((field) {
                              return DropdownMenuItem(
                                value: field.id,
                                child: Text(
                                  '${field.nameAr} (${field.governorateAr})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null) {
                                final selected = allFields.firstWhere(
                                  (f) => f.id == newId,
                                );
                                ref
                                    .read(selectedFieldProvider.notifier)
                                    .selectField(selected);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Field Agronomic Specs Badge
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricBadge(
                      title: 'المساحة',
                      value: '${activeField.areaInFeddan} فدان',
                      icon: Icons.aspect_ratio,
                    ),
                    _metricBadge(
                      title: 'نوع التربة',
                      value: activeField.soilTypeNameAr.split(' ')[0],
                      icon: Icons.landscape,
                    ),
                    _metricBadge(
                      title: 'المحصول القائم',
                      value: activeCrop?.nameAr.split(' ')[0] ?? 'غير محدد',
                      icon: Icons.grass,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 4. Live Agro-Climatic Forecast Section
            Text(
              'توقعات الطقس الزراعي (الـ 7 أيام القادمة)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),

            forecastAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Card(
                color: const Color(0xFFFFEBEE),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'خطأ في استرجاع البيانات: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              data: (result) {
                return result.when(
                  failure: (fail) => Card(
                    color: const Color(0xFFFFF3E0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تنبيه عدم كفاية البيانات',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(fail.userMessageAr),
                        ],
                      ),
                    ),
                  ),
                  success: (records) {
                    if (records.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('لا توجد سجلات أرصاد متاحة.'),
                        ),
                      );
                    }

                    final expectedForecastDays =
                        records.first.provenance.expectedPeriodDays ??
                        records.length;
                    final totalForecastDays = records.length;
                    final availableEt0Days = records
                        .where((r) => r.referenceEt0Mm != null)
                        .length;
                    final isCompleteEt0 =
                        availableEt0Days == expectedForecastDays &&
                        totalForecastDays == expectedForecastDays;

                    // Validated Heat Stress Evaluation
                    final tMaxSeries = records
                        .map((r) => r.maxTemperatureC)
                        .toList();
                    final heatEvalResult = activeCrop != null
                        ? HeatStressEvaluator.evaluateCropHeatStressValidated(
                            crop: activeCrop,
                            totalRequestedDays: expectedForecastDays,
                            dailyTmaxSeries: tMaxSeries,
                          )
                        : null;

                    // Validated ETc Water Requirement
                    final et0Series = records
                        .map((r) => r.referenceEt0Mm)
                        .toList();
                    final etcResult = activeCrop != null
                        ? EtcCalculator.calculateCycleWaterRequirementValidated(
                            crop: activeCrop,
                            totalRequestedDays: expectedForecastDays,
                            dailyEt0Series: et0Series,
                          )
                        : null;

                    final totalForecastEt0 = records
                        .where((r) => r.referenceEt0Mm != null)
                        .fold(0.0, (acc, r) => acc + r.referenceEt0Mm!);

                    final volumetricDemandM3 =
                        etcResult?.dataOrNull?.totalVolumeM3PerFeddan;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heat stress assessment or validation failure alert
                        if (heatEvalResult != null)
                          heatEvalResult.when(
                            failure: (failure) => Card(
                              color: const Color(0xFFFFF3E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFFFB74D),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFE65100),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'تعذر تقييم الإجهاد الحراري — بيانات غير مكتملة',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFFE65100),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            failure.userMessageAr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            success: (eval) => _buildHeatStressCard(eval),
                          ),

                        const SizedBox(height: 8),

                        // 1. Independent Reference Evapotranspiration (ET₀) Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.water_drop_outlined,
                                      color: Color(0xFF0277BD),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isCompleteEt0
                                            ? 'البخر نتح المرجعي (ET₀) — فترة $expectedForecastDays أيام'
                                            : 'البخر نتح المرجعي (ET₀) — مجموع جزئي ($availableEt0Days من $expectedForecastDays أيام مطلوبة)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (availableEt0Days == 0)
                                  const Text(
                                    'لا توجد قراءات صالحة للبخر نتح المرجعي (ET₀) خلال الفترة المطلوبة.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFC62828),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else ...[
                                  Text(
                                    isCompleteEt0
                                        ? 'مجموع البخر نتح المرجعي (ET₀): ${totalForecastEt0.toStringAsFixed(1)} مم'
                                        : 'مجموع جزئي للبخر نتح المرجعي ($availableEt0Days من أصل $expectedForecastDays يوماً مطلوبة): ${totalForecastEt0.toStringAsFixed(1)} مم',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!isCompleteEt0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'تنبيه: التوقعات غير مكتملة لكامل الفترة (${expectedForecastDays - availableEt0Days} أيام بدون قراءة ET₀ صالحة من أصل $expectedForecastDays يوماً). المجموع المعروض يمثل الأيام المتوفرة فقط.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 2. Crop-specific Evapotranspiration (ETc) & Irrigation Demand Card
                        if (activeCrop == null)
                          Card(
                            color: const Color(0xFFF5F5F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.blueGrey,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'يرجى تحديد المحصول القائم للحقل لحساب الاحتياج المائي الفعلي للمحصول (ETc).',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (etcResult != null && etcResult.isFailure)
                          Card(
                            color: const Color(0xFFFFF3E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFFFB74D)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFE65100),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'تعذر حساب الاحتياج المائي (ETc) — بيانات غير مكتملة',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFFE65100),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          etcResult
                                              .failureOrNull!
                                              .userMessageAr,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (etcResult != null && etcResult.isSuccess)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.water_drop,
                                        color: Color(0xFF0277BD),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'الاستهلاك المائي التبخري للمحصول (ETc) — ${activeCrop.nameAr.split(' ')[0]}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isCompleteEt0
                                        ? 'الاستهلاك المائي الصافي للمحصول: ${etcResult.dataOrNull!.totalEtcMm.toStringAsFixed(1)} مم'
                                        : 'استهلاك مائي جزئي للمحصول ($availableEt0Days من $expectedForecastDays أيام): ${etcResult.dataOrNull!.totalEtcMm.toStringAsFixed(1)} مم',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  if (volumetricDemandM3 != null)
                                    Text(
                                      isCompleteEt0
                                          ? 'حجم البخر نتح التقديري للمحصول (${activeCrop.nameAr.split(' ')[0]}): ${volumetricDemandM3.toStringAsFixed(0)} م³ / فدان'
                                          : 'حجم البخر نتح التقديري الجزئي للمحصول (${activeCrop.nameAr.split(' ')[0]} - للأيام المتوفرة): ${volumetricDemandM3.toStringAsFixed(0)} م³ / فدان',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0277BD),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '* يمثل الاستهلاك التبخري الصافي للمحصول (ETc = Kc × ET₀) وفق مراحل النمو الفسيولوجي المعتمدة من منظمة FAO. لا يمثل هذا الرقم المقنن المائي الإجمالي للحقل، حيث يتطلب الري الحقلي الفعلي إضافة فواقد كفاءة شبكة الري وتوزيع المياه واحتياجات الغسيل الملحي.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Data provenance badge
                        ProvenanceCard(provenance: records.first.provenance),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScientificDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تنبيه علمي معتمد: التطبيق أداة تحليل ودعم قرار زراعي ولا يقدم ضمانات يقينية للإنتاجية أو الأرباح المالية. تعتمد التقديرات على نماذج الأرصاد الشبكية ومعاملات منظمة الأغذية والزراعة (FAO).',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF5D4037),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1B5E20), size: 22),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHeatStressCard(
    ({
      String agronomicAdviceAr,
      double peakObservedTempC,
      HeatRiskLevel riskLevel,
      int totalExceedanceDays,
    })
    eval,
  ) {
    final (color, icon) = switch (eval.riskLevel) {
      HeatRiskLevel.low => (
        const Color(0xFF2E7D32),
        Icons.check_circle_outline,
      ),
      HeatRiskLevel.moderate => (const Color(0xFFF57F17), Icons.warning_amber),
      HeatRiskLevel.high => (const Color(0xFFE65100), Icons.error_outline),
      HeatRiskLevel.severe => (
        const Color(0xFFC62828),
        Icons.dangerous_outlined,
      ),
    };

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  'مؤشر الإجهاد الحراري للمحصول:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'أيام تجاوز الحد الحرج: ${eval.totalExceedanceDays} يوم | أعلى حرارة متوقعة: ${eval.peakObservedTempC.toStringAsFixed(1)}°C',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              eval.agronomicAdviceAr,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
