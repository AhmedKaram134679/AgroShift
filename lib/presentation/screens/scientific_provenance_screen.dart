import 'package:flutter/material.dart';

class ScientificProvenanceScreen extends StatelessWidget {
  const ScientificProvenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنهجية العلمية والمصادر المعتمدة')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Text(
                        'ميثاق النزاهة العلمية لتطبيق AgroShift',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تم بناء كافة نماذج التحليل الحسابي والفسيولوجي بالاعتماد الحصري على المعادلات الفيزيائية المعتمدة من منظمة الأغذية والزراعة (FAO) ونشرات مركز البحوث الزراعية المصري (ARC)، دون استخدام تنبؤات عشوائية أو ادعاء دقة محطات رصد أرضية من بيانات شبكية.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 1. FAO-56 Penman-Monteith
          _citationCard(
            title: '1. معادلة البخر نتح المرجعي (FAO-56 Penman-Monteith)',
            reference: 'Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). Crop evapotranspiration: Guidelines for computing crop water requirements. FAO Irrigation and Drainage Paper 56, Rome.',
            details: 'تستخدم لحساب البخر نتح القياسي (ET₀) بناءً على الإشعاع الشمسي الصافي، درجة حرارة الهواء، سرعة الرياح، وضغط بخار الماء المشبع والفعلي. يتم الحساب داخلياً بوحدات مم/يوم وتتحول حجمياً إلى 4.2 م³/فدان لكل 1 مم عمق ماء.',
          ),

          const SizedBox(height: 12),

          // 2. Growing Degree Days
          _citationCard(
            title: '2. وحدات الحرارة المتجمعة (Growing Degree Days - GDD)',
            reference: 'McMaster, G. S., & Wilhelm, W. W. (1997). Growing degree-days: one equation, two interpretations. Agricultural and Forest Meteorology, 87(4), 291-300.',
            details: 'لحساب التطور الفسيولوجي للمحصول مع تطبيق حد القطع الحراري الأعلى (Cutoff = 30°C) لمحصول الذرة الشامية لتفادي التقدير الزائد للنمو في درجات الحرارة القاسية.',
          ),

          const SizedBox(height: 12),

          // 3. ARC Egypt Crop Coefficients
          _citationCard(
            title: '3. معاملات المحاصيل المصرية (ARC Egypt & FAO Kc Stages)',
            reference: 'نشرات معهد بحوث الأراضي والمياه والبيئة - مركز البحوث الزراعية، الجيزة، مصر (المقررات المائية للمحاصيل الحقلية).',
            details: 'تمت معايرة أطوار النمو ومعاملات الاستهلاك المائي (Kc_ini, Kc_mid, Kc_end) وفق التوصيات المعتمدة لمحاصيل وادي النيل والدلتا.',
          ),

          const SizedBox(height: 12),

          // 4. Uncertainty & Limitations
          Card(
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'حدود ومحددات عدم اليقين (Uncertainties):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _bulletPoint(
                    'بيانات الأرصاد الشبكية (ERA5 بدقة ~25 كم / 0.25°) تمثل متوسط المربع الشبكي وليس نقطة الحقل بالتحديد.',
                  ),
                  _bulletPoint(
                    'تطابق نموذجين مناخيين (مثل Open-Meteo و NASA POWER) لا يُعد دليلاً قاطعاً على الحقيقة الأرضية (Ground Truth).',
                  ),
                  _bulletPoint(
                    'لا يقدم التطبيق أي ضمانات لغلة الفدان بالأردب أو الطن نظراً لتأثرها بعوامل متباينة كالآفات، نوعية مياه الري، وإدارة التسميد.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _citationCard({
    required String title,
    required String reference,
    required String details,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reference,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF424242),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(fontSize: 12, height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
