import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/presentation/screens/egypt_location_picker_screen.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';

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
          home: EgyptLocationPickerScreen(boundaryService: boundaryService),
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
  });
}
