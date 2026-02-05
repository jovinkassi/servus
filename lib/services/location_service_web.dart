// lib/services/location_service_web.dart
// Web implementation using browser's Geolocation API
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'location_service.dart';

Future<LocationPosition?> getCurrentPosition() async {
  try {
    final completer = Completer<LocationPosition?>();

    html.window.navigator.geolocation.getCurrentPosition().then((position) {
      completer.complete(LocationPosition(
        latitude: position.coords!.latitude!.toDouble(),
        longitude: position.coords!.longitude!.toDouble(),
      ));
    }).catchError((error) {
      if (kDebugMode) {
        print('Geolocation error: $error');
      }
      completer.complete(null);
    });

    return completer.future;
  } catch (e) {
    if (kDebugMode) {
      print('Error getting current position on web: $e');
    }
    return null;
  }
}
