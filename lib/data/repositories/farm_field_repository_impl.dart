import 'package:drift/drift.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/domain/agronomy/repositories/i_farm_field_repository.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';

import '../datasources/local/database/app_database.dart';

/// Implementation of IFarmFieldRepository using Drift SQLite database.
class FarmFieldRepositoryImpl implements IFarmFieldRepository {
  final AppDatabase _db;

  FarmFieldRepositoryImpl(this._db);

  @override
  Future<Result<List<FarmField>, Failure>> getAllFields() async {
    try {
      final rows = await (_db.select(
        _db.farmFieldsTable,
      )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).get();

      final List<FarmField> fields = [];
      for (final row in rows) {
        final soil = _parseSoilType(row.soilType);
        final coord = Coordinate(
          latitude: row.latitude,
          longitude: row.longitude,
          governorateName: row.governorateAr,
        );

        final field = FarmField(
          id: row.id,
          nameAr: row.nameAr,
          governorateAr: row.governorateAr,
          coordinate: coord,
          areaInFeddan: row.areaInFeddan,
          soilType: soil,
          activeCropId: row.activeCropId,
          plantingDate: row.plantingDate,
        );

        // Physical validation guard when reading
        final val = field.validate();
        if (val.isFailure) {
          // Skip or log corrupted record rather than crashing the whole app
          continue;
        }

        fields.add(field);
      }

      return Success(fields);
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr:
              'حدث خطأ أثناء قراءة الحقول المسجلة من قاعدة البيانات.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<void, Failure>> saveField(
    FarmField field, {
    bool isDefault = false,
  }) async {
    final val = field.validate();
    if (val.isFailure) {
      return FailureResult(val.failureOrNull!);
    }

    try {
      final now = DateTime.now();
      final existing = await (_db.select(
        _db.farmFieldsTable,
      )..where((t) => t.id.equals(field.id))).getSingleOrNull();

      final createdAtValue = existing != null ? existing.createdAt : now;

      await _db
          .into(_db.farmFieldsTable)
          .insertOnConflictUpdate(
            FarmFieldsTableCompanion(
              id: Value(field.id),
              nameAr: Value(field.nameAr),
              governorateAr: Value(field.governorateAr),
              latitude: Value(field.coordinate.latitude),
              longitude: Value(field.coordinate.longitude),
              areaInFeddan: Value(field.areaInFeddan),
              soilType: Value(field.soilType.name),
              activeCropId: Value(field.activeCropId),
              plantingDate: Value(field.plantingDate),
              isDefault: Value(isDefault || (existing?.isDefault ?? false)),
              createdAt: Value(createdAtValue),
              updatedAt: Value(now),
            ),
          );

      return const Success(null);
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr: 'تعذر حفظ الحقل في قاعدة البيانات.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<void, Failure>> deleteField(String id) async {
    try {
      // Check if field was a default field
      final existing = await (_db.select(
        _db.farmFieldsTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (existing != null && existing.isDefault) {
        // Record in DeletedDefaultFieldIdsTable so it is never resurrected
        await _db
            .into(_db.deletedDefaultFieldIdsTable)
            .insertOnConflictUpdate(
              DeletedDefaultFieldIdsTableCompanion(
                id: Value(id),
                deletedAt: Value(DateTime.now()),
              ),
            );
      }

      await (_db.delete(
        _db.farmFieldsTable,
      )..where((t) => t.id.equals(id))).go();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr: 'تعذر حذف الحقل من قاعدة البيانات.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<void, Failure>> seedDefaultFieldsIfNecessary(
    List<FarmField> defaults,
  ) async {
    try {
      final deletedDefaultIds = await (_db.select(
        _db.deletedDefaultFieldIdsTable,
      )).get();
      final deletedSet = deletedDefaultIds.map((d) => d.id).toSet();

      for (final defField in defaults) {
        if (deletedSet.contains(defField.id)) {
          // User previously deleted this default field; do not recreate
          continue;
        }

        final existing = await (_db.select(
          _db.farmFieldsTable,
        )..where((t) => t.id.equals(defField.id))).getSingleOrNull();

        if (existing == null) {
          final saveResult = await saveField(defField, isDefault: true);
          if (saveResult.isFailure) {
            return saveResult;
          }
        }
      }

      return const Success(null);
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr: 'تعذر تهيئة الحقول النموذجية.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  SoilType _parseSoilType(String name) {
    for (final s in SoilType.values) {
      if (s.name == name) return s;
    }
    return SoilType.clay;
  }
}
