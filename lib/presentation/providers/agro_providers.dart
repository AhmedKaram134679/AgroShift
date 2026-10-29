import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_shift/domain/environment/repositories/i_weather_repository.dart';
import 'package:agro_shift/domain/agronomy/repositories/i_farm_field_repository.dart';
import 'package:agro_shift/data/repositories/weather_repository_impl.dart';
import 'package:agro_shift/data/repositories/farm_field_repository_impl.dart';
import 'package:agro_shift/data/datasources/local/database/app_database.dart';
import 'package:agro_shift/data/datasources/local/database/connection.dart';
import 'package:agro_shift/data/datasources/local/weather_local_data_source.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';

// 0. Primary App Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(() => db.close());
  return db;
});

// 1. Weather Local Data Source Provider
final weatherLocalDataSourceProvider = Provider<WeatherLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WeatherLocalDataSource(db);
});

// 2. Farm Field Repository Provider
final farmFieldRepositoryProvider = Provider<IFarmFieldRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FarmFieldRepositoryImpl(db);
});

// 3. Weather Repository Provider with persistent SQLite cache
final weatherRepositoryProvider = Provider<IWeatherRepository>((ref) {
  final localDataSource = ref.watch(weatherLocalDataSourceProvider);
  return WeatherRepositoryImpl(localDataSource: localDataSource);
});

// 4. Pre-seeded Egyptian benchmark fields across governorates
final defaultEgyptianFields = <FarmField>[
  FarmField(
    id: 'field_kafr_sheikh',
    nameAr: 'حقل سيدي سالم (كفر الشيخ)',
    governorateAr: 'كفر الشيخ (شمال الدلتا)',
    coordinate: const Coordinate(
      latitude: 31.27,
      longitude: 30.79,
      governorateName: 'كفر الشيخ',
    ),
    areaInFeddan: 5.0,
    soilType: SoilType.clay,
    activeCropId: 'wheat',
    plantingDate: DateTime(2024, 1, 15),
  ),
  FarmField(
    id: 'field_gharbia',
    nameAr: 'مزرعة طنطا الإرشادية',
    governorateAr: 'الغربية (وسط الدلتا)',
    coordinate: const Coordinate(
      latitude: 30.79,
      longitude: 31.00,
      governorateName: 'الغربية',
    ),
    areaInFeddan: 3.5,
    soilType: SoilType.clay,
    activeCropId: 'berseem',
    plantingDate: DateTime(2024, 2, 1),
  ),
  FarmField(
    id: 'field_minya',
    nameAr: 'حقل بني مزار (المنيا)',
    governorateAr: 'المنيا (مصر الوسطى)',
    coordinate: const Coordinate(
      latitude: 28.50,
      longitude: 30.80,
      governorateName: 'المنيا',
    ),
    areaInFeddan: 10.0,
    soilType: SoilType.clayLoam,
    activeCropId: 'maize',
    plantingDate: DateTime(2024, 5, 10),
  ),
];

// 5. Registered Fields State Notifier with persistent SQLite backing
class FieldListNotifier extends Notifier<List<FarmField>> {
  @override
  List<FarmField> build() {
    _loadPersistedFields();
    return defaultEgyptianFields;
  }

  Future<void> _loadPersistedFields() async {
    final repo = ref.read(farmFieldRepositoryProvider);
    // Ensure default benchmark fields are seeded if not previously deleted
    await repo.seedDefaultFieldsIfNecessary(defaultEgyptianFields);

    final res = await repo.getAllFields();
    if (res.isSuccess && res.dataOrNull != null) {
      state = res.dataOrNull!;
    }
  }

  Future<Result<void, Failure>> addField(FarmField field) async {
    final val = field.coordinate.validate();
    if (val.isFailure) {
      return FailureResult(val.failureOrNull!);
    }

    final repo = ref.read(farmFieldRepositoryProvider);
    final saveRes = await repo.saveField(field);
    if (saveRes.isSuccess) {
      // Update state without duplicates
      final updated = [...state.where((f) => f.id != field.id), field];
      state = updated;
      return const Success(null);
    }
    return saveRes;
  }

