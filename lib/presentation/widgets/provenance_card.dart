import 'package:flutter/material.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:intl/intl.dart';

/// Reusable card displaying full scientific provenance and uncertainty caveats.
class ProvenanceCard extends StatelessWidget {
  final DataSourceProvenance provenance;

  const ProvenanceCard({super.key, required this.provenance});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm UTC');

    return Card(
      color: const Color(0xFFF1F6EE),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provenance.isStaleFallback
                      ? Icons.cloud_off_outlined
                      : Icons.verified_outlined,
                  color: provenance.isStaleFallback
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  provenance.isStaleFallback
                      ? 'بيانات مخزنة سابقة (أوفلاين)'
                      : 'المصدر وبيانات التتبع العلمي (Provenance)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: provenance.isStaleFallback
                        ? const Color(0xFFE65100)
                        : const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('المزود:', provenance.providerName),
            _infoRow(
              'مجموعة البيانات:',
              provenance.isStaleFallback
                  ? '${provenance.datasetName} (نسخة مخزنة دون اتصال)'
                  : provenance.datasetName,
            ),
            _infoRow(
              'الإحداثيات المطلوبة للحقل:',
              '${provenance.requestedLatitude.toStringAsFixed(4)}°N, ${provenance.requestedLongitude.toStringAsFixed(4)}°E',
            ),
            _infoRow(
              'إحداثيات خلية الشبكة (Grid):',
              '${provenance.gridLatitude.toStringAsFixed(4)}°N, ${provenance.gridLongitude.toStringAsFixed(4)}°E',
            ),
            if (provenance.gridElevationMeters != null)
              _infoRow(
                'منسوب سطح الشبكة:',
                '${provenance.gridElevationMeters!.toStringAsFixed(1)} متر',
              ),
            _infoRow(
              'توقيت الاسترجاع:',
              dateFormat.format(provenance.acquisitionTimestamp),
            ),
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    provenance.scientificDisclaimerAr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF5D4037),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF212121)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
