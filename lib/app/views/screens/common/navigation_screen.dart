import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:flutter_application_test/utils/logger.dart';

class NavigationScreen extends StatefulWidget {
  final Point startPoint;
  final Point endPoint;
  final String destinationAddress;

  const NavigationScreen({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.destinationAddress,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  String? _distance;
  String? _duration;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppLogger.map(
      'NavigationScreen initialized: Start(${widget.startPoint.coordinates.lat}, ${widget.startPoint.coordinates.lng}) -> End(${widget.endPoint.coordinates.lat}, ${widget.endPoint.coordinates.lng})',
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    AppLogger.map('Map created successfully');

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      _mapboxMap?.annotations.createPointAnnotationManager().then((
        pointManager,
      ) {
        _pointAnnotationManager = pointManager;
        AppLogger.map('Point annotation manager created');
        _getRouteAndDraw();
      });
    } catch (e) {
      AppLogger.map('Error creating point annotation manager: $e');
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  void _setError(String error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final geolocator.Position position = await _determinePosition();
      final currentLocation = Point(
        coordinates: Position(position.longitude, position.latitude),
      );
      _mapboxMap?.flyTo(
        CameraOptions(center: currentLocation, zoom: 14.0),
        MapAnimationOptions(duration: 1500),
      );
    } catch (e) {
      AppLogger.map('Error centering on current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy vị trí hiện tại: $e')),
        );
      }
    }
  }

  Future<geolocator.Position> _determinePosition() async {
    bool serviceEnabled;
    geolocator.LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Dịch vụ vị trí đã bị tắt.');
    }

    permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        return Future.error('Quyền truy cập vị trí đã bị từ chối');
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      return Future.error(
        'Quyền truy cập vị trí bị từ chối vĩnh viễn, không thể yêu cầu quyền.',
      );
    }

    return await geolocator.Geolocator.getCurrentPosition();
  }

  Future<void> _getRouteAndDraw() async {
    try {
      AppLogger.map('Starting route calculation...');
      await _addMarkers();

      final url = Uri.parse(
        'https://rsapi.goong.io/Direction?origin=${widget.startPoint.coordinates.lat},${widget.startPoint.coordinates.lng}&destination=${widget.endPoint.coordinates.lat},${widget.endPoint.coordinates.lng}&vehicle=bike&api_key=$_goongApiKey',
      );

      AppLogger.map('Calling Goong API: ${url.toString()}');

      final response = await http.get(url);
      AppLogger.map('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        AppLogger.map('API Response body: ${jsonResponse.toString()}');

        final routes = jsonResponse['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>?;
          if (route == null) {
            _setError('Dữ liệu tuyến đường không hợp lệ.');
            return;
          }

          final overviewPolyline =
              route['overview_polyline']?['points'] as String?;
          final legs = route['legs'] as List?;

          if (mounted && legs != null && legs.isNotEmpty) {
            final firstLeg = legs.first as Map<String, dynamic>?;
            setState(() {
              _distance = firstLeg?['distance']?['text'] as String?;
              _duration = firstLeg?['duration']?['text'] as String?;
            });
            AppLogger.map(
              'Route info: Distance=$_distance, Duration=$_duration',
            );
          }

          if (overviewPolyline != null) {
            await _drawPolyline(overviewPolyline);
            _setLoading(false);
          } else {
            _setError('Không thể lấy được hình dạng tuyến đường từ API.');
          }
        } else {
          _setError('Không tìm thấy tuyến đường phù hợp.');
        }
      } else {
        AppLogger.map('API Error: ${response.body}');
        _setError('Lỗi API: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.map('Error getting route: $e');
      _setError('Lỗi khi lấy chỉ đường: $e');
    }
  }

  Future<void> _addMarkers() async {
    try {
      // Load custom images
      final Uint8List startIconBytes = await _loadImageBytes(
        "assets/imgs/repairer_icon.png",
      );
      final Uint8List endIconBytes = await _loadImageBytes(
        "assets/imgs/user_icon.png",
      );

      await _pointAnnotationManager?.createMulti([
        PointAnnotationOptions(
          geometry: widget.startPoint,
          image: startIconBytes,
          iconSize: 1.5,
        ),
        PointAnnotationOptions(
          geometry: widget.endPoint,
          image: endIconBytes,
          iconSize: 1.0,
        ),
      ]);
      AppLogger.map('Custom markers added successfully');
    } catch (e) {
      AppLogger.map('Error adding custom markers: $e');
      // Fallback to default markers if custom images fail
      try {
        await _pointAnnotationManager?.createMulti([
          PointAnnotationOptions(
            geometry: widget.startPoint,
            iconSize: 1.5,
            iconImage: 'marker-15',
            iconOffset: [0, -7.5],
          ),
          PointAnnotationOptions(
            geometry: widget.endPoint,
            iconSize: 1.0,
            iconImage: 'marker-15',
            iconOffset: [0, -7.5],
          ),
        ]);
        AppLogger.map('Fallback to default markers successful');
      } catch (fallbackError) {
        AppLogger.map('Error with fallback markers: $fallbackError');
      }
    }
  }

  Future<Uint8List> _loadImageBytes(String assetName) async {
    try {
      final ByteData byteData = await rootBundle.load(assetName);
      return byteData.buffer.asUint8List();
    } catch (e) {
      AppLogger.map('Error loading image $assetName: $e');
      rethrow;
    }
  }

  Future<void> _drawPolyline(String encodedPolyline) async {
    try {
      List<PointLatLng> points = PolylinePoints().decodePolyline(
        encodedPolyline,
      );
      AppLogger.map('Decoded ${points.length} points from polyline');

      if (points.isEmpty) {
        AppLogger.map('No points decoded from polyline');
        return;
      }

      List<List<double>> coordinates = points
          .map((point) => [point.longitude, point.latitude])
          .toList();

      // Kiểm tra sự tồn tại trước khi xóa
      if (await _mapboxMap?.style.styleLayerExists('route-layer') ?? false) {
        await _mapboxMap?.style.removeStyleLayer('route-layer');
      }
      if (await _mapboxMap?.style.styleSourceExists('route-source') ?? false) {
        await _mapboxMap?.style.removeStyleSource('route-source');
      }

      await _mapboxMap?.style.addSource(
        GeoJsonSource(
          id: "route-source",
          data: json.encode({
            "type": "Feature",
            "properties": {},
            "geometry": {"type": "LineString", "coordinates": coordinates},
          }),
        ),
      );

      await _mapboxMap?.style.addLayer(
        LineLayer(
          id: "route-layer",
          sourceId: "route-source",
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: Colors.blue.value,
          lineWidth: 7.0,
          lineOpacity: 0.8,
        ),
      );

      AppLogger.map('Polyline drawn successfully');
    } catch (e) {
      AppLogger.map('Error drawing polyline: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi vẽ tuyến đường: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉ đường'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri:
                'https://tiles.goong.io/assets/goong_map_web.json?api_key=$_goongMapKey',
            cameraOptions: CameraOptions(center: widget.startPoint, zoom: 14.0),
          ),
          if (_isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Đang tính toán tuyến đường...'),
                    ],
                  ),
                ),
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Lỗi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(_errorMessage!),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isLoading && _duration != null && _errorMessage == null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đi đến: ${widget.destinationAddress}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_bike,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _duration!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Text(
                            _distance!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'nav_zoom_in',
            mini: true,
            onPressed: () async {
              try {
                final currentZoom =
                    (await _mapboxMap?.getCameraState())?.zoom ?? 0;
                _mapboxMap?.flyTo(
                  CameraOptions(zoom: currentZoom + 1),
                  MapAnimationOptions(duration: 300),
                );
              } catch (e) {
                AppLogger.map('Error zooming in: $e');
              }
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'nav_zoom_out',
            mini: true,
            onPressed: () async {
              try {
                final currentZoom =
                    (await _mapboxMap?.getCameraState())?.zoom ?? 0;
                _mapboxMap?.flyTo(
                  CameraOptions(zoom: currentZoom - 1),
                  MapAnimationOptions(duration: 300),
                );
              } catch (e) {
                AppLogger.map('Error zooming out: $e');
              }
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'nav_my_location',
            onPressed: _centerOnCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
