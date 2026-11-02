import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';

/// Screen allowing the user to pick an agricultural field location on an interactive map
/// strictly restricted and verified against the Arab Republic of Egypt's geographic boundaries.
class EgyptLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final EgyptBoundaryService?
  boundaryService; // Test seam for injecting preloaded service
  final AssetBundle?
  assetBundle; // Test seam for injecting custom/failing asset bundle
  final TileProvider?
  tileProvider; // Test seam for injecting offline/mock tile provider
  final void Function(TileImage tile, Object error, StackTrace? stackTrace)?
  onTileLoadError; // Test seam for observing/simulating tile errors

  const EgyptLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.boundaryService,
    this.assetBundle,
    this.tileProvider,
    this.onTileLoadError,
  });

  @override
  State<EgyptLocationPickerScreen> createState() =>
      _EgyptLocationPickerScreenState();
}

class _EgyptLocationPickerScreenState extends State<EgyptLocationPickerScreen> {
  late final MapController _mapController;
  EgyptBoundaryService? _boundaryService;
  bool _isLoadingService = true;
  String? _serviceErrorMessage;

  LatLng? _selectedPoint;
  String? _detectedGovernorate;
  bool _isPointInEgypt = false;
  bool _hasTileLoadError = false;

  // Center of Egypt (near Minya/Asyut)
  static const LatLng _egyptCenter = LatLng(27.0, 30.8);
  static const double _initialZoom = 6.0;

  late final LatLng _mapInitialCenter;
  late final double _mapInitialZoom;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final hasValidInitial = widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude!.isFinite &&
        widget.initialLongitude!.isFinite;
    _mapInitialCenter = hasValidInitial
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _egyptCenter;
    _mapInitialZoom = hasValidInitial ? 10.0 : _initialZoom;
    _initBoundaryService();
  }

  Future<void> _initBoundaryService() async {
    if (widget.boundaryService != null) {
      _boundaryService = widget.boundaryService;
      _isLoadingService = false;
      _applyInitialPoint();
      return;
    }

    try {
      final service = await EgyptBoundaryService.loadFromBundle(
        bundle: widget.assetBundle,
      );
      if (!mounted) return;
      setState(() {
        _boundaryService = service;
        _isLoadingService = false;
        _applyInitialPoint();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingService = false;
        _serviceErrorMessage = 'تعذر تحميل بيانات الحدود الجغرافية لمصر: $e';
      });
    }
  }

  void _applyInitialPoint() {
    if (widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude!.isFinite &&
        widget.initialLongitude!.isFinite) {
      _onPointSelected(
        LatLng(widget.initialLatitude!, widget.initialLongitude!),
      );
    }
  }

  void _onPointSelected(LatLng point) {
    if (_boundaryService == null) return;

    final inEgypt = _boundaryService!.isWithinEgypt(
      point.latitude,
      point.longitude,
    );
    final gov = _boundaryService!.findGovernorate(
      point.latitude,
      point.longitude,
    );

    setState(() {
      _selectedPoint = point;
      _isPointInEgypt = inEgypt;
      _detectedGovernorate = gov;
    });
  }

  void _confirmSelection() {
    if (_selectedPoint == null ||
        !_isPointInEgypt ||
        _detectedGovernorate == null) {
      return;
    }

    final result = SelectedLocation(
      latitude: double.parse(_selectedPoint!.latitude.toStringAsFixed(6)),
      longitude: double.parse(_selectedPoint!.longitude.toStringAsFixed(6)),
      governorateAr: _detectedGovernorate!,
    );

    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديد موقع الحقل على الخريطة'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomPanel(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingService) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text(
              'جارٍ تحميل الحدود الجغرافية لجمهورية مصر العربية...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_serviceErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _serviceErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoadingService = true;
                    _serviceErrorMessage = null;
                  });
                  _initBoundaryService();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapInitialCenter,
            initialZoom: _mapInitialZoom,
            minZoom: 5.0,
            maxZoom: 18.0,
            cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(
                const LatLng(21.0, 24.0),
                const LatLng(32.5, 37.5),
              ),
            ),
            onTap: (tapPosition, point) => _onPointSelected(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agroshift.app',
              tileProvider: widget.tileProvider ?? NetworkTileProvider(),
              tileBuilder: (context, tileWidget, tile) {
                if (tile.loadError) {
                  return Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 28,
                      color: Colors.grey.shade400,
                    ),
                  );
                }
                return tileWidget;
              },
              errorTileCallback: (tile, error, stackTrace) {
                widget.onTileLoadError?.call(tile, error, stackTrace);
                if (mounted && !_hasTileLoadError) {
                  setState(() {
                    _hasTileLoadError = true;
                  });
                }
              },
            ),
            if (_selectedPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint!,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: _isPointInEgypt
                          ? const Color(0xFF1B5E20)
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Attribution Badge
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(217), // 0.85 opacity
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),

        // Helper instruction card
        Positioned(
          top: 12,
          right: 12,
          left: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withAlpha(242), // 0.95 opacity
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        size: 20,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPoint == null
                              ? 'انقر على الخريطة لتحديد موقع الحقل داخل مصر'
                              : 'يمكنك النقر مجدداً لتغيير موقع الحقل المحدد',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_hasTileLoadError) ...[
                const SizedBox(height: 6),
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.amber.shade50,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_outlined,
                          size: 18,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تعذر تحميل خلفية الخريطة نظراً لضعف الاتصال بالشبكة أو تعطل خدمة الخرائط. لا يزال بإمكانك النقر لتحديد الموقع أو الإلغاء.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20), // 0.08 opacity
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedPoint == null) ...[
              const Text(
                'لم يتم تحديد موقع بعد',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ] else if (_isPointInEgypt && _detectedGovernorate != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'المحافظة: $_detectedGovernorate',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'الإحداثيات: ${_selectedPoint!.latitude.toStringAsFixed(5)}° شمالاً، ${_selectedPoint!.longitude.toStringAsFixed(5)}° شرقاً',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'الموقع المختار خارج الحدود الجغرافية لجمهورية مصر العربية',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'الإحداثيات: ${_selectedPoint!.latitude.toStringAsFixed(5)}°، ${_selectedPoint!.longitude.toStringAsFixed(5)}°',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isPointInEgypt && _detectedGovernorate != null)
                        ? _confirmSelection
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'تأكيد الموقع',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
}
