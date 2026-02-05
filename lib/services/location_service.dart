// lib/services/location_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Conditional import for web geolocation
import 'location_service_stub.dart'
    if (dart.library.html) 'location_service_web.dart' as platform;

class LocationPosition {
  final double latitude;
  final double longitude;

  LocationPosition({required this.latitude, required this.longitude});
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  String? _googleApiKey;

  /// Initialize the service by fetching API key from backend
  Future<void> initialize() async {
    if (_googleApiKey != null) return;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/config/maps-api-key'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _googleApiKey = data['api_key'];
        if (kDebugMode) {
          print('Google Maps API key loaded from backend');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching API key: $e');
      }
    }
  }

  String get _apiKey => _googleApiKey ?? '';

  /// Get current position using platform-specific implementation
  Future<LocationPosition?> getCurrentPosition() async {
    try {
      return await platform.getCurrentPosition();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current position: $e');
      }
      return null;
    }
  }

  /// Get address from coordinates using Google Geocoding API
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting address: $e');
      }
      return null;
    }
  }

  /// Get coordinates from address using Google Geocoding API
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'lat': location['lat'].toDouble(),
            'lng': location['lng'].toDouble(),
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting coordinates: $e');
      }
      return null;
    }
  }

  /// Search for places (autocomplete)
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedQuery&key=$_apiKey&types=geocode',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List).map((p) => {
            'description': p['description'],
            'place_id': p['place_id'],
          }).toList();
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error searching places: $e');
      }
      return [];
    }
  }

  /// Get place details (coordinates) from place_id
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,formatted_address&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          return {
            'lat': location['lat'].toDouble(),
            'lng': location['lng'].toDouble(),
            'address': result['formatted_address'],
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting place details: $e');
      }
      return null;
    }
  }

  /// Calculate distance between two points in kilometers using Haversine formula
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