  Future<Result<void, Failure>> deleteField(String id) async {
    final repo = ref.read(farmFieldRepositoryProvider);
    final delRes = await repo.deleteField(id);
    if (delRes.isSuccess) {
      state = state.where((f) => f.id != id).toList();
      return const Success(null);
    }
    return delRes;
  }

  Future<Result<void, Failure>> updateCropAndPlantingDate({
    required String fieldId,
    required String? newCropId,
    required DateTime? newPlantingDate,
  }) async {
    final fieldIndex = state.indexWhere((f) => f.id == fieldId);
    if (fieldIndex == -1) {
      return const FailureResult(
        ParsingFailure(
          userMessageAr: 'الحقل المطلوب تحديثه غير موجود.',
          technicalMessage: 'Field not found in state.',
        ),
      );
    }

    final oldField = state[fieldIndex];
    // If active crop changes, do not silently retain previous crop's planting date
    final effectivePlantingDate = oldField.activeCropId == newCropId
        ? newPlantingDate
        : newPlantingDate;

    final updatedField = FarmField(
      id: oldField.id,
      nameAr: oldField.nameAr,
      governorateAr: oldField.governorateAr,
      coordinate: oldField.coordinate,
      areaInFeddan: oldField.areaInFeddan,
      soilType: oldField.soilType,
      activeCropId: newCropId,
      plantingDate: effectivePlantingDate,
    );

    final repo = ref.read(farmFieldRepositoryProvider);
    final saveRes = await repo.saveField(updatedField);
    if (saveRes.isSuccess) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == fieldIndex) updatedField else state[i],
      ];
      // Keep selectedFieldProvider synced if this was the selected field
      final selectedField = ref.read(selectedFieldProvider);
      if (selectedField?.id == fieldId) {
        ref.read(selectedFieldProvider.notifier).selectField(updatedField);
      }
      return const Success(null);
    }
    return saveRes;
  }
}

final fieldListProvider = NotifierProvider<FieldListNotifier, List<FarmField>>(
  FieldListNotifier.new,
);

// 6. Currently Selected Active Field Provider
class SelectedFieldNotifier extends Notifier<FarmField?> {
  @override
  FarmField? build() {
    final fields = ref.watch(fieldListProvider);
    if (fields.isEmpty) {
      return null;
    }
    return fields.first;
  }

  void selectField(FarmField field) {
    state = field;
  }
}

final selectedFieldProvider =
    NotifierProvider<SelectedFieldNotifier, FarmField?>(
      SelectedFieldNotifier.new,
    );

// 7. Active Field Forecast Weather Async Provider (7-day forecast)
final fieldForecastProvider =
    FutureProvider.autoDispose<Result<List<DailyAgroRecord>, Failure>>((
      ref,
    ) async {
      final activeField = ref.watch(selectedFieldProvider);
      if (activeField == null) {
        return const Success([]);
      }
      final weatherRepo = ref.watch(weatherRepositoryProvider);
      return await weatherRepo.getForecastDailyRecords(
        coordinate: activeField.coordinate,
        days: 7,
      );
    });

// 8. Active Field Historical Weather Async Provider (30 eligible historical days)
final fieldHistorical30DaysProvider =
    FutureProvider.autoDispose<Result<List<DailyAgroRecord>, Failure>>((
      ref,
    ) async {
      final activeField = ref.watch(selectedFieldProvider);
      if (activeField == null) {
        return const Success([]);
      }
      final weatherRepo = ref.watch(weatherRepositoryProvider);
      final latestEligible =
          WeatherRepositoryImpl.getLatestEligibleHistoricalDate();
      final startDate = latestEligible.subtract(const Duration(days: 29));
      return await weatherRepo.getHistoricalDailyRecords(
        coordinate: activeField.coordinate,
        startDate: startDate,
        endDate: latestEligible,
      );
    });

// 9. Navigation Tab Index Provider
class NavigationTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final navigationTabIndexProvider = NotifierProvider<NavigationTabNotifier, int>(
  NavigationTabNotifier.new,
);
