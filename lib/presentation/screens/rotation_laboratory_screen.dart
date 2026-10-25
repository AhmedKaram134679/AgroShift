import 'package:flutter/material.dart';
import 'package:agro_shift/domain/agronomy/science/rotation_presets.dart';
import 'package:agro_shift/domain/agronomy/science/rotation_evaluator.dart';

class RotationLaboratoryScreen extends StatefulWidget {
  const RotationLaboratoryScreen({super.key});

  @override
  State<RotationLaboratoryScreen> createState() =>
      _RotationLaboratoryScreenState();
}

class _RotationLaboratoryScreenState extends State<RotationLaboratoryScreen> {
  // Baseline estimated annual ET0 for the Nile Delta (~1450 mm/year)
  final double _baselineEt0 = 1450.0;
  String _selectedSequenceId = RotationPresets.berseemToMaize.id;

  @override
  Widget build(BuildContext context) {
    final sequences = RotationPresets.standardSequences;
    final currentSequence = sequences.firstWhere(
      (s) => s.id == _selectedSequenceId,
    );
    final evaluation = RotationEvaluator.evaluate(
      sequence: currentSequence,
      baselineAnnualEt0Mm: _baselineEt0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('مختبر مقارنة الدورات الزراعية')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Informative Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: const Text(
              'أداة المقارنة العلمية للدورات الزراعية: تتيح تقييم البصمة المائية، وأثر تعاقب المحاصيل على خصوبة التربة وتثبيت النيتروجين دون ادعاء أرقام أرباح غير مثبتة.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1B5E20),
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sequence Selector
          Text(
            'اختر الدورة الزراعية للمقارنة:',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...sequences.map((seq) {
            final isSelected = seq.id == _selectedSequenceId;
            return Card(
              color: isSelected ? const Color(0xFFF1F8E9) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE0E0E0),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: ListTile(
                title: Text(
                  seq.titleAr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'المحصول الشتوي: ${seq.firstCrop.nameAr} ⬅️ المحصول الصيفي: ${seq.secondCrop.nameAr}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                    : const Icon(Icons.circle_outlined, color: Colors.grey),
                onTap: () {
                  setState(() {
                    _selectedSequenceId = seq.id;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 16),

          // Agronomic Rationale
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الأساس العلمي للدورة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentSequence.agronomicRationaleAr,
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scientific Evaluation Dashboard
          Text(
            'نتائج التقييم الزراعي والبيئي:',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 1. Water Consumption Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.water_drop,
                    color: Color(0xFF0277BD),
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الاستهلاك المائي التقديري السنوي:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '${evaluation.estimatedAnnualWaterM3PerFeddan.toStringAsFixed(0)} م³ / فدان',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0277BD),
                          ),
                        ),
                        const Text(
                          '* بناءً على معاملات الاستهلاك التبخري لمنطقة الدلتا',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. Soil Balance Card
          _buildSoilBalanceCard(evaluation),

          const SizedBox(height: 8),

          // 3. Turnaround Days Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        evaluation.hasTurnaroundConflict
                            ? Icons.error_outline
                            : Icons.event_available,
                        color: evaluation.hasTurnaroundConflict
                            ? Colors.orange
                            : const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الفترة الفاصلة لتجهيز الأرض: ${evaluation.turnaroundDays} يوماً',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    evaluation.turnaroundNotesAr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilBalanceCard(RotationComparisonResult eval) {
    final (color, icon, title) = switch (eval.soilBalanceEffect) {
      SoilBalanceEffect.positiveEnrichment => (
        const Color(0xFF2E7D32),
        Icons.eco,
        'تأثير إيجابي: تخصيب وتثبيت نيتروجين',
      ),
      SoilBalanceEffect.neutralOrBalanced => (
        const Color(0xFFF57F17),
        Icons.change_circle,
        'تأثير متوازن ومعتدل',
      ),
      SoilBalanceEffect.cumulativeDepletion => (
        const Color(0xFFC62828),
        Icons.warning_amber,
        'تأثير مستنزف للتربة (إجهاد غذائي)',
      ),
    };

    return Card(
      color: color.withValues(alpha: 0.06),
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
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
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
              eval.soilImpactSummaryAr,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
