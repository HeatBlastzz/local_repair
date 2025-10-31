import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_application_test/utils/logger.dart';

class GoongService {


  /// Lấy gợi ý địa chỉ từ Goong Autocomplete API
  static Future<List<GoongPlace>> getAutocompleteSuggestions(
    String input,
  ) async {
    if (input.isEmpty) return [];

    final uri = Uri.https(_baseUrl, '/Place/AutoComplete', {
      'api_key': _apiKey,
      'input': input,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List? ?? [];

        return predictions
            .map((prediction) => GoongPlace.fromJson(prediction))
            .toList();
      }
    } catch (e) {
      AppLogger.map('Lỗi Autocomplete: $e');
    }
    return [];
  }

  /// Lấy chi tiết địa điểm từ Goong Place Detail API
  static Future<GoongPlaceDetail?> getPlaceDetails(String placeId) async {
    final uri = Uri.https(_baseUrl, '/Place/Detail', {
      'api_key': _apiKey,
      'place_id': placeId,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        if (result != null) {
          return GoongPlaceDetail.fromJson(result);
        }
      }
    } catch (e) {
      AppLogger.map('Lỗi Place Detail: $e');
    }
    return null;
  }

  /// Chuyển tọa độ thành địa chỉ bằng Goong Geocoding API
  static Future<String?> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    final uri = Uri.https(_baseUrl, '/Geocode', {
      'api_key': _apiKey,
      'latlng': '$lat,$lng',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];

        if (results.isNotEmpty) {
          final firstResult = results.first;
          return firstResult['formatted_address'] as String?;
        }
      }
    } catch (e) {
      AppLogger.map('Lỗi Reverse Geocoding: $e');
    }
    return null;
  }

  /// Chuyển địa chỉ thành tọa độ
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    final uri = Uri.https(_baseUrl, '/Geocode', {
      'api_key': _apiKey,
      'address': address,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];

        if (results.isNotEmpty) {
          final location = results.first['geometry']['location'];
          final lng = (location['lng'] ?? 0.0).toDouble();
          final lat = (location['lat'] ?? 0.0).toDouble();
          return Position(lng, lat);
        }
      }
    } catch (e) {
      AppLogger.map('Lỗi Geocoding: $e');
    }
    return null;
  }
}

/// Model cho Goong Place (Autocomplete result)
class GoongPlace {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  GoongPlace({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory GoongPlace.fromJson(Map<String, dynamic> json) {
    return GoongPlace(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }
}

/// Model cho Goong Place Detail
class GoongPlaceDetail {
  final String placeId;
  final String name;
  final String formattedAddress;
  final Position location; // Thay thế LatLng bằng Position
  final String? phoneNumber;
  final double? rating;

  GoongPlaceDetail({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.location,
    this.phoneNumber,
    this.rating,
  });

  factory GoongPlaceDetail.fromJson(Map<String, dynamic> json) {
    final location = json['geometry']['location'];
    final lng = (location['lng'] ?? 0.0).toDouble();
    final lat = (location['lat'] ?? 0.0).toDouble();
    return GoongPlaceDetail(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      location: Position(lng, lat),
      phoneNumber: json['formatted_phone_number'],
      rating: json['rating']?.toDouble(),
    );
  }

  /// Chuyển đổi thành GeoPoint để lưu vào Firestore
  GeoPoint toGeoPoint() {
    final lat = location.lat.toDouble();
    final lng = location.lng.toDouble();
    return GeoPoint(lat, lng);
  }
}
