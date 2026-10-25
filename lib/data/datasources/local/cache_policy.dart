import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';

/// Policy governing cache freshness and staleness for agro-meteorological data.
class CachePolicy {
  CachePolicy._();

  /// Short-term numerical weather predictions lose accuracy rapidly past 6 hours.
  static const Duration forecastTtl = Duration(hours: 6);

  /// Historical reanalysis records (e.g. ERA5) are static once finalized, but
  /// provisional/recent records may be re-run; 7-day TTL allows periodic sync.
  static const Duration historicalTtl = Duration(days: 7);

  /// Evaluates whether a cached dataset is within its freshness horizon.
  static bool isFresh({
    required DateTime cachedAt,
    required bool isForecast,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final ttl = isForecast ? forecastTtl : historicalTtl;
    return currentTime.difference(cachedAt) <= ttl;
  }
}

/// Result of evaluating a cache entry for a query.
class CacheLookupResult {
  final List<DailyAgroRecord> records;
  final DateTime cachedAt;
  final bool isFresh;

  const CacheLookupResult({
    required this.records,
    required this.cachedAt,
    required this.isFresh,
  });
}
