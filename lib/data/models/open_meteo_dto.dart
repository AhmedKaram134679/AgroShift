/// Raw DTO representing Open-Meteo daily response.
class OpenMeteoDailyResponseDto {
  final double latitude;
  final double longitude;
  final double generationTimeMs;
  final int utcOffsetSeconds;
  final String timezone;
  final double? elevation;
  final Map<String, dynamic> dailyUnits;
  final Map<String, dynamic> daily;

  const OpenMeteoDailyResponseDto({
    required this.latitude,
    required this.longitude,
    required this.generationTimeMs,
    required this.utcOffsetSeconds,
    required this.timezone,
    this.elevation,
    required this.dailyUnits,
    required this.daily,
  });

  factory OpenMeteoDailyResponseDto.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['daily_units'];
    final rawDaily = json['daily'];

    return OpenMeteoDailyResponseDto(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      generationTimeMs: (json['generationtime_ms'] as num).toDouble(),
      utcOffsetSeconds: (json['utc_offset_seconds'] as num).toInt(),
      timezone: json['timezone'] as String? ?? 'UTC',
      elevation: (json['elevation'] as num?)?.toDouble(),
      dailyUnits: rawUnits is Map ? Map<String, dynamic>.from(rawUnits) : {},
      daily: rawDaily is Map ? Map<String, dynamic>.from(rawDaily) : {},
    );
  }
}
