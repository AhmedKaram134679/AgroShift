/// Selected geographic location returned by the Egypt map picker.
class SelectedLocation {
  final double latitude;
  final double longitude;
  final String governorateAr;

  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    required this.governorateAr,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedLocation &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          governorateAr == other.governorateAr;

  @override
  int get hashCode => Object.hash(latitude, longitude, governorateAr);

  @override
  String toString() =>
      'SelectedLocation(lat: $latitude, lon: $longitude, gov: $governorateAr)';
}

