import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';

/// Available basemap layers for the Egypt location picker.
enum MapLayerType { satellite, streets }

/// Lifecycle states for Android Location Services and runtime permission verification.
enum LocationLifecycleState {
  initializing,
  waitingForLocationService,
  waitingForPermission,
  ready,
  openingLocationSettings,
  openingAppSettings,
}

/// Contract for GPS location services enabling deterministic testing and seams.
abstract class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({LocationSettings? locationSettings});
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

/// Production implementation backed by the geolocator plugin.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Geolocator.getCurrentPosition(locationSettings: locationSettings);

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

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
  final MapLayerType initialLayer;
  final LocationService locationService;

  const EgyptLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.boundaryService,
    this.assetBundle,
    this.tileProvider,
    this.onTileLoadError,
    this.initialLayer = MapLayerType.satellite,
    this.locationService = const GeolocatorLocationService(),
  });

  @override
  State<EgyptLocationPickerScreen> createState() =>
      _EgyptLocationPickerScreenState();
}

class _EgyptLocationPickerScreenState extends State<EgyptLocationPickerScreen>
    with WidgetsBindingObserver {
  static const String _esriSatelliteUrl =
      'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String _esriLabelsUrl =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
  static const String _osmStreetUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _esriHybridAttribution =
      'Imagery © Esri, Maxar, Earthstar Geographics | Labels © Esri, Garmin, HERE, and GIS Community';
  static const String _osmAttribution = '© OpenStreetMap contributors';

  late final MapController _mapController;
  late MapLayerType _selectedLayer;
  EgyptBoundaryService? _boundaryService;
  bool _isLoadingService = true;
  String? _serviceErrorMessage;

  LatLng? _selectedPoint;
  String? _detectedGovernorate;
  bool _isPointInEgypt = false;
  bool _hasTileLoadError = false;
  bool _isLocating = false;

  LocationLifecycleState _locationLifecycleState =
      LocationLifecycleState.initializing;
  bool _isVerifyingPrerequisites = false;
  bool _isDialogShowing = false;

  bool get _isLocationReady =>
      _locationLifecycleState == LocationLifecycleState.ready;

  LocationLifecycleState get locationLifecycleState => _locationLifecycleState;

  // Center of Egypt (near Minya/Asyut)
  static const LatLng _egyptCenter = LatLng(27.0, 30.8);
  static const double _initialZoom = 6.0;

  late final LatLng _mapInitialCenter;
  late final double _mapInitialZoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedLayer = widget.initialLayer;
    _mapController = MapController();
    final hasValidInitial =
        widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude!.isFinite &&
        widget.initialLongitude!.isFinite;
    _mapInitialCenter = hasValidInitial
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _egyptCenter;
    _mapInitialZoom = hasValidInitial ? 10.0 : _initialZoom;
    _initBoundaryService();

    // Automatically check and enforce mandatory GPS & location permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verifyLocationPrerequisites();
      }
    });
  }

  Future<void> _initBoundaryService() async {
    if (widget.boundaryService != null) {
      _boundaryService = widget.boundaryService;
      _isLoadingService = false;
      if (_isLocationReady) {
        _applyInitialPoint();
      }
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
        if (_isLocationReady) {
          _applyInitialPoint();
        }
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
    if (!mounted || _boundaryService == null || !_isLocationReady) {
      return;
    }

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
    if (!_isLocationReady ||
        _selectedPoint == null ||
        !_isPointInEgypt ||
        _detectedGovernorate == null ||
        _detectedGovernorate!.trim().isEmpty ||
        !_selectedPoint!.latitude.isFinite ||
        !_selectedPoint!.longitude.isFinite) {
      return;
    }

    final result = SelectedLocation(
      latitude: double.parse(_selectedPoint!.latitude.toStringAsFixed(6)),
      longitude: double.parse(_selectedPoint!.longitude.toStringAsFixed(6)),
      governorateAr: _detectedGovernorate!.trim(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_locationLifecycleState != LocationLifecycleState.ready) {
        _verifyLocationPrerequisites();
      }
    }
  }

  /// Mandatory verification of Android Location Services (GPS) and permissions.
  Future<void> _verifyLocationPrerequisites() async {
    if (!mounted || _isVerifyingPrerequisites) return;
    _isVerifyingPrerequisites = true;

    try {
      // 1. Check whether Android Location Services are enabled
      final serviceResult = await _safeIsLocationServiceEnabled();
      if (serviceResult.hasError) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState =
              LocationLifecycleState.waitingForLocationService;
        });
        _showSnackBar(
          serviceResult.errorMessage ??
              'حدث خطأ في الاتصال بخدمة الموقع. يرجى إعادة المحاولة.',
          isError: true,
        );
        return;
      }

      if (!serviceResult.isEnabled) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState =
              LocationLifecycleState.waitingForLocationService;
        });
        await _showMandatoryLocationServiceDialog();
        return;
      }

      // 2. Check and request location permission
      var permResult = await _safeCheckPermission();
      if (permResult.hasError) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        _showSnackBar(
          permResult.errorMessage ??
              'حدث خطأ أثناء فحص إذن الموقع. يرجى إعادة المحاولة.',
          isError: true,
        );
        return;
      }

      var permission = permResult.permission;
      if (permission == LocationPermission.unableToDetermine) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        _showSnackBar(
          'تعذر تحديد حالة إذن الموقع من نظام أندرويد. يرجى إعادة المحاولة.',
          isError: true,
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        final reqResult = await _safeRequestPermission();
        if (!mounted) return;
        if (reqResult.hasError) {
          _showSnackBar(
            reqResult.errorMessage ??
                'حدث خطأ أثناء طلب إذن الموقع. يرجى إعادة المحاولة.',
            isError: true,
          );
          return;
        }
        permission = reqResult.permission;
      }

      if (permission == LocationPermission.unableToDetermine) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        _showSnackBar(
          'تعذر تحديد حالة إذن الموقع من نظام أندرويد. يرجى إعادة المحاولة.',
          isError: true,
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        _showSnackBar(
          'تم رفض إذن الوصول إلى الموقع. يرجى تفعيل الإذن للمتابعة.',
          isError: true,
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.waitingForPermission;
        });
        await _showMandatoryAppSettingsDialog();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final serviceStillEnabled = await _safeIsLocationServiceEnabled();
        if (serviceStillEnabled.hasError || !serviceStillEnabled.isEnabled) {
          if (!mounted) return;
          setState(() {
            _locationLifecycleState =
                LocationLifecycleState.waitingForLocationService;
          });
          if (serviceStillEnabled.hasError) {
            _showSnackBar(
              serviceStillEnabled.errorMessage ??
                  'حدث خطأ في الاتصال بخدمة الموقع. يرجى إعادة المحاولة.',
              isError: true,
            );
          } else {
            await _showMandatoryLocationServiceDialog();
          }
          return;
        }

        if (!mounted) return;
        setState(() {
          _locationLifecycleState = LocationLifecycleState.ready;
        });

        if (_boundaryService != null && _selectedPoint == null) {
          _applyInitialPoint();
        }
      }
    } finally {
      _isVerifyingPrerequisites = false;
    }
  }

  Future<void> _showMandatoryLocationServiceDialog() async {
    if (_isDialogShowing || !mounted) return;
    _isDialogShowing = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.location_off, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'تشغيل الموقع مطلوب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'يجب تفعيل خدمة الموقع (GPS) حتى تتمكن من تحديد موقع الحقل الزراعي واستخدام هذه الخاصية.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _locationLifecycleState =
                          LocationLifecycleState.openingLocationSettings;
                    });
                    Navigator.of(ctx).pop();
                    final opened = await _safeOpenLocationSettings();
                    if (!opened && mounted) {
                      _showSnackBar(
                        'تعذر فتح إعدادات الموقع تلقائياً. يرجى فتحها يدوياً من إعدادات الهاتف.',
                        isError: true,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تشغيل الموقع'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  Future<void> _showMandatoryAppSettingsDialog() async {
    if (_isDialogShowing || !mounted) return;
    _isDialogShowing = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'إذن الموقع مطلوب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'تم رفض إذن الوصول إلى الموقع بشكل دائم. يجب السماح للتطبيق بالوصول إلى الموقع من إعدادات التطبيق للمتابعة.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _locationLifecycleState =
                          LocationLifecycleState.openingAppSettings;
                    });
                    Navigator.of(ctx).pop();
                    final opened = await _safeOpenAppSettings();
                    if (!opened && mounted) {
                      _showSnackBar(
                        'تعذر فتح إعدادات التطبيق تلقائياً. يرجى فتحها يدوياً من إعدادات الهاتف.',
                        isError: true,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('فتح إعدادات التطبيق'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  Future<({bool isEnabled, bool hasError, String? errorMessage})>
  _safeIsLocationServiceEnabled() async {
    try {
      final enabled = await widget.locationService.isLocationServiceEnabled();
      return (isEnabled: enabled, hasError: false, errorMessage: null);
    } on TimeoutException {
      return (
        isEnabled: false,
        hasError: true,
        errorMessage: 'انتهت مهلة التحقق من خدمة الموقع. يرجى إعادة المحاولة.',
      );
    } on PlatformException catch (e) {
      return (
        isEnabled: false,
        hasError: true,
        errorMessage:
            'حدث خطأ في الاتصال بخدمة الموقع (${e.code}). يرجى إعادة المحاولة.',
      );
    } catch (_) {
      return (
        isEnabled: false,
        hasError: true,
        errorMessage:
            'حدث خطأ غير متوقع أثناء فحص خدمة الموقع. يرجى إعادة المحاولة.',
      );
    }
  }

  Future<({LocationPermission permission, bool hasError, String? errorMessage})>
  _safeCheckPermission() async {
    try {
      final perm = await widget.locationService.checkPermission();
      return (permission: perm, hasError: false, errorMessage: null);
    } on TimeoutException {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage: 'انتهت مهلة فحص إذن الموقع. يرجى إعادة المحاولة.',
      );
    } on PlatformException catch (e) {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage:
            'حدث خطأ أثناء فحص إذن الموقع (${e.code}). يرجى إعادة المحاولة.',
      );
    } catch (_) {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage: 'تعذر التحقق من إذن الموقع. يرجى إعادة المحاولة.',
      );
    }
  }

  Future<({LocationPermission permission, bool hasError, String? errorMessage})>
  _safeRequestPermission() async {
    try {
      final perm = await widget.locationService.requestPermission();
      return (permission: perm, hasError: false, errorMessage: null);
    } on TimeoutException {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage: 'انتهت مهلة طلب إذن الموقع. يرجى إعادة المحاولة.',
      );
    } on PlatformException catch (e) {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage:
            'حدث خطأ أثناء طلب إذن الموقع (${e.code}). يرجى إعادة المحاولة.',
      );
    } catch (_) {
      return (
        permission: LocationPermission.unableToDetermine,
        hasError: true,
        errorMessage: 'تعذر طلب إذن الموقع. يرجى إعادة المحاولة.',
      );
    }
  }

  Future<bool> _safeOpenLocationSettings() async {
    try {
      return await widget.locationService.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeOpenAppSettings() async {
    try {
      return await widget.locationService.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<void> _determineCurrentLocation() async {
    if (_isLocating) return;

    if (!_isLocationReady) {
      await _verifyLocationPrerequisites();
      if (!_isLocationReady) {
        return;
      }
    }

    if (_boundaryService == null) {
      _showSnackBar(
        'يرجى الانتظار حتى اكتمال تحميل الحدود الجغرافية لمصر',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final position = await widget.locationService.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);

      // Move camera to current coordinates with zoom 15.0
      _mapController.move(latLng, 15.0);

      // Call point selection to trigger boundary & governorate detection
      _onPointSelected(latLng);

      if (!_isPointInEgypt) {
        _showSnackBar(
          'الموقع الحالي يقع خارج حدود جمهورية مصر العربية (${position.latitude.toStringAsFixed(4)}°، ${position.longitude.toStringAsFixed(4)}°)',
          isError: true,
        );
      } else {
        _showSnackBar('تم تحديد موقعك الحالي بنجاح: $_detectedGovernorate');
      }
    } on TimeoutException {
      if (!mounted) return;
      _showSnackBar(
        'استغرق تحديد الموقع وقتاً طويلاً. يرجى المحاولة مرة أخرى.',
        isError: true,
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      _showSnackBar('تم إيقاف خدمة الموقع (GPS)', isError: true);
      await _verifyLocationPrerequisites();
    } on PermissionDeniedException {
      if (!mounted) return;
      _showSnackBar('تم رفض إذن الوصول إلى الموقع الجغرافي', isError: true);
      await _verifyLocationPrerequisites();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('تعذر تحديد موقعك الحالي: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: isError
            ? Colors.red.shade800
            : const Color(0xFF1B5E20),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            onTap: _isLocationReady
                ? (tapPosition, point) => _onPointSelected(point)
                : null,
          ),
          children: [
            TileLayer(
              key: ValueKey(_selectedLayer),
              urlTemplate: _selectedLayer == MapLayerType.satellite
                  ? _esriSatelliteUrl
                  : _osmStreetUrl,
              userAgentPackageName: 'com.agroshift.app',
              tileProvider: widget.tileProvider ?? NetworkTileProvider(),
              maxZoom: 19,
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
            if (_selectedLayer == MapLayerType.satellite)
              TileLayer(
                key: const ValueKey('esri_labels_layer'),
                urlTemplate: _esriLabelsUrl,
                userAgentPackageName: 'com.agroshift.app',
                tileProvider: widget.tileProvider ?? NetworkTileProvider(),
                maxZoom: 19,
                tileBuilder: (context, tileWidget, tile) {
                  if (tile.loadError) {
                    return const SizedBox.shrink();
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

        // Map Lock Overlay when GPS/Permissions not ready
        if (!_isLocationReady) _buildMapLockOverlay(),

        // Attribution Badge
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width > 380
                  ? 210
                  : MediaQuery.sizeOf(context).width - 165,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(225), // 0.88 opacity
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              _selectedLayer == MapLayerType.satellite
                  ? _esriHybridAttribution
                  : _osmAttribution,
              style: const TextStyle(
                fontSize: 8.5,
                color: Colors.black87,
                height: 1.25,
              ),
              softWrap: true,
            ),
          ),
        ),

        // Map Layer Selector (Satellite vs Street Map)
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withAlpha(245),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLayerOption(
                    type: MapLayerType.satellite,
                    label: 'قمر صناعي',
                    icon: Icons.satellite_alt_outlined,
                  ),
                  const SizedBox(width: 2),
                  _buildLayerOption(
                    type: MapLayerType.streets,
                    label: 'خريطة',
                    icon: Icons.map_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Current GPS Location Button
        Positioned(
          right: 12,
          bottom: 50,
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: InkWell(
              onTap: _isLocating ? null : _determineCurrentLocation,
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: 'موقعي الحالي',
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1B5E20),
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                          size: 22,
                          color: Color(0xFF1B5E20),
                        ),
                ),
              ),
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
                          !_isLocationReady
                              ? 'يرجى تفعيل الموقع للمتابعة'
                              : (_selectedPoint == null
                                    ? 'انقر على الخريطة لتحديد موقع الحقل داخل مصر'
                                    : 'يمكنك النقر مجدداً لتغيير موقع الحقل المحدد'),
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

  Widget _buildLayerOption({
    required MapLayerType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedLayer == type;
    return InkWell(
      onTap: () {
        if (_selectedLayer != type) {
          setState(() {
            _selectedLayer = type;
            _hasTileLoadError = false;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLockOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _verifyLocationPrerequisites,
        child: Container(
          color: Colors.black.withAlpha(90),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_outlined,
                      size: 28,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'يرجى تفعيل الموقع للمتابعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يجب تفعيل خدمة الموقع (GPS) ومنح الإذن لتتمكن من اختيار موقع الحقل الزراعي على الخريطة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _verifyLocationPrerequisites,
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text('تفعيل خدمة الموقع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
                    onPressed:
                        (_isLocationReady &&
                            _isPointInEgypt &&
                            _detectedGovernorate != null)
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
