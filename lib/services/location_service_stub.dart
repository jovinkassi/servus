// lib/services/location_service_stub.dart
// Stub implementation for non-web platforms (mobile)
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'location_service.dart';

Future<LocationPosition?> getCurrentPosition() async {
  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print('Location services are disabled.');
      }
      return null;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('Location permissions are denied');
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('Location permissions are permanently denied');
      }
      return null;
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return LocationPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (e) {
    if (kDebugMode) {
      print('Error getting current position: $e');
    }
    return null;
  }
}
