import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:agro_shift/app/theme.dart';
import 'package:agro_shift/presentation/screens/field_management_screen.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/data/datasources/local/database/app_database.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';
import 'package:agro_shift/data/repositories/farm_field_repository_impl.dart';
import 'package:agro_shift/domain/environment/models/selected_location.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/presentation/screens/egypt_location_picker_screen.dart';
import 'package:geolocator/geolocator.dart';

class MockTestLocationService implements LocationService {
  const MockTestLocationService();

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
              locationService: const MockTestLocationService(),
            ),
          ),
        ),
      ),
    );
  }

  group('FieldManagementScreen Mandatory Location Verification Tests', () {
    testWidgets(
      '1. Open a new field registration form: Geographic fields are empty',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap Add Field FAB
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);

        // Verify governorate controller is empty
        final govField = tester.widget<TextFormField>(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
        );
        expect(govField.controller?.text, isEmpty);

        // Verify latitude controller is empty
        final latField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'خط العرض'),
        );
        expect(latField.controller?.text, isEmpty);

        // Verify longitude controller is empty
        final lonField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'خط الطول'),
        );
        expect(lonField.controller?.text, isEmpty);

        // Verify Arabic warning message is visible
        expect(
          find.text(
            'يجب تحديد موقع الحقل على الخريطة والتحقق منه قبل التسجيل.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Attempt to save without opening the map: Save is rejected and button is disabled',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Fill out name and area
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة بدون خريطة',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '10.0',
        );
        await tester.pumpAndSettle();

        // Save button must be disabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(
          saveBtn.onPressed,
          isNull,
          reason: 'Save button must be disabled until map location is verified',
        );

        // Dialog remains open
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        final fields = await db.select(db.farmFieldsTable).get();
        expect(fields.where((f) => f.nameAr == 'مزرعة بدون خريطة'), isEmpty);
      },
    );

    testWidgets(
      '3. Enter manual coordinates without map verification: Save is rejected and remains disabled',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة إدخال يدوي',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '12.0',
        );

        // Manually inject coordinates
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
          'كفر الشيخ',
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

        // Save button must remain disabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(
          saveBtn.onPressed,
          isNull,
          reason: 'Manual coordinate entry cannot bypass map verification',
        );

        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
      },
    );

    testWidgets(
      '4 & 5. Select a valid location inside Egypt: Becomes verified and save succeeds',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        const testName = 'مزرعة النوبارية النموذجية';
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          testName,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '8.5',
        );
        await tester.pumpAndSettle();

        // Simulate returning valid SelectedLocation from map picker
        const validLocation = SelectedLocation(
          latitude: 30.5678,
          longitude: 30.1234,
          governorateAr: 'البحيرة',
        );

        // Call _onFieldLocationSelected via dialog state
        await tester.tap(find.text('تحديد الموقع على الخريطة'));
        await tester.pumpAndSettle();

        // We are on EgyptLocationPickerScreen
        expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);

        // Simulate location selection via navigator pop
        final navigator = Navigator.of(
          tester.element(find.text('تحديد موقع الحقل على الخريطة')),
        );
        navigator.pop(validLocation);
        await tester.pumpAndSettle();

        // Returned to dialog
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        expect(
          find.text('تم تحديد موقع الحقل والتحقق منه بنجاح.'),
          findsOneWidget,
        );

        // Check controllers populated
        expect(find.text('البحيرة'), findsOneWidget);
        expect(find.text('30.5678'), findsOneWidget);
        expect(find.text('30.1234'), findsOneWidget);

        // Save button is now enabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(saveBtn.onPressed, isNotNull);

        // Tap save
        await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ الحقل'));
        await tester.pumpAndSettle();

        // Verify dialog dismissed and field appears
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsNothing);
        await tester.scrollUntilVisible(find.text(testName), 100);
        expect(find.text(testName), findsOneWidget);

        // Verify in database
        final fields = await db.select(db.farmFieldsTable).get();
        final saved = fields.firstWhere((f) => f.nameAr == testName);
        expect(saved.governorateAr, equals('البحيرة'));
        expect((saved.latitude - 30.5678).abs() < 0.001, isTrue);
        expect((saved.longitude - 30.1234).abs() < 0.001, isTrue);
      },
    );

    testWidgets(
      '6. Coordinates outside Egypt are rejected when returned from picker',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Open picker
        await tester.tap(find.text('تحديد الموقع على الخريطة'));
        await tester.pumpAndSettle();

        // Return invalid location outside Egypt (Paris)
        final invalidLocation = const SelectedLocation(
          latitude: 48.8566,
          longitude: 2.3522,
          governorateAr: 'باريس',
        );

        Navigator.of(tester.element(find.text('تحديد موقع الحقل على الخريطة')))
            .pop(invalidLocation);
        await tester.pumpAndSettle();

        // Dialog still open, verification failed, error SnackBar shown
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
        expect(
          find.text('الموقع المحدد غير صالح. يرجى اختيار موقع صحيح داخل مصر.'),
          findsOneWidget,
        );

        // Save button remains disabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    testWidgets('7. Location without detected governorate is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تحديد الموقع على الخريطة'));
      await tester.pumpAndSettle();

      // Return location with empty governorate
      final emptyGovLocation = const SelectedLocation(
        latitude: 30.0444,
        longitude: 31.2357,
        governorateAr: '   ',
      );

      Navigator.of(tester.element(find.text('تحديد موقع الحقل على الخريطة')))
          .pop(emptyGovLocation);
      await tester.pumpAndSettle();

      expect(
        find.text('الموقع المحدد غير صالح. يرجى اختيار موقع صحيح داخل مصر.'),
        findsOneWidget,
      );

      final saveBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
      );
      expect(saveBtn.onPressed, isNull);
    });

    testWidgets(
      '8 & 9. Modifying coordinates after successful selection invalidates verification and prevents saving',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة اختبار التعديل',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '5.0',
        );

        // Open picker and return valid location
        final mapBtn = find.text('تحديد الموقع على الخريطة');
        await tester.ensureVisible(mapBtn);
        await tester.tap(mapBtn);
        await tester.pumpAndSettle();

        Navigator.of(tester.element(find.text('تحديد موقع الحقل على الخريطة')))
            .pop(
              const SelectedLocation(
                latitude: 30.0444,
                longitude: 31.2357,
                governorateAr: 'القاهرة',
              ),
            );
        await tester.pumpAndSettle();

        // Location is verified
        expect(
          find.text('تم تحديد موقع الحقل والتحقق منه بنجاح.'),
          findsOneWidget,
        );
        var saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(saveBtn.onPressed, isNotNull);

        // Now modify latitude text controller manually
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط العرض'),
          '28.5000',
        );
        await tester.pumpAndSettle();

        // Verification must be invalidated!
        expect(
          find.text(
            'يجب تحديد موقع الحقل على الخريطة والتحقق منه قبل التسجيل.',
          ),
          findsOneWidget,
        );
        saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ الحقل'),
        );
        expect(
          saveBtn.onPressed,
          isNull,
          reason: 'Modifying coordinates must invalidate verification and disable save',
        );
      },
    );

    testWidgets(
      '10 & 11. Open existing field for editing preserves coordinates, keeps verified state, and allows saving unrelated edits',
      (tester) async {
        // Pre-insert an existing field in database
        const existingField = FarmField(
          id: 'existing_field_1',
          nameAr: 'حقل الصعيد القائم',
          governorateAr: 'المنيا',
          coordinate: Coordinate(
            latitude: 28.1099,
            longitude: 30.7503,
            governorateName: 'المنيا',
          ),
          areaInFeddan: 20.0,
          soilType: SoilType.clayLoam,
        );

        await FarmFieldRepositoryImpl(db).saveField(existingField);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Verify existing field card is displayed
        await tester.scrollUntilVisible(find.text('حقل الصعيد القائم'), 100);
        expect(find.text('حقل الصعيد القائم'), findsOneWidget);

        // Tap "تعديل الحقل" on the specific card
        final cardFinder = find.ancestor(
          of: find.text('حقل الصعيد القائم'),
          matching: find.byType(Card),
        );
        final editBtn = find.descendant(
          of: cardFinder,
          matching: find.widgetWithText(TextButton, 'تعديل الحقل'),
        );
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        // Title indicates editing
        expect(find.text('تعديل بيانات الحقل الزراعي'), findsOneWidget);

        // Existing coordinates and governorate are preserved in dialog
        final govField = tester.widget<TextFormField>(
          find.widgetWithText(
            TextFormField,
            'المحافظة (مثال: كفر الشيخ، المنيا)',
          ),
        );
        expect(govField.controller?.text, equals('المنيا'));
        expect(find.text('28.1099'), findsOneWidget);
        expect(find.text('30.7503'), findsOneWidget);

        // Verified status is maintained for existing field
        expect(
          find.text('تم تحديد موقع الحقل والتحقق منه بنجاح.'),
          findsOneWidget,
        );

        // Save button is enabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ التعديلات'),
        );
        expect(saveBtn.onPressed, isNotNull);

        // Edit unrelated field info (e.g. name and area)
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'حقل الصعيد المطور',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'المساحة (بالفدان)'),
          '25.0',
        );
        await tester.pumpAndSettle();

        // Save modifications
        final saveActionBtn = find.widgetWithText(
          ElevatedButton,
          'حفظ التعديلات',
        );
        await tester.ensureVisible(saveActionBtn);
        await tester.tap(saveActionBtn);
        await tester.pumpAndSettle();

        // Verify update in UI and database
        expect(find.text('تعديل بيانات الحقل الزراعي'), findsNothing);
        await tester.scrollUntilVisible(find.text('حقل الصعيد المطور'), 100);
        expect(find.text('حقل الصعيد المطور'), findsOneWidget);

        final updatedField = await (db.select(
          db.farmFieldsTable,
        )..where((tbl) => tbl.id.equals('existing_field_1'))).getSingle();
        expect(updatedField.nameAr, equals('حقل الصعيد المطور'));
        expect(updatedField.areaInFeddan, equals(25.0));
        expect(updatedField.governorateAr, equals('المنيا'));
        expect((updatedField.latitude - 28.1099).abs() < 0.001, isTrue);
      },
    );

    testWidgets(
      '12. Changing location coordinates while editing requires new verified selection',
      (tester) async {
        const existingField = FarmField(
          id: 'existing_field_2',
          nameAr: 'حقل الدلتا الثاني',
          governorateAr: 'الغربية',
          coordinate: Coordinate(
            latitude: 30.7865,
            longitude: 31.0004,
            governorateName: 'الغربية',
          ),
          areaInFeddan: 15.0,
          soilType: SoilType.clay,
        );

        await FarmFieldRepositoryImpl(db).saveField(existingField);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('حقل الدلتا الثاني'), 100);
        expect(find.text('حقل الدلتا الثاني'), findsOneWidget);

        final cardFinder = find.ancestor(
          of: find.text('حقل الدلتا الثاني'),
          matching: find.byType(Card),
        );
        final editBtn = find.descendant(
          of: cardFinder,
          matching: find.widgetWithText(TextButton, 'تعديل الحقل'),
        );
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        expect(find.text('تعديل بيانات الحقل الزراعي'), findsOneWidget);

        // Manually tampering with latitude in edit dialog invalidates verification
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط العرض'),
          '30.1234',
        );
        await tester.pumpAndSettle();

        // Save is disabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ التعديلات'),
        );
        expect(saveBtn.onPressed, isNull);
        expect(
          find.text(
            'يجب تحديد موقع الحقل على الخريطة والتحقق منه قبل التسجيل.',
          ),
          findsOneWidget,
        );

        // Now pick a new verified location on map
        final mapBtn = find.text('تحديد الموقع على الخريطة');
        await tester.ensureVisible(mapBtn);
        await tester.tap(mapBtn);
        await tester.pumpAndSettle();

        Navigator.of(tester.element(find.text('تحديد موقع الحقل على الخريطة')))
            .pop(
              const SelectedLocation(
                latitude: 30.0444,
                longitude: 31.2357,
                governorateAr: 'القاهرة',
              ),
            );
        await tester.pumpAndSettle();

        // Location is re-verified
        expect(
          find.text('تم تحديد موقع الحقل والتحقق منه بنجاح.'),
          findsOneWidget,
        );
        final enabledSaveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'حفظ التعديلات'),
        );
        expect(enabledSaveBtn.onPressed, isNotNull);

        final saveActionBtn = find.widgetWithText(
          ElevatedButton,
          'حفظ التعديلات',
        );
        await tester.ensureVisible(saveActionBtn);
        await tester.tap(saveActionBtn);
        await tester.pumpAndSettle();

        // Database updated with new verified coordinates
        final updatedField = await (db.select(
          db.farmFieldsTable,
        )..where((tbl) => tbl.id.equals('existing_field_2'))).getSingle();
        expect(updatedField.governorateAr, equals('القاهرة'));
        expect((updatedField.latitude - 30.0444).abs() < 0.001, isTrue);
      },
    );
  });
}
