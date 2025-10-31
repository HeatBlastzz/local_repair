import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/services/map_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_application_test/utils/logger.dart';

class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({super.key});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  MapboxMap? _mapboxMap;
  Point _currentMapCenter = Point(coordinates: Position(105.7469, 10.0452));
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<GoongPlace> _suggestions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  Future<void> _fetchAutocompleteSuggestions(String input) async {
    if (input.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final results = await GoongService.getAutocompleteSuggestions(input);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.map('Lỗi khi lấy gợi ý địa chỉ: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    if (mounted) {
      setState(() {
        _suggestions = [];
        _isLoading = true;
      });
    }

    try {
      final placeDetail = await GoongService.getPlaceDetails(placeId);
      if (placeDetail != null && mounted) {
        final targetPoint = Point(coordinates: placeDetail.location);
        _mapboxMap?.flyTo(
          CameraOptions(center: targetPoint, zoom: 16.0),
          MapAnimationOptions(duration: 1500),
        );
        setState(() => _currentMapCenter = targetPoint);
      }
    } catch (e) {
      AppLogger.map('Lỗi khi lấy chi tiết địa điểm: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn một địa điểm'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: 'https://tiles.goong.io/assets/goong_map_web.json?api_key=$_goongMapKey',
            cameraOptions: CameraOptions(
              center: _currentMapCenter,
              zoom: 12.0,
            ),
            onCameraChangeListener: (data) async {
              final newCenter = data.cameraState.center;
              setState(() {
                _currentMapCenter = newCenter;
              });
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 50.0),
              child: Icon(Icons.location_pin, color: Colors.red, size: 50),
            ),
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Tìm kiếm địa chỉ",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        _fetchAutocompleteSuggestions(value);
                      });
                    },
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          dense: true,
                          onTap: () {
                            _searchController.text = suggestion.description;
                            _fetchPlaceDetails(suggestion.placeId);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Xác nhận vị trí này'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        try {
                          final centerCoordinates = _currentMapCenter.coordinates;
                          final lat = centerCoordinates.lat.toDouble();
                          final lng = centerCoordinates.lng.toDouble();

                          final address = await GoongService.getAddressFromCoordinates(lat, lng);
                          if (mounted) {
                            Navigator.pop(context, {
                              'coordinates': LatLng(lat, lng),
                              'address': address ?? 'Địa chỉ không xác định',
                            });
                          }
                        } catch (e) {
                          AppLogger.map('Lỗi khi xác nhận vị trí: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 90,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'picker_zoom_in',
                  mini: true,
                  onPressed: () async {
                    try {
                      final currentZoom = (await _mapboxMap?.getCameraState())?.zoom ?? 12.0;
                      _mapboxMap?.flyTo(
                        CameraOptions(zoom: currentZoom + 1),
                        MapAnimationOptions(duration: 300),
                      );
                    } catch (e) {
                      AppLogger.map('Lỗi khi zoom in: $e');
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'picker_zoom_out',
                  mini: true,
                  onPressed: () async {
                    try {
                      final currentZoom = (await _mapboxMap?.getCameraState())?.zoom ?? 12.0;
                      _mapboxMap?.flyTo(
                        CameraOptions(zoom: currentZoom - 1),
                        MapAnimationOptions(duration: 300),
                      );
                    } catch (e) {
                      AppLogger.map('Lỗi khi zoom out: $e');
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}