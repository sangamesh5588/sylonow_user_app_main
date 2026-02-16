import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'logger.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.warning('Location service not enabled', tag: 'LocationService');
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.warning('Location permission denied', tag: 'LocationService');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.warning('Location permission denied forever', tag: 'LocationService');
        return null;
      }

      // Force fresh location with best accuracy settings
      // This helps ensure we get the most current location instead of cached
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,  // Use best accuracy for fresh location
          distanceFilter: 0,  // Don't filter by distance - get exact location
          timeLimit: Duration(seconds: 30),  // Increased timeout for fresh fix
        ),
      );

      Logger.success(
        'Fresh position obtained: ${position.latitude}, ${position.longitude}',
        tag: 'LocationService',
      );
      return position;
    } catch (e) {
      Logger.error('Error in getCurrentLocation', tag: 'LocationService', error: e);

      // If fresh location fails, try to get last known position as fallback
      try {
        Logger.warning('Attempting to get last known position as fallback', tag: 'LocationService');
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          Logger.success(
            'Last known position obtained: ${lastPosition.latitude}, ${lastPosition.longitude}',
            tag: 'LocationService',
          );
          return lastPosition;
        }
      } catch (fallbackError) {
        Logger.error('Error getting last known position', tag: 'LocationService', error: fallbackError);
      }

      return null;
    }
  }

  Future<String> getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];

      return "${place.street}, ${place.locality}, ${place.postalCode}";
    } catch (e) {
      return "Location not found";
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
