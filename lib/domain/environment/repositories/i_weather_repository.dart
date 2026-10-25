import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';

/// Provider-independent contract for weather and agro-climatological data.
abstract class IWeatherRepository {
  /// Fetches historical daily agro records for a given coordinate and date range.
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalDailyRecords({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetches forecast daily agro records for a given coordinate up to [days] ahead.
  Future<Result<List<DailyAgroRecord>, Failure>> getForecastDailyRecords({
    required Coordinate coordinate,
    required int days,
  });
}
