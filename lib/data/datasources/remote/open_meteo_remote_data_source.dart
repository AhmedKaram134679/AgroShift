import 'package:agro_shift/data/models/open_meteo_dto.dart';
import 'package:dio/dio.dart';

/// Concrete remote data source querying Open-Meteo ERA5-Land Archive and Forecast APIs.
class OpenMeteoRemoteDataSource {
  final Dio _dio;

  static const String _archiveBaseUrl =
      'https://archive-api.open-meteo.com/v1/archive';
  static const String _forecastBaseUrl =
      'https://api.open-meteo.com/v1/forecast';

  OpenMeteoRemoteDataSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          );

  Future<OpenMeteoDailyResponseDto> fetchHistoricalDaily({
    required double latitude,
    required double longitude,
    required String startDateIso,
    required String endDateIso,
  }) async {
    final response = await _dio.get(
      _archiveBaseUrl,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'start_date': startDateIso,
        'end_date': endDateIso,
        'daily': 'temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum',
        'timezone': 'Africa/Cairo',
        'models': 'era5_land',
      },
    );

    return OpenMeteoDailyResponseDto.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<OpenMeteoDailyResponseDto> fetchForecastDaily({
    required double latitude,
    required double longitude,
    required int forecastDays,
  }) async {
    final response = await _dio.get(
      _forecastBaseUrl,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'forecast_days': forecastDays,
        'daily': 'temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum',
        'timezone': 'Africa/Cairo',
      },
    );

    return OpenMeteoDailyResponseDto.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
