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
  SoilType _selectedSoil = SoilType.clay;
  String _selectedCropId = 'wheat';
  DateTime? _selectedPlantingDate;

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
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'إضافة حقل زراعي جديد في مصر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الحقل / المزرعة',
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'يرجى إدخال اسم الحقل'
                          : null,
                    ),
                    TextFormField(
                      controller: _govController,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة (مثال: كفر الشيخ، المنيا)',
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'يرجى إدخال اسم المحافظة'
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'خط العرض (22 - 31.8)',
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lonController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'خط الطول (25 - 37)',
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
                    TextFormField(
                      controller: _areaController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المساحة (بالفدان)',
                      ),
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'قيمة غير صحيحة';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SoilType>(
                      initialValue: _selectedSoil,
                      decoration: const InputDecoration(
                        labelText: 'نوع التربة',
                      ),
                      items: SoilType.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(_soilTypeName(s)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSoil = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCropId,
                      decoration: const InputDecoration(
                        labelText: 'المحصول القائم',
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
                        setState(() {
                          _selectedCropId = val ?? '';
                          if (_selectedCropId.isEmpty) {
                            _selectedPlantingDate = null;
                          }
                        });
                      },
                    ),
                    if (_selectedCropId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تاريخ زراعة المحصول'),
                        subtitle: Text(
                          _selectedPlantingDate != null
                              ? DateFormat('yyyy-MM-dd')
                                    .format(_selectedPlantingDate!)
                              : 'غير محدد (انقر للاختيار)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedPlantingDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() => _selectedPlantingDate = null);
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: _selectedPlantingDate ?? now,
                                  firstDate: now.subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setState(
                                    () => _selectedPlantingDate = picked,
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
                      soilType: _selectedSoil,
                      activeCropId: _selectedCropId.isNotEmpty
                          ? _selectedCropId
                          : null,
                      plantingDate: _selectedCropId.isNotEmpty
                          ? _selectedPlantingDate
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
                        decoration: const InputDecoration(
                          labelText: 'المحصول القائم',
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ زراعة المحصول'),
                          subtitle: Text(
                            currentPlantingDate != null
                                ? DateFormat('yyyy-MM-dd')
                                      .format(currentPlantingDate!)
                                : 'غير محدد (انقر للاختيار)',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentPlantingDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setDialogState(
                                      () => currentPlantingDate = null,
                                    );
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isActive
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE0E0E0),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? const Color(0xFF1B5E20)
                        : Colors.grey.shade300,
                    foregroundColor: isActive ? Colors.white : Colors.black87,
                    child: const Icon(Icons.agriculture, size: 20),
                  ),
                  title: Text(
                    f.nameAr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${f.governorateAr} | ${f.coordinate.latitude.toStringAsFixed(2)}°N, ${f.coordinate.longitude.toStringAsFixed(2)}°E | ${f.areaInFeddan} فدان\nالمحصول: ${crop?.nameAr ?? "غير محدد"}${f.plantingDate != null ? " (زراعة: ${DateFormat('yyyy-MM-dd').format(f.plantingDate!)})" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isActive)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F8E9),
                            foregroundColor: const Color(0xFF1B5E20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () {
                            ref
                                .read(selectedFieldProvider.notifier)
                                .selectField(f);
                          },
                          child: const Text(
                            'تفعيل',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                      else
                        const Chip(
                          label: Text(
                            'الحقل النشط',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 20,
                          color: Color(0xFF1B5E20),
                        ),
                        tooltip: 'تعديل المحصول وتاريخ الزراعة',
                        onPressed: () => _showEditCropDialog(f),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red,
                        ),
                        tooltip: 'حذف الحقل',
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
                                    onPressed: () => Navigator.pop(c, false),
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
                ),
              );
            }),
        ],
      ),
    );
  }
}
