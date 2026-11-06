import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/presentation/screens/egypt_location_picker_screen.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';

// Minimal deterministic 1x1 transparent PNG tile for offline widget tests
final Uint8List _transparentPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Deterministic offline tile provider returning a mock in-memory tile
class MockOfflineTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(_transparentPngBytes);
}

/// Simulated failing image provider for deterministic tile error tests
class _FailingTileImageProvider
    extends ImageProvider<_FailingTileImageProvider> {
  @override
  Future<_FailingTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final streamCompleter = OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(
        const SocketException('Failed host lookup: tile.openstreetmap.org'),
      ),
    );
    return streamCompleter;
  }

  @override
  bool operator ==(Object other) => other is _FailingTileImageProvider;

  @override
  int get hashCode => 42;
}

/// Deterministic tile provider simulating network/service failure
/// Simulated failing asset bundle for testing boundary loading failure
class MockFailingAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    return Future.error(
      const FileSystemException('Asset not found or corrupt'),
    );
  }

  @override
  Future<ByteData> load(String key) {
    return Future.error(
      const FileSystemException('Asset not found or corrupt'),
    );
  }
}

class MockFailingTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => _FailingTileImageProvider();
}

/// Asset bundle that fails on first load and succeeds on subsequent load
class MockRetryAssetBundle extends CachingAssetBundle {
  int attempts = 0;
  final String validGeoJson;

