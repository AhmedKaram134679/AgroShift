import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/presentation/widgets/provenance_card.dart';
import 'package:intl/intl.dart';

class EnvironmentalAnalysisScreen extends ConsumerWidget {
  const EnvironmentalAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeField = ref.watch(selectedFieldProvider);
    final historyAsync = ref.watch(fieldHistorical30DaysProvider);

    return Scaffold(
      appBar: AppBar(title: Text('التحليل المناخي — ${activeField.nameAr}')),
      body: historyAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('جاري استرجاع السجلات التاريخية من نموذج ERA5-Land...'),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (result) {
          return result.when(
            failure: (fail) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(fail.userMessageAr, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            success: (records) {
              if (records.isEmpty) {
                return const Center(
                  child: Text('لا تتوفر سجلات مناخية لهذه الفترة.'),
                );
              }

              final dateFormat = DateFormat('MM/dd');

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Title Header
                  Text(
                    'مسار درجات الحرارة (الـ 30 يوماً الماضية)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'مقارنة بين درجات الحرارة العظمى والصغرى اليومية (°C)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Line Chart for Temperatures
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (val, meta) {
                                    final index = val.toInt();
                                    if (index >= 0 && index < records.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Text(
                                          dateFormat.format(
                                            records[index].date,
                                          ),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (val, meta) {
                                    return Text(
                                      '${val.toInt()}°',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              // Tmax line (Red/Amber)
                              LineChartBarData(
                                spots: List.generate(
                                  records.length,
                                  (i) => FlSpot(
                                    i.toDouble(),
                                    records[i].maxTemperatureC,
                                  ),
                                ),
                                isCurved: true,
                                color: const Color(0xFFD32F2F),
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                              ),
                              // Tmin line (Blue)
                              LineChartBarData(
                                spots: List.generate(
                                  records.length,
                                  (i) => FlSpot(
                                    i.toDouble(),
                                    records[i].minTemperatureC,
                                  ),
                                ),
                                isCurved: true,
                                color: const Color(0xFF1976D2),
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendItem(
                        color: const Color(0xFFD32F2F),
                        label: 'العظمى (Tmax)',
                      ),
                      const SizedBox(width: 24),
                      _legendItem(
                        color: const Color(0xFF1976D2),
                        label: 'الصغرى (Tmin)',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Evapotranspiration ET0 Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water, color: Color(0xFF0277BD)),
                              const SizedBox(width: 8),
                              Text(
                                'معدل البخر نتح المرجعي التراكمي (ET₀)',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إجمالي الفاقد البخري خلال 30 يوماً: ${_calculateTotalEt0(records).toStringAsFixed(1)} مم',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المعادل الحجمي النظري للبخر المرجعي: ${(_calculateTotalEt0(records) * 4.2).toStringAsFixed(0)} م³ / فدان',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0277BD),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '* يعبر عن البخر نتح المرجعي لسطح حشائش قياسي (ET₀) ولا يمثل المقنن المائي لمحصول معين أو الحقل الفعلي.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Provenance
                  ProvenanceCard(provenance: records.first.provenance),
                ],
              );
            },
          );
        },
      ),
    );
  }

  double _calculateTotalEt0(List<dynamic> records) {
    double total = 0.0;
    for (final r in records) {
      if (r.referenceEt0Mm != null) {
        total += r.referenceEt0Mm!;
      }
    }
    return total;
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
