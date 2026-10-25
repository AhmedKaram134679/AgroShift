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

                    // Compute summary metrics
                    final tMaxList = records
                        .map((r) => r.maxTemperatureC)
                        .whereType<double>()
                        .toList();
                    final heatEval = activeCrop != null
                        ? HeatStressEvaluator.evaluateCropHeatStress(
                            crop: activeCrop,
                            dailyTmaxSeries: tMaxList,
                          )
                        : null;

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

                    final totalForecastEt0 = records
                        .where((r) => r.referenceEt0Mm != null)
                        .fold(0.0, (acc, r) => acc + r.referenceEt0Mm!);

                    final volumetricDemandM3 =
                        EtcCalculator.convertMmToCubicMetersPerFeddan(
                          activeCrop != null
                              ? totalForecastEt0 * activeCrop.kcMid
                              : totalForecastEt0,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heat stress warning card
                        if (heatEval != null) _buildHeatStressCard(heatEval),

                        const SizedBox(height: 8),

                        // Evapotranspiration and water requirement
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
                                        isCompleteEt0
                                            ? 'الاستهلاك المائي التبخري للمحصول (ETc) — فترة $expectedForecastDays أيام'
                                            : 'الاستهلاك المائي التبخري للمحصول (ETc) — مجموع جزئي ($availableEt0Days من $expectedForecastDays أيام مطلوبة)',
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
                                      ? 'مجموع البخر نتح المرجعي (ET₀): ${totalForecastEt0.toStringAsFixed(1)} مم'
                                      : 'مجموع جزئي للبخر نتح المرجعي ($availableEt0Days من أصل $expectedForecastDays يوماً مطلوبة): ${totalForecastEt0.toStringAsFixed(1)} مم',
                                  style: const TextStyle(fontSize: 13),
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
                                const SizedBox(height: 4),
                                Text(
                                  isCompleteEt0
                                      ? 'حجم البخر نتح التقديري للمحصول: ${volumetricDemandM3.toStringAsFixed(0)} م³ / فدان'
                                      : 'حجم البخر نتح التقديري الجزئي (للأيام المتوفرة): ${volumetricDemandM3.toStringAsFixed(0)} م³ / فدان',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0277BD),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '* يمثل الاستهلاك التبخري الصافي للمحصول (ETc = Kc × ET₀) خلال فترة التوقعات (7 أيام). لا يمثل هذا الرقم المقنن المائي الإجمالي للحقل، حيث يتطلب الري الحقلي الفعلي إضافة فواقد كفاءة شبكة الري وتوزيع المياه واحتياجات الغسيل الملحي.',
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
