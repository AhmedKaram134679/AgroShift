import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late EgyptBoundaryService boundaryService;

  setUpAll(() async {
    final file = File('assets/geo/egypt_governorates.geojson');
    final jsonStr = await file.readAsString();
    boundaryService = EgyptBoundaryService.fromJsonString(jsonStr);
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
  });
}
