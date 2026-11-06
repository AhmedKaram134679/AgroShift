import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:agro_shift/app/theme.dart';
import 'package:agro_shift/presentation/screens/field_management_screen.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/data/datasources/local/database/app_database.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/presentation/screens/egypt_location_picker_screen.dart';
import 'package:geolocator/geolocator.dart';

class MockReadyLocationService implements LocationService {
  const MockReadyLocationService();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      latitude: 30.0444,
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
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  late AppDatabase db;
  late EgyptBoundaryService boundaryService;

  setUpAll(() async {
    final file = File('assets/geo/egypt_governorates.geojson');
    final jsonStr = await file.readAsString();
    boundaryService = EgyptBoundaryService.fromJsonString(jsonStr);
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AgroTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: FieldManagementScreen(
              boundaryService: boundaryService,
              locationService: const MockReadyLocationService(),
            ),
          ),
        ),
      ),
    );
  }

  group('Add Field Dialog & Map Picker Integration Tests', () {
    testWidgets(
      'Add-field dialog displays map picker button alongside manual inputs',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final addFieldFab = find.byType(FloatingActionButton);
        expect(addFieldFab, findsOneWidget);
        await tester.tap(addFieldFab);
        await tester.pumpAndSettle();

        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        expect(find.text('تحديد الموقع على الخريطة'), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'تحديد الموقع على الخريطة'),
          findsOneWidget,
        );

        expect(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextFormField, 'خط العرض'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'خط الطول'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          findsOneWidget,
        );
        expect(find.text('حفظ الحقل'), findsOneWidget);
      },
    );

    testWidgets(
      'Attempt to save without verified map location is rejected and geographic fields start empty',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Verify geographic fields start empty
        expect(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
          findsOneWidget,
        );
        final govField = tester.widget<TextFormField>(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
        );
        expect(govField.controller?.text, isEmpty);

        final latField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'خط العرض'),
        );
        expect(latField.controller?.text, isEmpty);

        final lonField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'خط الطول'),
        );
        expect(lonField.controller?.text, isEmpty);

        // Verification banner informs user that map location is required
        expect(
          find.text(
            'يجب تحديد موقع الحقل على الخريطة والتحقق منه قبل التسجيل.',
          ),
          findsOneWidget,
        );

        // Save button is disabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(saveBtn.onPressed, isNull);

        // Enter field details manually without map verification
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة الدلتا النموذجية',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '5.0',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط العرض'),
          '31.10',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط الطول'),
          '30.95',
        );
        await tester.pumpAndSettle();

        // Even with manually entered coordinates, save remains disabled
        final saveBtnAfterManual = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(saveBtnAfterManual.onPressed, isNull);

        // Dialog remains open and field is not saved
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        final savedFields = await db.select(db.farmFieldsTable).get();
        expect(
          savedFields.where((f) => f.nameAr == 'مزرعة الدلتا النموذجية'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'Tapping map button opens picker route and cancelling preserves entered inputs',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Enter a custom name and area
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة توشكى الجديدة',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '25.0',
        );
        await tester.pumpAndSettle();

        // Tap "تحديد الموقع على الخريطة"
        await tester.tap(find.text('تحديد الموقع على الخريطة'));
        await tester.pumpAndSettle();

        // Verify picker screen opened
        expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);
        expect(find.text('تأكيد الموقع'), findsOneWidget);

        // Tap cancel in the picker
        await tester.tap(find.text('إلغاء'));
        await tester.pumpAndSettle();

        // Verify returned to still-open dialog and inputs are intact
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        expect(find.text('مزرعة توشكى الجديدة'), findsOneWidget);
        expect(find.text('25.0'), findsOneWidget);
      },
    );

    testWidgets(
      'End-to-end map selection of a genuine new point, confirmation, dialog population, non-persistence, and subsequent save (Workstream C)',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // 1. Initial database state: record initial total and verify 0 custom fields
        final initialFields = await db.select(db.farmFieldsTable).get();
        final initialCount = initialFields.length;
        final initialCustomFields = initialFields
            .where((f) => !f.isDefault)
            .toList();
        expect(initialCustomFields, isEmpty);

        // 2. Open Add Field dialog via FloatingActionButton
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);

        // 3. User enters field name and area manually
        const testFieldName = 'مزرعة الوادي الجديد التجريبية';
        const testArea = '15.0';
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          testFieldName,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          testArea,
        );
        await tester.pumpAndSettle();

        // 4. Clear the pre-populated default coordinates in the dialog
        // so that the map opens without any pre-selected location
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط العرض'),
          '',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط الطول'),
          '',
        );
        await tester.pumpAndSettle();

        // 5. User opens the map with empty coordinate inputs
        final mapBtn = find.widgetWithText(
          OutlinedButton,
          'تحديد الموقع على الخريطة',
        );
        await tester.ensureVisible(mapBtn);
        await tester.tap(mapBtn);
        await tester.pumpAndSettle();

        // 6. Verify map picker is open and NO location is selected initially
        expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);
        expect(find.text('لم يتم تحديد موقع بعد'), findsOneWidget);

        // Confirm button is disabled prior to map selection
        final initialConfirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(initialConfirmBtn.onPressed, isNull);

        // 7. Select a genuinely new point through real map interaction.
        // Tapping the interactive FlutterMap canvas invokes MapOptions.onTap(tapPosition, point).
        // PositionedTapDetector2 requires the double-tap timeout (typically ~250-300ms) to fire single tap.
        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // 8. Verify that the selected point changes to the newly tapped location
        // Lat 27.0, Lon 30.8 is within Egypt and correctly detected as New Valley (الوادي الجديد).
        expect(find.text('المحافظة: الوادي الجديد'), findsOneWidget);
        expect(find.textContaining('27.0000'), findsOneWidget);
        expect(find.textContaining('30.8000'), findsOneWidget);

        // Confirm button is now enabled
        final updatedConfirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'تأكيد الموقع'),
        );
        expect(updatedConfirmBtn.onPressed, isNotNull);

        // 9. Confirm the newly selected location on the map
        await tester.tap(find.widgetWithText(ElevatedButton, 'تأكيد الموقع'));
        await tester.pumpAndSettle();

        // 10. Verify returned to the still-open Add Field dialog
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);

        // 11. Verify newly selected coordinates and detected governorate populated into dialog controllers
        expect(find.text('الوادي الجديد'), findsOneWidget);
        expect(find.text('27.0000'), findsOneWidget);
        expect(find.text('30.8000'), findsOneWidget);

        // 12. Verify previously entered name and area are preserved
        expect(find.text(testFieldName), findsOneWidget);
        expect(find.text(testArea), findsOneWidget);

        // 13. CRITICAL: Verify field is NOT automatically persisted upon map confirmation
        final midFields = await db.select(db.farmFieldsTable).get();
        expect(
          midFields.length,
          equals(initialCount),
          reason: 'Field must not be persisted to database prior to explicit form save',
        );
        expect(
          midFields.where((f) => f.nameAr == testFieldName),
          isEmpty,
          reason: 'Custom field must not exist in database yet',
        );

        // 14. User explicitly saves the field
        final saveBtn = find.widgetWithText(ElevatedButton, 'حفظ الحقل');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // 15. Verify dialog is dismissed
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsNothing);

        // 16. Verify database now contains exactly initialCount + 1 fields with confirmed location
        final savedFields = await db.select(db.farmFieldsTable).get();
        expect(savedFields.length, equals(initialCount + 1));
        final savedField = savedFields.firstWhere(
          (f) => f.nameAr == testFieldName,
        );
        expect(savedField.nameAr, equals(testFieldName));
        expect(savedField.areaInFeddan, equals(15.0));
        expect(savedField.governorateAr, equals('الوادي الجديد'));
        expect(savedField.latitude, equals(27.0));
        expect(savedField.longitude, equals(30.8));
        expect(savedField.isDefault, isFalse);

        // 17. Verify field card appears in the list on FieldManagementScreen
        await tester.scrollUntilVisible(find.text(testFieldName), 100);
        expect(find.text(testFieldName), findsOneWidget);
      },
    );
  });
}
