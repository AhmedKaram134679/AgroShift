import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/agronomy/models/crop_catalog.dart';
import 'package:agro_shift/presentation/screens/egypt_location_picker_screen.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';

class FieldManagementScreen extends ConsumerStatefulWidget {
  final EgyptBoundaryService? boundaryService;
  final LocationService? locationService;

  const FieldManagementScreen({
    super.key,
    this.boundaryService,
    this.locationService,
  });

  @override
  ConsumerState<FieldManagementScreen> createState() =>
      _FieldManagementScreenState();
}

class _FieldManagementScreenState extends ConsumerState<FieldManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _govController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _areaController = TextEditingController();

  bool _hasVerifiedFieldLocation = false;
  SelectedLocation? _selectedFieldLocation;
  bool _isSaving = false;
  bool _isProgrammaticUpdate = false;
  StateSetter? _dialogSetState;
  EgyptBoundaryService? _boundaryService;

  String _soilTypeName(SoilType s) => switch (s) {
    SoilType.clay => 'طينية ثقيلة (دلتا قديمة)',
    SoilType.clayLoam => 'طميية طينية (وادي النيل)',
    SoilType.sandyLoam => 'طميية رملية (أراضي جديدة)',
    SoilType.sandy => 'رملية صحراوية',
  };

  @override
  void initState() {
    super.initState();
    _latController.addListener(_handleCoordinateChanged);
    _lonController.addListener(_handleCoordinateChanged);
    _govController.addListener(_handleCoordinateChanged);
    _initBoundaryService();
  }

  Future<void> _initBoundaryService() async {
    if (widget.boundaryService != null) {
      _boundaryService = widget.boundaryService;
      return;
    }
    try {
      final service = await EgyptBoundaryService.loadFromBundle();
      if (!mounted) return;
      _boundaryService = service;
    } catch (_) {}
  }

  void _handleCoordinateChanged() {
    if (_isProgrammaticUpdate) return;
    if (!_hasVerifiedFieldLocation && _selectedFieldLocation == null) return;

    final currentLat = double.tryParse(_latController.text.trim());
    final currentLon = double.tryParse(_lonController.text.trim());
    final currentGov = _govController.text.trim();

    if (_selectedFieldLocation == null ||
        currentLat == null ||
        currentLon == null ||
        (currentLat - _selectedFieldLocation!.latitude).abs() > 0.0001 ||
        (currentLon - _selectedFieldLocation!.longitude).abs() > 0.0001 ||
        currentGov != _selectedFieldLocation!.governorateAr) {
      _invalidateFieldLocationIfModified();
    }
  }

  void _invalidateFieldLocationIfModified() {
    if (!_hasVerifiedFieldLocation && _selectedFieldLocation == null) return;
    _dialogSetState?.call(() {
      _hasVerifiedFieldLocation = false;
      _selectedFieldLocation = null;
    });
    setState(() {
      _hasVerifiedFieldLocation = false;
      _selectedFieldLocation = null;
    });
  }

  bool _isValidSelectedLocation(SelectedLocation? location) {
    if (location == null) {
      return false;
    }

    final latitude = location.latitude;
    final longitude = location.longitude;

    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }

    if (location.governorateAr.trim().isEmpty) {
      return false;
    }

    final boundaryService = widget.boundaryService ?? _boundaryService;
    if (boundaryService != null) {
      if (!boundaryService.isWithinEgypt(latitude, longitude)) {
        return false;
      }
      final detectedGov = boundaryService.findGovernorate(latitude, longitude);
      if (detectedGov == null || detectedGov.trim().isEmpty) {
        return false;
      }
    } else {
      if (latitude < 22.0 ||
          latitude > 31.8 ||
          longitude < 25.0 ||
          longitude > 37.0) {
        return false;
      }
    }

    return true;
  }

  void _onFieldLocationSelected(SelectedLocation location) {
    if (!mounted) return;

    if (!_isValidSelectedLocation(location)) {
      _dialogSetState?.call(() {
        _selectedFieldLocation = null;
        _hasVerifiedFieldLocation = false;
      });
      setState(() {
        _selectedFieldLocation = null;
        _hasVerifiedFieldLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الموقع المحدد غير صالح. يرجى اختيار موقع صحيح داخل مصر.',
          ),
        ),
      );
      return;
    }

    _isProgrammaticUpdate = true;
    _govController.text = location.governorateAr;
    _latController.text = location.latitude.toStringAsFixed(4);
    _lonController.text = location.longitude.toStringAsFixed(4);
    _isProgrammaticUpdate = false;

    _dialogSetState?.call(() {
      _selectedFieldLocation = location;
      _hasVerifiedFieldLocation = true;
    });
    setState(() {
      _selectedFieldLocation = location;
      _hasVerifiedFieldLocation = true;
    });
  }

  @override
  void dispose() {
    _latController.removeListener(_handleCoordinateChanged);
    _lonController.removeListener(_handleCoordinateChanged);
    _govController.removeListener(_handleCoordinateChanged);
    _nameController.dispose();
    _govController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _showAddFieldDialog() {
    _showFieldFormDialog();
  }

  void _showEditFieldDialog(FarmField field) {
    _showFieldFormDialog(existingField: field);
  }

  void _showFieldFormDialog({FarmField? existingField}) {
    _isProgrammaticUpdate = true;
    _nameController.text = existingField?.nameAr ?? '';
    _areaController.text = existingField != null
        ? existingField.areaInFeddan.toString()
        : '';

    if (existingField != null) {
      _govController.text = existingField.governorateAr;
      _latController.text = existingField.coordinate.latitude.toString();
      _lonController.text = existingField.coordinate.longitude.toString();
      _selectedFieldLocation = SelectedLocation(
        latitude: existingField.coordinate.latitude,
        longitude: existingField.coordinate.longitude,
        governorateAr: existingField.governorateAr,
      );
      _hasVerifiedFieldLocation = true;
    } else {
      _govController.clear();
      _latController.clear();
      _lonController.clear();
      _selectedFieldLocation = null;
      _hasVerifiedFieldLocation = false;
    }
    _isProgrammaticUpdate = false;

    var selectedSoil = existingField?.soilType ?? SoilType.clay;
    var selectedCropId = existingField?.activeCropId ?? '';
    DateTime? selectedPlantingDate = existingField?.plantingDate;
    _isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            _dialogSetState = setDialogState;

            Future<void> saveField() async {
              if (!mounted) return;

              // Mandatory validation guard directly inside save method
              if (!_hasVerifiedFieldLocation ||
                  !_isValidSelectedLocation(_selectedFieldLocation)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'يرجى تحديد موقع الحقل والتحقق منه على الخريطة أولاً.',
                    ),
                  ),
                );
                return;
              }

              if (!(_formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => _isSaving = true);
              setState(() => _isSaving = true);

              try {
                final location = _selectedFieldLocation!;
                final fieldToSave = FarmField(
                  id:
                      existingField?.id ??
                      'field_${DateTime.now().millisecondsSinceEpoch}',
                  nameAr: _nameController.text.trim(),
                  governorateAr: location.governorateAr,
                  coordinate: Coordinate(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    governorateName: location.governorateAr,
                  ),
                  areaInFeddan: double.parse(_areaController.text.trim()),
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
                    .addField(fieldToSave);
                if (!mounted || !dialogCtx.mounted) return;
                if (addRes.isSuccess) {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existingField != null
                            ? 'تم تحديث الحقل الزراعي بنجاح'
                            : 'تم تسجيل الحقل الزراعي بنجاح',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        addRes.failureOrNull?.userMessageAr ?? 'خطأ في التسجيل',
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setDialogState(() => _isSaving = false);
                  setState(() => _isSaving = false);
                }
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                title: Row(
                  children: [
                    const Icon(
                      Icons.add_location_alt,
                      color: Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        existingField != null
                            ? 'تعديل بيانات الحقل الزراعي'
                            : 'إضافة حقل زراعي جديد في مصر',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                          OutlinedButton.icon(
                            onPressed: () async {
                              final initialLat = double.tryParse(
                                _latController.text.trim(),
                              );
                              final initialLon = double.tryParse(
                                _lonController.text.trim(),
                              );

                              final selected = await Navigator.of(context)
                                  .push<SelectedLocation>(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EgyptLocationPickerScreen(
                                            initialLatitude: initialLat,
                                            initialLongitude: initialLon,
                                            boundaryService:
                                                widget.boundaryService ??
                                                _boundaryService,
                                            locationService:
                                                widget.locationService ??
                                                const GeolocatorLocationService(),
                                          ),
                                    ),
                                  );

                              if (selected != null) {
                                _onFieldLocationSelected(selected);
                              }
                            },
                            icon: const Icon(
                              Icons.map_outlined,
                              color: Color(0xFF1B5E20),
                            ),
                            label: const Text(
                              'تحديد الموقع على الخريطة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF1B5E20)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _hasVerifiedFieldLocation
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasVerifiedFieldLocation
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFFFFB74D),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _hasVerifiedFieldLocation
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  size: 18,
                                  color: _hasVerifiedFieldLocation
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _hasVerifiedFieldLocation
                                        ? 'تم تحديد موقع الحقل والتحقق منه بنجاح.'
                                        : 'يجب تحديد موقع الحقل على الخريطة والتحقق منه قبل التسجيل.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _hasVerifiedFieldLocation
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFFBF360C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _govController,
                            decoration: InputDecoration(
                              labelText: 'المحافظة (مثال: كفر الشيخ، المنيا)',
                              hintText: 'يتم تحديدها تلقائياً من الخريطة',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'يرجى تحديد الموقع على الخريطة'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'خط العرض',
                                    helperText: '22 - 31.8 شمالاً',
                                    hintText: 'من الخريطة',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'يرجى تحديد الموقع';
                                    }
                                    final d = double.tryParse(v.trim());
                                    if (d == null || d < 22.0 || d > 31.8) {
                                      return 'بين 22 و 31.8';
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
                                    labelText: 'خط الطول',
                                    helperText: '25 - 37 شرقاً',
                                    hintText: 'من الخريطة',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'يرجى تحديد الموقع';
                                    }
                                    final d = double.tryParse(v.trim());
                                    if (d == null || d < 25.0 || d > 37.0) {
                                      return 'بين 25 و 37';
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
                            isExpanded: true,
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
                                child: Text(
                                  _soilTypeName(s),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                            isExpanded: true,
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
                                  child: Text(
                                    '${c.nameAr} (${c.nameEn})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: selectedPlantingDate ?? now,
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
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ زراعة المحصول',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.calendar_month_outlined,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  suffixIcon: selectedPlantingDate != null
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setDialogState(
                                              () => selectedPlantingDate = null,
                                            );
                                          },
                                        )
                                      : null,
                                ),
                                child: Text(
                                  selectedPlantingDate != null
                                      ? DateFormat('yyyy-MM-dd')
                                            .format(selectedPlantingDate!)
                                      : 'غير محدد (انقر للاختيار)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selectedPlantingDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
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
                    onPressed: (_hasVerifiedFieldLocation && !_isSaving)
                        ? saveField
                        : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            existingField != null
                                ? 'حفظ التعديلات'
                                : 'حفظ الحقل',
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _dialogSetState = null;
    });
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
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                title: Row(
                  children: [
                    const Icon(Icons.edit_calendar, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تحديث محصول وتاريخ زراعة ${field.nameAr}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: currentCropId,
                        isExpanded: true,
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
                              child: Text(
                                '${c.nameAr} (${c.nameEn})',
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
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
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'تاريخ زراعة المحصول',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              prefixIcon: const Icon(
                                Icons.calendar_month_outlined,
                                color: Color(0xFF1B5E20),
                              ),
                              suffixIcon: currentPlantingDate != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setDialogState(
                                          () => currentPlantingDate = null,
                                        );
                                      },
                                    )
                                  : null,
                            ),
                            child: Text(
                              currentPlantingDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                        .format(currentPlantingDate!)
                                  : 'غير محدد (انقر للاختيار)',
                              style: TextStyle(
                                fontSize: 14,
                                color: currentPlantingDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
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

                      // Action Buttons Row: Edit Crop & Planting Date, Edit Field, Delete Field
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
                          const SizedBox(width: 4),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1B5E20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text(
                              'تعديل الحقل',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _showEditFieldDialog(f),
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
