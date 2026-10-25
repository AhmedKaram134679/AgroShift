import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Table representing registered farm fields in Egypt.
class FarmFieldsTable extends Table {
  TextColumn get id => text()();
  TextColumn get nameAr => text()();
  TextColumn get governorateAr => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get areaInFeddan => real()();
  TextColumn get soilType => text()(); // clay, clayLoam, sandyLoam, sandy
  TextColumn get activeCropId => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table tracking explicitly deleted default fields to avoid resurrecting them on restart.
class DeletedDefaultFieldIdsTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table caching daily agro-meteorological records.
class CachedDailyRecordsTable extends Table {
  TextColumn get cacheKey =>
      text()(); // e.g., hist_lat_lon_start_end or fc_lat_lon_days
  DateTimeColumn get recordDate => dateTime()();
  RealColumn get maxTemperatureC => real()();
  RealColumn get minTemperatureC => real()();
  RealColumn get precipitationMm =>
      real().nullable()(); // null = missing, 0.0 = measured zero
  RealColumn get referenceEt0Mm => real().nullable()(); // null = missing

  // Provenance metadata
  TextColumn get providerName => text()();
  TextColumn get datasetName => text()();
  RealColumn get requestedLatitude => real()();
  RealColumn get requestedLongitude => real()();
  RealColumn get gridLatitude => real()();
  RealColumn get gridLongitude => real()();
  RealColumn get gridElevationMeters => real().nullable()();
  DateTimeColumn get acquisitionTimestamp => dateTime()();
  TextColumn get scientificDisclaimerAr => text()();

  // Freshness & storage timestamp
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey, recordDate};
}

@DriftDatabase(
  tables: [
    FarmFieldsTable,
    DeletedDefaultFieldIdsTable,
    CachedDailyRecordsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Schema migrations will be handled here incrementally
    },
  );
}
