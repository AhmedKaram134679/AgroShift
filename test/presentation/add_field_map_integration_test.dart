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
            body: FieldManagementScreen(boundaryService: boundaryService),
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
      'Manual field registration continues to work without opening map',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Enter field details manually
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الحقل / المزرعة'),
          'مزرعة الدلتا النموذجية',
        );
        await tester.pumpAndSettle();

        final saveBtn = find.widgetWithText(ElevatedButton, 'حفظ الحقل');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();

        // Tap save
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify dialog is dismissed and new field is visible in the list
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('مزرعة الدلتا النموذجية'),
          100,
        );
        expect(find.text('مزرعة الدلتا النموذجية'), findsOneWidget);
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
      'End-to-end map selection, confirmation, dialog population, non-persistence, and subsequent save (Workstream C)',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // 1. Initial database state: record initial total and verify 0 custom fields
        final initialFields = await db.select(db.farmFieldsTable).get();
        final initialCount = initialFields.length;
        final initialCustomFields =
            initialFields.where((f) => !f.isDefault).toList();
        expect(initialCustomFields, isEmpty);

        // 2. Open Add Field dialog via FloatingActionButton
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);

        // 3. User enters field name and area manually
        const testFieldName = 'مزرعة غرب الدلتا النموذجية';
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

        // 4. Pre-enter coordinate in the dialog for map inspection
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط العرض'),
          '28.5000',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'خط الطول'),
          '30.8000',
        );
        await tester.pumpAndSettle();

        // 5. Tap "تحديد الموقع على الخريطة" to open EgyptLocationPickerScreen
        final mapBtn = find.widgetWithText(
          OutlinedButton,
          'تحديد الموقع على الخريطة',
        );
        await tester.ensureVisible(mapBtn);
        await tester.tap(mapBtn);
        await tester.pumpAndSettle();

        // 6. Verify map picker is open and pre-populated point resolves to Minya
        expect(find.text('تحديد موقع الحقل على الخريطة'), findsOneWidget);
        expect(find.text('المحافظة: المنيا'), findsOneWidget);
        expect(find.textContaining('28.5000'), findsOneWidget);
        expect(find.textContaining('30.8000'), findsOneWidget);

        // 7. Confirm selection on the map
        final confirmBtn = find.widgetWithText(ElevatedButton, 'تأكيد الموقع');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // 8. Verify returned to the still-open Add Field dialog
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);

        // 9. Verify coordinates and detected governorate populated into text controllers
        expect(find.text('المنيا'), findsOneWidget);
        expect(find.text('28.5000'), findsOneWidget);
        expect(find.text('30.8000'), findsOneWidget);

        // 10. Verify previously entered name and area are preserved
        expect(find.text(testFieldName), findsOneWidget);
        expect(find.text(testArea), findsOneWidget);

        // 11. CRITICAL: Verify field is NOT automatically persisted upon map confirmation
        final midFields = await db.select(db.farmFieldsTable).get();
        expect(
          midFields.length,
          equals(initialCount),
          reason:
              'Field must not be persisted to database prior to explicit form save',
        );
        expect(
          midFields.where((f) => f.nameAr == testFieldName),
          isEmpty,
          reason: 'Custom field must not exist in database yet',
        );

        // 12. User explicitly saves the field
        final saveBtn = find.widgetWithText(ElevatedButton, 'حفظ الحقل');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // 13. Verify dialog is dismissed
        expect(find.text('إضافة حقل زراعي جديد في مصر'), findsNothing);

        // 14. Verify database now contains exactly initialCount + 1 fields
        final savedFields = await db.select(db.farmFieldsTable).get();
        expect(savedFields.length, equals(initialCount + 1));
        final savedField = savedFields.firstWhere(
          (f) => f.nameAr == testFieldName,
        );
        expect(savedField.nameAr, equals(testFieldName));
        expect(savedField.areaInFeddan, equals(15.0));
        expect(savedField.governorateAr, equals('المنيا'));
        expect(savedField.latitude, equals(28.5));
        expect(savedField.longitude, equals(30.8));
        expect(savedField.isDefault, isFalse);

        // 15. Verify field card appears in the list on FieldManagementScreen
        await tester.scrollUntilVisible(find.text(testFieldName), 100);
        expect(find.text(testFieldName), findsOneWidget);
      },
    );
  });
}
