import 'package:geolocator/geolocator.dart';

class AppLocation {
  const AppLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.code);

  final String code;
}

class LocationService {
  Future<AppLocation> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('LOCATION_SERVICE_DISABLED');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('LOCATION_PERMISSION_DENIED');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException('LOCATION_PERMISSION_DENIED_FOREVER');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