  MockRetryAssetBundle(this.validGeoJson);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    attempts++;
    if (attempts == 1) {
      throw const FileSystemException('Temporary I/O failure');
    }
    return validGeoJson;
  }

  @override
  Future<ByteData> load(String key) async {
    attempts++;
    if (attempts == 1) {
      throw const FileSystemException('Temporary I/O failure');
    }
    final bytes = utf8.encode(validGeoJson);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

/// Controllable mock location service for testing Android GPS workflows
class MockTestLocationService implements LocationService {
  bool serviceEnabled;
  LocationPermission permission;
  Position? positionToReturn;
  Exception? exceptionToThrow;
  int positionCallCount = 0;
  bool openSettingsCalled = false;
  bool openAppSettingsCalled = false;
  Duration? simulatedDelay;

  MockTestLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.positionToReturn,
    this.exceptionToThrow,
    this.simulatedDelay,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCallCount++;
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return positionToReturn ??
        Position(
          latitude: 30.0444, // Cairo
          longitude: 31.2357,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Future<bool> openLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;
    return true;
  }
}
/*
/// Controllable mock location service for testing Android GPS workflows
class MockTestLocationService implements LocationService {
  bool serviceEnabled;
  LocationPermission permission;
  Position? positionToReturn;
  Exception? exceptionToThrow;
  int positionCallCount = 0;
  bool openSettingsCalled = false;
  bool openAppSettingsCalled = false;
  Duration? simulatedDelay;

  MockTestLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.positionToReturn,
    this.exceptionToThrow,
    this.simulatedDelay,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    positionCallCount++;
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return positionToReturn ??
        Position(
          latitude: 30.0444, // Cairo
          longitude: 31.2357,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Future<bool> openLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;
    return true;
  }
}
*/
void main() {
  late EgyptBoundaryService boundaryService;
  late String geoJsonString;

  setUpAll(() async {
    final file = File('assets/geo/egypt_governorates.geojson');
    geoJsonString = await file.readAsString();
    boundaryService = EgyptBoundaryService.fromJsonString(geoJsonString);
  });

  group('EgyptLocationPickerScreen Widget Tests', () {
    testWidgets('Renders essential controls and title in Arabic', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);
      expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تأكيد الموقع'), findsOneWidget);

      // Confirm button is disabled when no point is selected
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
      );
      expect(confirmBtn.onPressed, isNull);
    });

    testWidgets(
      'Pre-populated with valid coordinate displays governorate and enables confirmation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockOfflineTileProvider(),
              initialLatitude: 31.27, // Sidi Salem
              initialLongitude: 30.79,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('المحافظة: كفر الشيخ'), findsOneWidget);
        expect(find.textContaining('31.27'), findsOneWidget);
        expect(find.textContaining('30.79'), findsOneWidget);

        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(confirmBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Pre-populated with outside Egypt coordinate shows error and disables confirmation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockOfflineTileProvider(),
              initialLatitude: 31.60, // Mediterranean offshore in old bbox
              initialLongitude: 30.00,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'الموقع المختار خارج الحدود الجغرافية لجمهورية مصر العربية',
          ),
          findsOneWidget,
        );

        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(confirmBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Confirming returns SelectedLocation with coordinates and governorate',
      (tester) async {
        SelectedLocation? returnedLocation;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedLocation = await Navigator.of(ctx)
                      .push<SelectedLocation>(
                        MaterialPageRoute(
                          builder: (ctx) => EgyptLocationPickerScreen(
                            boundaryService: boundaryService,
                            tileProvider: MockOfflineTileProvider(),
                            initialLatitude: 28.50, // Minya
                            initialLongitude: 30.80,
                          ),
                        ),
                      );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Picker'));
        await tester.pumpAndSettle();

        expect(find.text('المحافظة: المنيا'), findsOneWidget);

        await tester.tap(find.text('تأكيد الموقع'));
        await tester.pumpAndSettle();

        expect(returnedLocation, isNotNull);
        expect(returnedLocation!.governorateAr, equals('المنيا'));
        expect(returnedLocation!.latitude, equals(28.5));
        expect(returnedLocation!.longitude, equals(30.8));
      },
    );

    testWidgets('Cancelling picker returns null', (tester) async {
      SelectedLocation? returnedLocation;
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                returnedLocation = await Navigator.of(ctx)
                    .push<SelectedLocation>(
                      MaterialPageRoute(
                        builder: (ctx) => EgyptLocationPickerScreen(
                          boundaryService: boundaryService,
                          tileProvider: MockOfflineTileProvider(),
                          initialLatitude: 28.50,
                          initialLongitude: 30.80,
                        ),
                      ),
                    );
                popped = true;
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(returnedLocation, isNull);
    });

    testWidgets(
      'Simulated tile loading failure displays warning banner and broken tile placeholder without crashing',
      (tester) async {
        int tileErrorCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockFailingTileProvider(),
              initialLatitude: 31.27, // Sidi Salem
              initialLongitude: 30.79,
              onTileLoadError: (tile, error, stackTrace) {
                tileErrorCount++;
              },
            ),
          ),
        );

        // Allow tile loading errors to dispatch through image stream completers
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // Screen does not crash and tile errors were detected
        expect(tileErrorCount, greaterThan(0));

        // Network tile error banner is displayed
        expect(
          find.text(
            'تعذر تحميل خلفية الخريطة نظراً لضعف الاتصال بالشبكة أو تعطل خدمة الخرائط. لا يزال بإمكانك النقر لتحديد الموقع أو الإلغاء.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);

        // Broken image fallback icons rendered in place of tiles
        expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);

        // Map interaction and pre-populated governorate data remain intact
        expect(find.text('المحافظة: كفر الشيخ'), findsOneWidget);

        // Confirmation remains functional and enabled for valid Egyptian point
        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(confirmBtn.onPressed, isNotNull);

        // Cancel button remains completely accessible and functional
        expect(find.text('إلغاء'), findsOneWidget);
        await tester.tap(find.text('إلغاء'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Boundary service initialization failure is handled independently from tile failure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              assetBundle: MockFailingAssetBundle(),
            ),
          ),
        );

        // Pump frames for async _initBoundaryService
        await tester.pump();
        await tester.pumpAndSettle();

        // Verifies the boundary error screen renders without tile layer
        expect(
          find.textContaining('تعذر تحميل بيانات الحدود الجغرافية لمصر'),
          findsOneWidget,
        );
        expect(find.text('إعادة المحاولة'), findsOneWidget);

        // Back / Cancel remains available
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      },
    );

    testWidgets(
      'Retry button re-attempts loading boundary service after initial failure',
      (tester) async {
        final retryBundle = MockRetryAssetBundle(geoJsonString);

        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              assetBundle: retryBundle,
              tileProvider: MockOfflineTileProvider(),
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Initial attempt fails and displays retry button
        expect(
          find.textContaining('تعذر تحميل بيانات الحدود الجغرافية لمصر'),
          findsOneWidget,
        );
        expect(find.text('إعادة المحاولة'), findsOneWidget);

        // 2. Tap retry
        await tester.tap(find.text('إعادة المحاولة'));
        await tester.pump();
        await tester.pumpAndSettle();

        // 3. Retry succeeds: error message is gone, map controls are rendered
        expect(
          find.textContaining('تعذر تحميل بيانات الحدود الجغرافية لمصر'),
          findsNothing,
        );
        expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);
        expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);
      },
    );

    testWidgets(
      'Interactive canvas tap selects point, detects governorate, and enables confirmation',
      (tester) async {
        SelectedLocation? returnedLocation;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedLocation = await Navigator.of(ctx)
                      .push<SelectedLocation>(
                        MaterialPageRoute(
                          builder: (ctx) => EgyptLocationPickerScreen(
                            boundaryService: boundaryService,
                            tileProvider: MockOfflineTileProvider(),
                          ),
                        ),
                      );
                },
                child: const Text('Open Map'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Map'));
        await tester.pumpAndSettle();

        // Initial state: no location selected, confirm disabled
        expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);
        final initialConfirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(initialConfirmBtn.onPressed, isNull);

        // Tap the map canvas at center (default center is Lat 27.0, Lon 30.8)
        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Location detected in New Valley
        expect(find.text('المحافظة: الوادي الجديد'), findsOneWidget);
        expect(find.textContaining('27.0000'), findsOneWidget);
        expect(find.textContaining('30.8000'), findsOneWidget);

        // Confirm button is now enabled
        final activeConfirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(activeConfirmBtn.onPressed, isNotNull);

        // Tap confirm
        await tester.tap(find.widgetWithText(ElevatedButton, 'تأكيد الموقع'));
        await tester.pumpAndSettle();

        // Verify returned location
        expect(returnedLocation, isNotNull);
        expect(returnedLocation!.governorateAr, equals('الوادي الجديد'));
        expect(returnedLocation!.latitude, equals(27.0));
        expect(returnedLocation!.longitude, equals(30.8));
      },
    );

    testWidgets(
      'Safe disposal during asynchronous boundary loading does not throw',
      (tester) async {
        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (ctx) => EgyptLocationPickerScreen(
                        assetBundle: MockFailingAssetBundle(),
                        tileProvider: MockOfflineTileProvider(),
                      ),
                    ),
                  );
                },
                child: const Text('Launch Screen'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Screen'));
        await tester.pump(); // Trigger tap and push
        await tester.pump(
          const Duration(milliseconds: 50),
        ); // Build screen in transition
        expect(find.byType(EgyptLocationPickerScreen), findsOneWidget);

        // Immediately pop before async bundle load completes
        navKey.currentState!.pop();
        await tester.pumpAndSettle();

        // Screen safely unmounted without throwing unhandled exceptions
        expect(find.byType(EgyptLocationPickerScreen), findsNothing);
        expect(find.text('Launch Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'Defaults to Esri World Imagery satellite layer with reference labels overlay, correct layer ordering, and attribution',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockOfflineTileProvider(),
              initialLatitude: 30.0444, // Cairo
              initialLongitude: 31.2357,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Satellite is default layer and FlutterMap children ordering:
        // [0] = Satellite TileLayer
        // [1] = Esri Labels TileLayer (above satellite imagery)
        // [2] = MarkerLayer (above all tile layers)
        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(flutterMap.children.length, equals(3));

        final basemapLayer = flutterMap.children[0] as TileLayer;
        expect(
          basemapLayer.urlTemplate,
          equals(
            'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          ),
        );
        expect(basemapLayer.maxZoom, equals(19));

        final labelsLayer = flutterMap.children[1] as TileLayer;
        expect(
          labelsLayer.urlTemplate,
          equals(
            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
          ),
        );
        expect(labelsLayer.maxZoom, equals(19));

        final markerLayer = flutterMap.children[2] as MarkerLayer;
        expect(markerLayer.markers.length, equals(1));
        expect(markerLayer.markers.first.point.latitude, equals(30.0444));

        // 2. Verify Esri hybrid attribution text is displayed without truncation
        expect(
          find.text(
            'Imagery © Esri, Maxar, Earthstar Geographics | Labels © Esri, Garmin, HERE, and GIS Community',
          ),
          findsOneWidget,
        );

        // 3. Verify layer selector buttons are rendered in Arabic
        expect(find.text('قمر صناعي'), findsOneWidget);
        expect(find.text('خريطة'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching layers via layer selector toggles between satellite+labels and street map without resetting selected location',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockOfflineTileProvider(),
              initialLatitude: 30.0444, // Cairo
              initialLongitude: 31.2357,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state: Satellite layer & Cairo selected with labels overlay
        expect(find.text('المحافظة: القاهرة'), findsOneWidget);
        var flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(flutterMap.children.length, equals(3));
        expect(
          (flutterMap.children[0] as TileLayer).urlTemplate,
          contains(
            'services.arcgisonline.com/ArcGIS/rest/services/World_Imagery',
          ),
        );
        expect(
          (flutterMap.children[1] as TileLayer).urlTemplate,
          contains('World_Boundaries_and_Places'),
        );
        expect(flutterMap.children[2], isA<MarkerLayer>());
        expect(
          find.text(
            'Imagery © Esri, Maxar, Earthstar Geographics | Labels © Esri, Garmin, HERE, and GIS Community',
          ),
          findsOneWidget,
        );

        // 1. Switch to Street Map ('خريطة') -> removes labels overlay to avoid duplicate labels
        await tester.tap(find.text('خريطة'));
        await tester.pumpAndSettle();

        flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(flutterMap.children.length, equals(2));
        final osmLayer = flutterMap.children[0] as TileLayer;
        expect(
          osmLayer.urlTemplate,
          equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        );
        expect(flutterMap.children[1], isA<MarkerLayer>());
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

        // Location selection and confirmation remain intact
        expect(find.text('المحافظة: القاهرة'), findsOneWidget);
        var confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(confirmBtn.onPressed, isNotNull);

        // 2. Switch back to Satellite ('قمر صناعي') -> restores labels overlay
        await tester.tap(find.text('قمر صناعي'));
        await tester.pumpAndSettle();

        flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(flutterMap.children.length, equals(3));
        expect(
          (flutterMap.children[0] as TileLayer).urlTemplate,
          contains(
            'services.arcgisonline.com/ArcGIS/rest/services/World_Imagery',
          ),
        );
        expect(
          (flutterMap.children[1] as TileLayer).urlTemplate,
          contains('World_Boundaries_and_Places'),
        );
        expect(flutterMap.children[2], isA<MarkerLayer>());
        expect(
          find.text(
            'Imagery © Esri, Maxar, Earthstar Geographics | Labels © Esri, Garmin, HERE, and GIS Community',
          ),
          findsOneWidget,
        );

        // Location selection and confirmation still intact
        expect(find.text('المحافظة: القاهرة'), findsOneWidget);
        confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(confirmBtn.onPressed, isNotNull);
      },
    );
  });

  group(
    'Android GPS Location Services & Launcher Icon Tests (Tasks 1, 2, 3, 4)',
    () {
      testWidgets(
        'Current location button renders with my_location icon and tooltip',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.my_location), findsOneWidget);
          expect(find.byTooltip('موقعي الحالي'), findsOneWidget);
        },
      );

      testWidgets(
        'Disabled location services displays Arabic alert dialog with تشغيل الموقع button',
        (tester) async {
          final mockLocation = MockTestLocationService(serviceEnabled: false);

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap current location button
          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          // Verify Arabic alert dialog explaining location must be enabled
          expect(find.text('خدمات الموقع غير مفعلة'), findsOneWidget);
          expect(
            find.textContaining('يرجى تفعيل خدمات الموقع الجغرافي'),
            findsOneWidget,
          );
          expect(find.text('تشغيل الموقع'), findsOneWidget);
          expect(find.text('إلغاء'), findsWidgets);

          // Tap تشغيل الموقع button
          await tester.tap(find.widgetWithText(ElevatedButton, 'تشغيل الموقع'));
          await tester.pumpAndSettle();

          expect(mockLocation.openSettingsCalled, isTrue);
          // Dialog dismissed
          expect(find.text('خدمات الموقع غير مفعلة'), findsNothing);
        },
      );

      testWidgets(
        'Denied location permission displays Arabic snackbar and does not select point',
        (tester) async {
          final mockLocation = MockTestLocationService(
            serviceEnabled: true,
            permission: LocationPermission.denied,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          expect(
            find.text('تم رفض إذن الوصول إلى الموقع الجغرافي'),
            findsOneWidget,
          );
          expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);
        },
      );

      testWidgets(
        'Permanently denied permission displays dialog with فتح إعدادات التطبيق button',
        (tester) async {
          final mockLocation = MockTestLocationService(
            serviceEnabled: true,
            permission: LocationPermission.deniedForever,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          expect(find.text('إذن الموقع مطلوب'), findsOneWidget);
          expect(
            find.textContaining(
              'تم رفض إذن الوصول إلى الموقع الجغرافي بشكل دائم',
            ),
            findsOneWidget,
          );
          expect(find.text('فتح إعدادات التطبيق'), findsOneWidget);

          await tester.tap(
            find.widgetWithText(ElevatedButton, 'فتح إعدادات التطبيق'),
          );
          await tester.pumpAndSettle();

          expect(mockLocation.openAppSettingsCalled, isTrue);
          expect(find.text('إذن الموقع مطلوب'), findsNothing);
        },
      );

      testWidgets(
        'Successful GPS acquisition moves camera, selects position inside Egypt, auto-detects governorate, and enables confirmation',
        (tester) async {
          final mockLocation = MockTestLocationService(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
            positionToReturn: Position(
              latitude: 28.1099, // Minya
              longitude: 30.7503,
              timestamp: DateTime.now(),
              accuracy: 5.0,
              altitude: 40.0,
              altitudeAccuracy: 1.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Before GPS: no location selected
          expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);

          // Tap GPS button
          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          // Governorate automatically detected as Minya
          expect(find.text('المحافظة: المنيا'), findsOneWidget);
          expect(
            find.textContaining('تم تحديد موقعك الحالي بنجاح: المنيا'),
            findsOneWidget,
          );

          // Confirmation button is now enabled
          final confirmBtn = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
          );
          expect(confirmBtn.onPressed, isNotNull);
        },
      );

      testWidgets(
        'GPS position outside Egypt marks location as invalid, disables confirmation, and displays warning snackbar',
        (tester) async {
          final mockLocation = MockTestLocationService(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
            positionToReturn: Position(
              latitude: 41.9028, // Rome (Outside Egypt)
              longitude: 12.4964,
              timestamp: DateTime.now(),
              accuracy: 5.0,
              altitude: 20.0,
              altitudeAccuracy: 1.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          // Warning snackbar displayed
          expect(
            find.textContaining(
              'الموقع الحالي يقع خارج حدود جمهورية مصر العربية',
            ),
            findsOneWidget,
          );

          // Bottom panel marks point as outside Egypt
          expect(
            find.text(
              'الموقع المختار خارج الحدود الجغرافية لجمهورية مصر العربية',
            ),
            findsOneWidget,
          );

          // Confirmation button is disabled
          final confirmBtn = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
          );
          expect(confirmBtn.onPressed, isNull);
        },
      );

      testWidgets('GPS timeout displays user-friendly Arabic error snackbar', (
        tester,
      ) async {
        final mockLocation = MockTestLocationService(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          exceptionToThrow: TimeoutException('GPS timed out after 20 seconds'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EgyptLocationPickerScreen(
              boundaryService: boundaryService,
              tileProvider: MockOfflineTileProvider(),
              locationService: mockLocation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.my_location));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'استغرق تحديد الموقع وقتاً طويلاً. يرجى المحاولة مرة أخرى.',
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'Duplicate GPS requests while locating are ignored and show loading indicator',
        (tester) async {
          final mockLocation = MockTestLocationService(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
            simulatedDelay: const Duration(milliseconds: 250),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EgyptLocationPickerScreen(
                boundaryService: boundaryService,
                tileProvider: MockOfflineTileProvider(),
                locationService: mockLocation,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // First tap starts location fetch
          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pump(const Duration(milliseconds: 50));

          // Loading indicator is shown inside the current location button
          expect(find.byType(CircularProgressIndicator), findsWidgets);

          // Second tap while still locating should be ignored
          await tester.tap(find.byType(InkWell).last);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          // Position was fetched exactly once!
          expect(mockLocation.positionCallCount, equals(1));
        },
      );

      test(
        'Android launcher icon resources and manifest verification (Task 3)',
        () {
          // 1. Verify exact source image exists and is untouched
          final sourceIcon = File('assets/Icon/Icon.png');
          expect(sourceIcon.existsSync(), isTrue);

          // 2. Verify Android launcher icon densities exist
          final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
          for (final density in densities) {
            final iconFile = File(
              'android/app/src/main/res/mipmap-$density/ic_launcher.png',
            );
            expect(
              iconFile.existsSync(),
              isTrue,
              reason: 'Missing mipmap-$density/ic_launcher.png',
            );
          }

          // 3. Verify AndroidManifest.xml references @mipmap/ic_launcher and location permissions
          final manifest = File('android/app/src/main/AndroidManifest.xml')
              .readAsStringSync();
          expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
          expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
          expect(
            manifest,
            contains('android.permission.ACCESS_COARSE_LOCATION'),
          );
          expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));

          // 4. Verify no iOS location permissions were added (Android-only requirement)
          final iosPlist = File('ios/Runner/Info.plist');
          if (iosPlist.existsSync()) {
            final plistContent = iosPlist.readAsStringSync();
            expect(
              plistContent,
              isNot(contains('NSLocationWhenInUseUsageDescription')),
            );
            expect(
              plistContent,
              isNot(contains('NSLocationAlwaysUsageDescription')),
            );
          }
        },
      );
    },
  );

  group('Android GPS Location Services & Launcher Icon Tests (Tasks 1, 2, 3, 4)', () {
    testWidgets('Current location button renders with my_location icon and tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byTooltip('موقعي الحالي'), findsOneWidget);
    });

    testWidgets('Disabled location services displays Arabic alert dialog with تشغيل الموقع button', (tester) async {
      final mockLocation = MockTestLocationService(serviceEnabled: false);

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap current location button
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      // Verify Arabic alert dialog explaining location must be enabled
      expect(find.text('خدمات الموقع غير مفعلة'), findsOneWidget);
      expect(find.textContaining('يرجى تفعيل خدمات الموقع الجغرافي'), findsOneWidget);
      expect(find.text('تشغيل الموقع'), findsOneWidget);
      expect(find.text('إلغاء'), findsWidgets);

      // Tap تشغيل الموقع button
      await tester.tap(find.widgetWithText(ElevatedButton, 'تشغيل الموقع'));
      await tester.pumpAndSettle();

      expect(mockLocation.openSettingsCalled, isTrue);
      // Dialog dismissed
      expect(find.text('خدمات الموقع غير مفعلة'), findsNothing);
    });

    testWidgets('Denied location permission displays Arabic snackbar and does not select point', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.denied,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      expect(find.text('تم رفض إذن الوصول إلى الموقع الجغرافي'), findsOneWidget);
      expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);
    });

    testWidgets('Permanently denied permission displays dialog with فتح إعدادات التطبيق button', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      expect(find.text('إذن الموقع مطلوب'), findsOneWidget);
      expect(find.textContaining('تم رفض إذن الوصول إلى الموقع الجغرافي بشكل دائم'), findsOneWidget);
      expect(find.text('فتح إعدادات التطبيق'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'فتح إعدادات التطبيق'));
      await tester.pumpAndSettle();

      expect(mockLocation.openAppSettingsCalled, isTrue);
      expect(find.text('إذن الموقع مطلوب'), findsNothing);
    });

    testWidgets('Successful GPS acquisition moves camera, selects position inside Egypt, auto-detects governorate, and enables confirmation', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        positionToReturn: Position(
          latitude: 28.1099, // Minya
          longitude: 30.7503,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 40.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before GPS: no location selected
      expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);

      // Tap GPS button
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      // Governorate automatically detected as Minya
      expect(find.text('المحافظة: المنيا'), findsOneWidget);
      expect(find.textContaining('تم تحديد موقعك الحالي بنجاح: المنيا'), findsOneWidget);

      // Confirmation button is now enabled
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
      );
      expect(confirmBtn.onPressed, isNotNull);
    });

    testWidgets('GPS position outside Egypt marks location as invalid, disables confirmation, and displays warning snackbar', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        positionToReturn: Position(
          latitude: 41.9028, // Rome (Outside Egypt)
          longitude: 12.4964,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      // Warning snackbar displayed
      expect(find.textContaining('الموقع الحالي يقع خارج حدود جمهورية مصر العربية'), findsOneWidget);

      // Bottom panel marks point as outside Egypt
      expect(find.text('الموقع المختار خارج الحدود الجغرافية لجمهورية مصر العربية'), findsOneWidget);

      // Confirmation button is disabled
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
      );
      expect(confirmBtn.onPressed, isNull);
    });

    testWidgets('GPS timeout displays user-friendly Arabic error snackbar', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        exceptionToThrow: TimeoutException('GPS timed out after 20 seconds'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      expect(find.text('استغرق تحديد الموقع وقتاً طويلاً. يرجى المحاولة مرة أخرى.'), findsOneWidget);
    });

    testWidgets('Duplicate GPS requests while locating are ignored and show loading indicator', (tester) async {
      final mockLocation = MockTestLocationService(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        simulatedDelay: const Duration(milliseconds: 250),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EgyptLocationPickerScreen(
            boundaryService: boundaryService,
            tileProvider: MockOfflineTileProvider(),
            locationService: mockLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First tap starts location fetch
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump(const Duration(milliseconds: 50));

      // Loading indicator is shown inside the current location button
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Second tap while still locating should be ignored
      await tester.tap(find.byType(InkWell).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Position was fetched exactly once!
      expect(mockLocation.positionCallCount, equals(1));
    });

    test('Android launcher icon resources and manifest verification (Task 3)', () {
      // 1. Verify exact source image exists and is untouched
      final sourceIcon = File('assets/Icon/Icon.png');
      expect(sourceIcon.existsSync(), isTrue);

      // 2. Verify Android launcher icon densities exist
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final iconFile = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(iconFile.existsSync(), isTrue, reason: 'Missing mipmap-$density/ic_launcher.png');
      }

      // 3. Verify AndroidManifest.xml references @mipmap/ic_launcher and location permissions
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));

      // 4. Verify no iOS location permissions were added (Android-only requirement)
      final iosPlist = File('ios/Runner/Info.plist');
      if (iosPlist.existsSync()) {
        final plistContent = iosPlist.readAsStringSync();
        expect(plistContent, isNot(contains('NSLocationWhenInUseUsageDescription')));
        expect(plistContent, isNot(contains('NSLocationAlwaysUsageDescription')));
      }
    });
  });
}
