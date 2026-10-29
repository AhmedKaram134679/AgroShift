import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/agronomy/models/crop_catalog.dart';

class FieldManagementScreen extends ConsumerStatefulWidget {
  const FieldManagementScreen({super.key});

  @override
  ConsumerState<FieldManagementScreen> createState() =>
      _FieldManagementScreenState();
}

class _FieldManagementScreenState extends ConsumerState<FieldManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _govController = TextEditingController(text: 'كفر الشيخ');
  final _latController = TextEditingController(text: '31.10');
  final _lonController = TextEditingController(text: '30.95');
  final _areaController = TextEditingController(text: '5.0');

  String _soilTypeName(SoilType s) => switch (s) {
    SoilType.clay => 'طينية ثقيلة (دلتا قديمة)',
    SoilType.clayLoam => 'طميية طينية (وادي النيل)',
    SoilType.sandyLoam => 'طميية رملية (أراضي جديدة)',
    SoilType.sandy => 'رملية صحراوية',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _govController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _showAddFieldDialog() {
    _nameController.clear();
    _govController.text = 'كفر الشيخ';
    _latController.text = '31.10';
    _lonController.text = '30.95';
    _areaController.text = '5.0';
    var selectedSoil = SoilType.clay;
    var selectedCropId = 'wheat';
    DateTime? selectedPlantingDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.add_location_alt, color: Color(0xFF1B5E20)),
                    SizedBox(width: 8),
                    Text(
                      'إضافة حقل زراعي جديد في مصر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'اسم الحقل / المزرعة',
                              hintText: 'مثال: مزرعة الأمل',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'يرجى إدخال اسم الحقل'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _govController,
                            decoration: InputDecoration(
                              labelText: 'المحافظة (مثال: كفر الشيخ، المنيا)',
                              hintText: 'مثال: كفر الشيخ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'يرجى إدخال اسم المحافظة'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'خط العرض (22 - 31.8)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (v) {
                                    final d = double.tryParse(v ?? '');
                                    if (d == null || d < 22.0 || d > 31.8) {
                                      return 'خط عرض غير صحيح لمصر';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _lonController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'خط الطول (25 - 37)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (v) {
                                    final d = double.tryParse(v ?? '');
                                    if (d == null || d < 25.0 || d > 37.0) {
                                      return 'خط طول غير صحيح لمصر';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _areaController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'المساحة (بالفدان)',
                              hintText: 'مثال: 5.0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return 'قيمة غير صحيحة';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<SoilType>(
                            initialValue: selectedSoil,
                            decoration: InputDecoration(
                              labelText: 'نوع التربة',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: SoilType.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(_soilTypeName(s)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedSoil = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCropId,
                            decoration: InputDecoration(
                              labelText: 'المحصول القائم',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('بدون محصول (غير محدد)'),
                              ),
                              ...EgyptianCropsCatalog.allCrops.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.nameAr} (${c.nameEn})'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedCropId = val ?? '';
                                if (selectedCropId.isEmpty) {
                                  selectedPlantingDate = null;
                                }
                              });
                            },
                          ),
                          if (selectedCropId.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'تاريخ زراعة المحصول',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          selectedPlantingDate != null
                                              ? DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(selectedPlantingDate!)
                                              : 'غير محدد (انقر للاختيار)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: selectedPlantingDate != null
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedPlantingDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setDialogState(
                                          () => selectedPlantingDate = null,
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.calendar_month),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: dialogCtx,
                                        initialDate:
                                            selectedPlantingDate ?? now,
                                        firstDate: now.subtract(
                                          const Duration(days: 365),
                                        ),
                                        lastDate: now,
                                      );
                                      if (picked != null) {
                                        setDialogState(
                                          () => selectedPlantingDate = picked,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final newField = FarmField(
                          id: 'field_${DateTime.now().millisecondsSinceEpoch}',
                          nameAr: _nameController.text.trim(),
                          governorateAr: _govController.text.trim(),
                          coordinate: Coordinate(
                            latitude: double.parse(_latController.text),
                            longitude: double.parse(_lonController.text),
                            governorateName: _govController.text.trim(),
                          ),
                          areaInFeddan: double.parse(_areaController.text),
                          soilType: selectedSoil,
                          activeCropId: selectedCropId.isNotEmpty
                              ? selectedCropId
                              : null,
                          plantingDate: selectedCropId.isNotEmpty
                              ? selectedPlantingDate
                              : null,
                        );

                        final addRes = await ref
                            .read(fieldListProvider.notifier)
                            .addField(newField);
                        if (!mounted || !ctx.mounted) return;
                        if (addRes.isSuccess) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل الحقل الزراعي بنجاح'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                addRes.failureOrNull?.userMessageAr ??
                                    'خطأ في التسجيل',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('حفظ الحقل'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCropDialog(FarmField field) {
    String currentCropId = field.activeCropId ?? '';
    DateTime? currentPlantingDate = field.plantingDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(
                  'تحديث محصول وتاريخ زراعة ${field.nameAr}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: currentCropId,
                        decoration: InputDecoration(
                          labelText: 'المحصول القائم',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('بدون محصول (إلغاء المحصول)'),
                          ),
                          ...EgyptianCropsCatalog.allCrops.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.nameAr} (${c.nameEn})'),
                            );
                          }),
                        ],
                        onChanged: (newCrop) {
                          setDialogState(() {
                            currentCropId = newCrop ?? '';
                            // Rule 8: If active crop changes, do not silently retain previous crop's planting date
                            if (currentCropId != field.activeCropId) {
                              currentPlantingDate = null;
                            } else {
                              currentPlantingDate = field.plantingDate;
                            }
                          });
                        },
                      ),
                      if (currentCropId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Color(0xFF1B5E20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'تاريخ زراعة المحصول',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      currentPlantingDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                                .format(currentPlantingDate!)
                                          : 'غير محدد (انقر للاختيار)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: currentPlantingDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentPlantingDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setDialogState(
                                      () => currentPlantingDate = null,
                                    );
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_month),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: currentPlantingDate ?? now,
                                    firstDate: now.subtract(
                                      const Duration(days: 365),
                                    ),
                                    lastDate: now,
                                  );
                                  if (picked != null) {
                                    setDialogState(
                                      () => currentPlantingDate = picked,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final updateRes = await ref
                          .read(fieldListProvider.notifier)
                          .updateCropAndPlantingDate(
                            fieldId: field.id,
                            newCropId: currentCropId.isNotEmpty
                                ? currentCropId
                                : null,
                            newPlantingDate: currentCropId.isNotEmpty
                                ? currentPlantingDate
                                : null,
                          );
                      if (!mounted || !ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (updateRes.isSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم تحديث المحصول وتاريخ الزراعة بنجاح',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              updateRes.failureOrNull?.userMessageAr ??
                                  'خطأ في التحديث',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(fieldListProvider);
    final activeField = ref.watch(selectedFieldProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الحقول والمواقع الزراعية')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('إضافة حقل'),
        onPressed: _showAddFieldDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'الحقول المسجلة في مصر (${fields.length}):',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (fields.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.nature_people_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد حقول مسجلة حالياً',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'انقر على "إضافة حقل" بالأسفل لإنشاء موقعك الزراعي الأول.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...fields.map((f) {
              final isActive = f.id == activeField?.id;
              final crop = f.activeCropId != null
                  ? EgyptianCropsCatalog.findById(f.activeCropId!)
                  : null;

              return Card(
                elevation: isActive ? 2 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isActive
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE0E0E0),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Avatar + Field Name & Governorate + Active / Activate Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isActive
                                ? const Color(0xFF1B5E20)
                                : Colors.grey.shade300,
                            foregroundColor: isActive
                                ? Colors.white
                                : Colors.black87,
                            child: const Icon(Icons.agriculture, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.nameAr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      f.governorateAr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'الحقل النشط',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F8E9),
                                foregroundColor: const Color(0xFF1B5E20),
                                elevation: 0,
                                side: const BorderSide(
                                  color: Color(0xFFC8E6C9),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ref
                                    .read(selectedFieldProvider.notifier)
                                    .selectField(f);
                              },
                              child: const Text(
                                'تفعيل',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Details Container: Area, Coordinates, Crop, Planting Date
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FBF7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8ECE5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.straighten,
                                        size: 15,
                                        color: Color(0xFF5D4037),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${f.areaInFeddan} فدان',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.gps_fixed,
                                        size: 15,
                                        color: Color(0xFF5D4037),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '\u200E${f.coordinate.latitude.toStringAsFixed(2)}°N, ${f.coordinate.longitude.toStringAsFixed(2)}°E\u200E',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.eco_outlined,
                                  size: 15,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    crop != null
                                        ? 'المحصول: ${crop.nameAr}${f.plantingDate != null ? " (زراعة: ${DateFormat('yyyy-MM-dd').format(f.plantingDate!)})" : ""}'
                                        : 'المحصول: غير محدد',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Action Buttons Row: Edit Crop & Planting Date, Delete Field
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1B5E20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              size: 17,
                            ),
                            label: const Text(
                              'تعديل المحصول والزراعة',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _showEditCropDialog(f),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            tooltip: 'حذف الحقل',
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    title: const Text('تأكيد حذف الحقل'),
                                    content: Text(
                                      'هل أنت متأكد من حذف ${f.nameAr}؟ لن يتم استرجاعه تلقائياً.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (confirm == true) {
                                await ref
                                    .read(fieldListProvider.notifier)
                                    .deleteField(f.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
