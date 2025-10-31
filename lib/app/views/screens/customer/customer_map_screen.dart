import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_test/app/controllers/job_controller.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/work_session_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../common/job_details_screen.dart';
import 'contact_list_screen.dart';
import 'package:flutter_application_test/app/views/screens/common/place_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide ScreenCoordinate;
import '../../../../utils/logger.dart';

class _ServiceOffering {
  final String serviceName;
  final double basePrice;
  final String majorId;
  _ServiceOffering({
    required this.serviceName,
    required this.basePrice,
    required this.majorId,
  });
}

class CustomerMapScreen extends StatefulWidget {
  final String? serviceCategory;
  final String? categoryName;

  const CustomerMapScreen({super.key, this.serviceCategory, this.categoryName});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

// Lớp xử lý sự kiện click trên marker
class _MyPointAnnotationClickListener
    implements OnPointAnnotationClickListener {
  final void Function(PointAnnotation annotation) onTap;

  _MyPointAnnotationClickListener(this.onTap);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation);
  }
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  final JobController _jobController = JobController();
  final FirestoreService _firestoreService = FirestoreService();
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  UserModel? _currentUser;
  PointAnnotation? _customerAnnotation;
  List<PointAnnotation> _repairerAnnotations = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _repairersSub;

  geolocator.Position? _customerPosition;

  final Map<String, Point> _repairerGeoPoints = {};
  final Map<String, ScreenCoordinate> _markerScreenCoords = {};
  List<JobModel> _repairerSchedule = [];

  Timer? _debounce;

  static const String REPAIRER_ICON_ID = "repairer-icon";
  static const String CUSTOMER_ICON_ID = "customer-icon";

  // Biến để lưu dữ liệu ảnh sau khi tải
  Uint8List? _repairerIconBytes;
  Uint8List? _customerIconBytes;

  final Map<String, UserModel> _repairerByAnnotationId = {};
  bool _isBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Tải ảnh và dữ liệu người dùng cùng lúc
    _loadAssets();
    _fetchCurrentUserData();
  }

  @override
  void dispose() {
    _repairersSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomerMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.serviceCategory != oldWidget.serviceCategory) {
      if (_pointAnnotationManager != null) {
        _clearAllRepairerMarkers();
        _attachRepairersListener();
      }
    }
  }

  // Hàm mới để tải tất cả assets cần thiết
  Future<void> _loadAssets() async {
    _repairerIconBytes = await _loadImageBytes("assets/imgs/repairer_icon.png");
    _customerIconBytes = await _loadImageBytes("assets/imgs/user_icon.png");
  }

  // Hàm mới để xóa tất cả marker của thợ
  Future<void> _clearAllRepairerMarkers() async {
    if (_pointAnnotationManager == null) return;

    // Xóa marker cũ
    for (var annotation in _repairerAnnotations) {
      await _pointAnnotationManager!.delete(annotation);
    }
    _repairerAnnotations.clear();
    _repairerByAnnotationId.clear();

    if (mounted) setState(() {});
  }

  Future<Uint8List> _loadImageBytes(String assetName) async {
    final ByteData byteData = await rootBundle.load(assetName);
    return byteData.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _mapboxMap?.compass.updateSettings(
      CompassSettings(enabled: true, position: OrnamentPosition.TOP_RIGHT),
    );
    _mapboxMap?.scaleBar.updateSettings(
      ScaleBarSettings(
        enabled: true,
        isMetricUnits: true,
        position: OrnamentPosition.TOP_LEFT,
      ),
    );

    _mapboxMap?.annotations.createPointAnnotationManager().then((value) {
      _pointAnnotationManager = value;
      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        _MyPointAnnotationClickListener(_onAnnotationTapped),
      );

      _getCurrentLocationAndMoveCamera(shouldFly: true);
      _attachRepairersListener();
    });
  }

  void _attachRepairersListener() {
    _repairersSub?.cancel();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'repairer')
        .where('status', whereIn: ['available', 'busy_instant']);

    if (widget.serviceCategory != null && widget.serviceCategory!.isNotEmpty) {
      query = query.where(
        'services.${widget.serviceCategory!}',
        isNotEqualTo: null,
      );
    }

    _repairersSub = query.snapshots().listen((snapshot) async {
      final allRepairers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      AppLogger.map('Tổng số thợ từ Firestore: ${allRepairers.length}');
      for (var repairer in allRepairers) {
        AppLogger.map(
          'Thợ ${repairer.name} - Status: ${repairer.status.name} - Majors: ${repairer.majors}',
        );
      }

      List<UserModel> filteredRepairers = [];
      if (widget.serviceCategory != null &&
          widget.serviceCategory!.isNotEmpty) {
        AppLogger.map('Đang lọc thợ cho dịch vụ: ${widget.serviceCategory}');

        for (var repairer in allRepairers) {
          final majorServices = repairer.services[widget.serviceCategory!];
          if (majorServices == null) continue;

          final offerings = majorServices['offerings'] as List<dynamic>?;
          final hasOfferings = offerings != null && offerings.isNotEmpty;

          if (hasOfferings) {
            filteredRepairers.add(repairer);
            AppLogger.map(
              '✅ Thợ ${repairer.name} được thêm vào danh sách (Status: ${repairer.status.name})',
            );
          } else {
            AppLogger.map('❌ Thợ ${repairer.name} không có offerings');
          }
        }

        AppLogger.map('Kết quả lọc: ${filteredRepairers.length} thợ phù hợp');
        for (var repairer in filteredRepairers) {
          AppLogger.map('- ${repairer.name} (${repairer.status.name})');
        }
      } else {
        filteredRepairers = allRepairers;
        AppLogger.map(
          'Không có service category, hiển thị tất cả ${filteredRepairers.length} thợ',
        );
      }

      await _refreshMarkersFromRepairers(filteredRepairers);
    });
  }

  Future<void> _refreshMarkersFromRepairers(List<UserModel> repairers) async {
    AppLogger.map(
      '_refreshMarkersFromRepairers được gọi với ${repairers.length} thợ',
    );

    if (_pointAnnotationManager == null || _repairerIconBytes == null) {
      AppLogger.map(
        '_pointAnnotationManager hoặc _repairerIconBytes null, thoát',
      );
      return;
    }

    // Xóa marker cũ
    AppLogger.map('Xóa ${_repairerAnnotations.length} marker cũ');
    for (var annotation in _repairerAnnotations) {
      await _pointAnnotationManager!.delete(annotation);
    }
    _repairerAnnotations.clear();
    _repairerByAnnotationId.clear();

    // Tạo marker mới
    final List<PointAnnotationOptions> optionsList = [];
    for (var repairer in repairers) {
      final addressMap = repairer.defaultAddress;
      if (addressMap != null && addressMap['coordinates'] != null) {
        final GeoPoint geoPoint = addressMap['coordinates'];
        optionsList.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(geoPoint.longitude, geoPoint.latitude),
            ),
            image: _repairerIconBytes,
            iconSize: 1.5,
          ),
        );
        AppLogger.map(
          'Tạo marker cho thợ ${repairer.name} tại (${geoPoint.latitude}, ${geoPoint.longitude}) - Status: ${repairer.status.name}',
        );
      } else {
        AppLogger.map('Thợ ${repairer.name} không có địa chỉ');
      }
    }

    AppLogger.map('Tạo ${optionsList.length} marker options');

    if (optionsList.isNotEmpty) {
      final createdAnnotations = await _pointAnnotationManager!.createMulti(
        optionsList,
      );
      AppLogger.map('Tạo thành công ${createdAnnotations.length} annotations');

      for (int i = 0; i < createdAnnotations.length; i++) {
        final annotation = createdAnnotations[i];
        if (annotation != null) {
          _repairerAnnotations.add(annotation);
          _repairerByAnnotationId[annotation.id] = repairers[i];
          AppLogger.map(
            'Thêm annotation ${annotation.id} cho thợ ${repairers[i].name}',
          );
        }
      }
    }

    AppLogger.map('Tổng số marker cuối cùng: ${_repairerAnnotations.length}');

    // Kiểm tra xem marker có được hiển thị trên bản đồ không
    if (_mapboxMap != null) {
      _mapboxMap!.triggerRepaint();
      AppLogger.map('Đã trigger repaint bản đồ');
    }

    if (mounted) setState(() {});
  }

  void _onAnnotationTapped(PointAnnotation annotation) {
    AppLogger.map(
      '_onAnnotationTapped được gọi cho annotation: ${annotation.id}',
    );

    if (_isBottomSheetOpen) {
      AppLogger.map('Bottom sheet đang mở, bỏ qua tap');
      return;
    }

    if (annotation.id == _customerAnnotation?.id) {
      AppLogger.map('Đây là marker của customer, bỏ qua');
      return;
    }

    final repairer = _repairerByAnnotationId[annotation.id];
    if (repairer != null) {
      AppLogger.map(
        'Tìm thấy thợ: ${repairer.name} (Status: ${repairer.status.name})',
      );

      setState(() {
        _isBottomSheetOpen = true;
      });

      AppLogger.map('Mở bottom sheet cho thợ ${repairer.name}');
      _showRepairerDetailsSheet(repairer).whenComplete(() {
        if (mounted) {
          setState(() {
            _isBottomSheetOpen = false;
          });
          AppLogger.map('Bottom sheet đã đóng');
        }
      });
    } else {
      AppLogger.map('Không tìm thấy thợ cho annotation: ${annotation.id}');
    }
  }

  void _onCameraChangeListener(CameraChangedEventData event) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      _updateMarkerScreenCoordinates();
    });
  }

  Future<void> _fetchCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userModel = await _firestoreService.getUser(user.uid);
      if (mounted) setState(() => _currentUser = userModel);
    }
  }

  Future<void> _updateAllMapMarkers() async {
    if (_pointAnnotationManager == null || _repairerIconBytes == null) return;

    // Xóa từng annotation của thợ sửa chữa cũ
    for (var annotation in _repairerAnnotations) {
      await _pointAnnotationManager!.delete(annotation);
    }
    _repairerAnnotations.clear();
    _repairerByAnnotationId.clear();

    // Tải lại vị trí khách hàng để đảm bảo nó luôn được vẽ
    await _getCurrentLocationAndMoveCamera();

    List<UserModel> repairers;
    if (widget.serviceCategory != null && widget.serviceCategory!.isNotEmpty) {
      // Lấy tất cả thợ có trạng thái available và busy_instant
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'repairer')
          .where('status', whereIn: ['available', 'busy_instant'])
          .get();

      final allRepairers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Lọc thợ có chuyên ngành và dịch vụ phù hợp
      repairers = [];
      if (widget.serviceCategory != null &&
          widget.serviceCategory!.isNotEmpty) {
        // Lọc phía client ở đây cũng nên được thay thế bằng truy vấn, nhưng để đây như một fallback
        for (var repairer in allRepairers) {
          final majorServices = repairer.services[widget.serviceCategory!];
          if (majorServices != null) {
            final offerings = majorServices['offerings'] as List<dynamic>?;
            if (offerings != null && offerings.isNotEmpty) {
              repairers.add(repairer);
            }
          }
        }
      } else {
        repairers = allRepairers;
      }
    } else {
      // Nếu không chọn dịch vụ cụ thể, lấy tất cả thợ available và busy_instant
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'repairer')
          .where('status', whereIn: ['available', 'busy_instant'])
          .get();
      repairers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    }

    if (repairers.isEmpty) {
      if (mounted) {
        // Hiển thị thông báo nếu không tìm thấy thợ cho dịch vụ cụ thể
        if (widget.serviceCategory != null &&
            widget.serviceCategory!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không tìm thấy thợ nào cho dịch vụ "${widget.categoryName ?? 'này'}". Có thể thợ đang offline hoặc chưa đăng ký dịch vụ này.',
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      return;
    }
    ;

    List<PointAnnotationOptions> optionsList = [];
    for (var repairer in repairers) {
      final addressMap = repairer.defaultAddress;
      if (addressMap != null && addressMap['coordinates'] != null) {
        final GeoPoint geoPoint = addressMap['coordinates'];
        optionsList.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(geoPoint.longitude, geoPoint.latitude),
            ),
            image: _repairerIconBytes,
            iconSize: 1.5,
          ),
        );
      }
    }

    if (optionsList.isNotEmpty) {
      final createdAnnotations = await _pointAnnotationManager!.createMulti(
        optionsList,
      );

      _repairerAnnotations.clear();
      _repairerByAnnotationId.clear();

      for (int i = 0; i < createdAnnotations.length; i++) {
        final annotation = createdAnnotations[i];
        if (annotation != null) {
          _repairerAnnotations.add(annotation);
          _repairerByAnnotationId[annotation.id] = repairers[i];
        }
      }
    }
  }

  Future<void> _updateMarkerScreenCoordinates() async {
    if (_mapboxMap == null) return;

    final allPoints = Map<String, Point>.from(_repairerGeoPoints);
    if (_customerPosition != null) {
      allPoints['__customer__'] = Point(
        coordinates: Position(
          _customerPosition!.longitude,
          _customerPosition!.latitude,
        ),
      );
    }

    final newCoords = await _mapboxMap!.pixelsForCoordinates(
      allPoints.values.toList(),
    );

    if (mounted) {
      setState(() {
        _markerScreenCoords.clear();
        final keys = allPoints.keys.toList();
        for (int i = 0; i < newCoords.length; i++) {
          final coord = newCoords[i];
          if (coord != null) {
            _markerScreenCoords[keys[i]] = coord;
          }
        }
      });
    }
  }

  Future<void> _getCurrentLocationAndMoveCamera({
    bool shouldFly = false,
  }) async {
    if (_mapboxMap == null ||
        _pointAnnotationManager == null ||
        _customerIconBytes == null)
      return;
    try {
      geolocator.Position position = await _determinePosition();
      final customerPoint = Point(
        coordinates: Position(position.longitude, position.latitude),
      );

      if (_currentUser != null) {
        final currentGeoPoint = GeoPoint(position.latitude, position.longitude);
        await _firestoreService.updateUserLocation(
          _currentUser!.uid,
          currentGeoPoint,
        );
      }

      if (_customerAnnotation == null) {
        final options = PointAnnotationOptions(
          geometry: customerPoint,
          image: _customerIconBytes,
          iconSize: 1.0,
        );
        _customerAnnotation = await _pointAnnotationManager!.create(options);
      } else {
        _customerAnnotation!.geometry = customerPoint;
        await _pointAnnotationManager!.update(_customerAnnotation!);
      }

      if (shouldFly) {
        _mapboxMap!.flyTo(
          CameraOptions(center: customerPoint, zoom: 14.0),
          MapAnimationOptions(duration: 2000),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lấy vị trí: $e')));
      }
    }
  }

  // --- Widget Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Tìm thợ quanh đây'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts_outlined),
            tooltip: 'Danh bạ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: MapWidget(
        onMapCreated: _onMapCreated,
        styleUri:
            'https://tiles.goong.io/assets/goong_map_web.json?api_key=$_goongMapKey',
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(105.7469, 10.0452)),
          zoom: 12.0,
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Nút refresh dữ liệu thợ
          FloatingActionButton(
            heroTag: 'refresh_repairers',
            mini: true,
            onPressed: () async {
              await _updateAllMapMarkers();

              _attachRepairersListener();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã làm mới danh sách thợ.')),
                );
              }
            },
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            onPressed: () async {
              final currentZoom =
                  (await _mapboxMap?.getCameraState())?.zoom ?? 0;
              _mapboxMap?.flyTo(
                CameraOptions(zoom: currentZoom + 1),
                MapAnimationOptions(duration: 300),
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            onPressed: () async {
              final currentZoom =
                  (await _mapboxMap?.getCameraState())?.zoom ?? 0;
              _mapboxMap?.flyTo(
                CameraOptions(zoom: currentZoom - 1),
                MapAnimationOptions(duration: 300),
              );
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'my_location',
            onPressed: () => _getCurrentLocationAndMoveCamera(shouldFly: true),
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  // Hàm hiển thị bottom sheet
  Future<void> _showRepairerDetailsSheet(UserModel repairer) async {
    AppLogger.map(
      '_showRepairerDetailsSheet được gọi cho thợ: ${repairer.name}',
    );
    AppLogger.map('Trạng thái thợ: ${repairer.status.name}');

    // Ngay khi mở sheet, tải lịch trình của thợ
    final schedule = await _firestoreService
        .getScheduledAndConfirmedJobsForRepairer(repairer.uid);
    AppLogger.map('Lịch trình thợ: ${schedule.length} job');

    if (mounted) {
      setState(() {
        _repairerSchedule = schedule;
      });
    }

    // 1. Tạo danh sách dịch vụ "phẳng"
    final List<_ServiceOffering> serviceOfferings = [];
    repairer.services.forEach((majorId, majorData) {
      final offerings = majorData['offerings'] as List<dynamic>? ?? [];
      for (var offering in offerings) {
        serviceOfferings.add(
          _ServiceOffering(
            serviceName: offering['name'] ?? 'Dịch vụ không tên',
            basePrice: (offering['base_price'] ?? 0.0).toDouble(),
            majorId: majorId,
          ),
        );
      }
    });

    AppLogger.map('Dịch vụ của thợ: ${serviceOfferings.length} offerings');

    _ServiceOffering? selectedService;
    double? estimatedPrice;
    // 2. Tự động chọn dịch vụ nếu có thể
    if (widget.serviceCategory != null) {
      final matchingServices = serviceOfferings
          .where((s) => s.majorId == widget.serviceCategory)
          .toList();
      if (matchingServices.isNotEmpty) {
        selectedService = matchingServices.first;
        AppLogger.map('Tự động chọn dịch vụ: ${selectedService.serviceName}');
      } else {
        AppLogger.map(
          'Không tìm thấy dịch vụ phù hợp cho major: ${widget.serviceCategory}',
        );
      }
    }

    AppLogger.map('Hiển thị bottom sheet...');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        bool isInitialBuild = true;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            void calculatePrice() {
              if (selectedService == null) return;

              final basePrice = selectedService!.basePrice;
              setStateSheet(() {
                estimatedPrice = (basePrice / 1000).round() * 1000;
              });
            }

            if (isInitialBuild && selectedService != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                calculatePrice();
              });
              isInitialBuild = false;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 20,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              repairer.name ?? 'Thợ sửa chữa',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    repairer.defaultAddress?['address_line'] ??
                                        'Không có địa chỉ',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            _buildScheduleList(repairer),
                            if (selectedService != null &&
                                widget.serviceCategory != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.work_outline,
                                  color: Colors.blue,
                                ),
                                title: const Text('Dịch vụ được chọn'),
                                subtitle: Text(
                                  selectedService!.serviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            else
                              DropdownButtonFormField<_ServiceOffering>(
                                decoration: const InputDecoration(
                                  labelText: 'Chọn một dịch vụ',
                                  border: OutlineInputBorder(),
                                ),
                                value: selectedService,
                                items: serviceOfferings.map((
                                  _ServiceOffering service,
                                ) {
                                  return DropdownMenuItem<_ServiceOffering>(
                                    value: service,
                                    child: Text(service.serviceName),
                                  );
                                }).toList(),
                                onChanged: (_ServiceOffering? newValue) {
                                  setStateSheet(() {
                                    selectedService = newValue;
                                    calculatePrice();
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Vui lòng chọn một dịch vụ'
                                    : null,
                              ),

                            const SizedBox(height: 16),

                            if (estimatedPrice != null)
                              Column(
                                children: [
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Ước tính:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(estimatedPrice)} VNĐ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: const Text('Yêu cầu ngay'),
                                    onPressed: selectedService == null
                                        ? null
                                        : () async {
                                            AppLogger.map(
                                              'Nút "Yêu cầu ngay" được bấm',
                                            );
                                            Navigator.pop(sheetContext);

                                            AppLogger.map(
                                              'Kiểm tra cảnh báo busy_instant trước khi hiển thị dialog vị trí',
                                            );
                                            final shouldContinue =
                                                await _showBusyRepairerWarning(
                                                  repairer,
                                                );

                                            if (shouldContinue) {
                                              AppLogger.map(
                                                'Người dùng đồng ý tiếp tục, hiển thị dialog xác nhận vị trí',
                                              );
                                              _showLocationConfirmationDialog(
                                                repairer,
                                                selectedService!,
                                              );
                                            } else {
                                              AppLogger.map(
                                                'Người dùng hủy, không hiển thị dialog vị trí',
                                              );
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.calendar_today),
                                    label: const Text('Đặt lịch'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: selectedService == null
                                        ? null
                                        : () {
                                            _showDateTimePicker(
                                              sheetContext: sheetContext,
                                              repairer: repairer,
                                              selectedService: selectedService!,
                                            );
                                          },
                                  ),
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
            );
          },
        );
      },
    );
  }

  // Thêm hàm hiển thị Date/Time Picker
  Future<void> _showDateTimePicker({
    required BuildContext sheetContext,
    required UserModel repairer,
    required _ServiceOffering selectedService,
  }) async {
    // Đóng bottom sheet hiện tại trước
    Navigator.pop(sheetContext);

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(
        const Duration(days: 30),
      ), // Cho phép đặt lịch trước 30 ngày
    );

    if (date == null) return; // Người dùng hủy chọn ngày

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (time == null) return; // Người dùng hủy chọn giờ

    final scheduledDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Kiểm tra xem thời gian đã chọn có phải trong quá khứ không
    if (scheduledDateTime.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chọn thời gian trong quá khứ.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    bool isConflict = false;
    for (final job in _repairerSchedule) {
      final jobStart = job.scheduledAt!.toDate();
      // Nếu không có thời gian kết thúc, giả định công việc kéo dài 2 giờ
      final jobEnd =
          job.scheduledEndTime?.toDate() ??
          jobStart.add(const Duration(hours: 2));

      if (scheduledDateTime.isAfter(jobStart) &&
          scheduledDateTime.isBefore(jobEnd)) {
        isConflict = true;
        break;
      }
      // Cũng kiểm tra xem thời gian bắt đầu có trùng không
      if (scheduledDateTime.isAtSameMomentAs(jobStart)) {
        isConflict = true;
        break;
      }
    }

    if (isConflict) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lỗi: Thời gian bạn chọn bị trùng với lịch hẹn khác của thợ.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final scheduledTimestamp = Timestamp.fromDate(scheduledDateTime);

    // Bây giờ, hiển thị dialog xác nhận vị trí với thông tin lịch hẹn
    if (mounted) {
      _showLocationConfirmationDialog(
        repairer,
        selectedService,
        scheduledAt: scheduledTimestamp,
      );
    }
  }

  // Hàm hiển thị dialog xác nhận vị trí
  Future<void> _showLocationConfirmationDialog(
    UserModel repairer,
    _ServiceOffering selectedService, {
    Timestamp? scheduledAt,
  }) async {
    AppLogger.map('_showLocationConfirmationDialog được gọi');
    AppLogger.map(
      'Repairer: ${repairer.name} (Status: ${repairer.status.name})',
    );
    AppLogger.map('Service: ${selectedService.serviceName}');
    AppLogger.map('ScheduledAt: $scheduledAt');
    AppLogger.map('Lưu ý: Cảnh báo busy_instant đã được hiển thị trước đó');

    final customer = _currentUser;
    if (customer == null || customer.defaultAddress == null) {
      AppLogger.map('Customer hoặc defaultAddress null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin khách hàng.')),
      );
      return;
    }

    AppLogger.map('Hiển thị dialog xác nhận vị trí...');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận vị trí'),
          content: const Text('Bạn muốn sử dụng vị trí nào cho yêu cầu này?'),
          actions: [
            TextButton(
              child: const Text('Vị trí đã lưu'),
              onPressed: () {
                AppLogger.map('Người dùng chọn "Vị trí đã lưu"');
                Navigator.pop(dialogContext);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    final locationData = customer.defaultAddress!;
                    if (scheduledAt != null) {
                      AppLogger.map('Tạo scheduled job với vị trí đã lưu');
                      _createScheduledJobWithLocation(
                        customer: customer,
                        repairer: repairer,
                        selectedService: selectedService,
                        locationData: locationData,
                        scheduledAt: scheduledAt,
                      );
                    } else {
                      AppLogger.map('Tạo instant job với vị trí đã lưu');
                      _createJobWithLocation(
                        customer: customer,
                        repairer: repairer,
                        selectedService: selectedService,
                        locationData: locationData,
                      );
                    }
                  }
                });
              },
            ),
            ElevatedButton(
              child: const Text('Chọn vị trí khác'),
              onPressed: () async {
                AppLogger.map('Người dùng chọn "Chọn vị trí khác"');
                Navigator.pop(dialogContext);
                await Future.delayed(const Duration(milliseconds: 100));

                if (!mounted) return;

                AppLogger.map('Điều hướng đến PlacePickerScreen');
                final newLocationResult =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlacePickerScreen(),
                      ),
                    );

                if (newLocationResult != null && mounted) {
                  AppLogger.map('Nhận kết quả từ PlacePickerScreen');
                  // Chuyển đổi LatLng sang GeoPoint
                  final latLng = newLocationResult['coordinates'] as LatLng;
                  final locationData = {
                    'address_line': newLocationResult['address'] as String,
                    'coordinates': GeoPoint(latLng.latitude, latLng.longitude),
                  };

                  if (scheduledAt != null) {
                    AppLogger.map('Tạo scheduled job với vị trí mới');
                    _createScheduledJobWithLocation(
                      customer: customer,
                      repairer: repairer,
                      selectedService: selectedService,
                      locationData: locationData,
                      scheduledAt: scheduledAt,
                    );
                  } else {
                    AppLogger.map('Tạo instant job với vị trí mới');
                    _createJobWithLocation(
                      customer: customer,
                      repairer: repairer,
                      selectedService: selectedService,
                      locationData: locationData,
                    );
                  }
                } else {
                  AppLogger.map('Không nhận được kết quả từ PlacePickerScreen');
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Hàm kiểm tra và hiển thị cảnh báo cho repairer busy
  Future<bool> _showBusyRepairerWarning(UserModel repairer) async {
    AppLogger.map(
      '_showBusyRepairerWarning được gọi cho thợ: ${repairer.name}',
    );
    AppLogger.map('Trạng thái thợ: ${repairer.status.name}');

    if (repairer.status == RepairerStatus.busy_instant) {
      AppLogger.map('Thợ đang busy_instant, hiển thị cảnh báo');
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text('Thợ đang bận'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${repairer.name} đang làm việc với khách hàng khác.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thợ vẫn có thể nhận yêu cầu của bạn, nhưng có thể phải chờ lâu hơn để hoàn thành công việc hiện tại.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bạn có muốn tiếp tục gửi yêu cầu không?',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tiếp tục'),
              ),
            ],
          );
        },
      );
      AppLogger.map('Kết quả dialog: $result');
      return result ?? false;
    }
    AppLogger.map('Thợ không busy, cho phép tiếp tục');
    return true;
  }

  // Hàm tạo job (tách ra để tái sử dụng)
  Future<void> _createJobWithLocation({
    required UserModel customer,
    required UserModel repairer,
    required _ServiceOffering selectedService,
    required Map<String, dynamic> locationData,
  }) async {
    AppLogger.map('_createJobWithLocation được gọi');
    AppLogger.map('Customer: ${customer.name}');
    AppLogger.map(
      'Repairer: ${repairer.name} (Status: ${repairer.status.name})',
    );
    AppLogger.map('Service: ${selectedService.serviceName}');
    AppLogger.map('Lưu ý: Cảnh báo busy_instant đã được hiển thị trước đó');

    try {
      AppLogger.map('Bắt đầu tạo job...');
      final addressLine = locationData['address_line'] as String;
      final location = locationData['coordinates'] as GeoPoint;

      final job = await _jobController.createNewJob(
        customer: customer,
        locksmith: repairer,
        service: selectedService.serviceName,
        location: location,
        addressLine: addressLine,
      );

      if (job != null && mounted) {
        AppLogger.map('Job được tạo thành công, chuyển đến JobDetailsScreen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job.id!),
          ),
        );
      } else if (mounted) {
        AppLogger.map('Không thể tạo job');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo yêu cầu. Vui lòng thử lại.'),
          ),
        );
      }
    } catch (e) {
      AppLogger.map('Lỗi khi tạo job: $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo yêu cầu: $e')));
    }
  }

  // Hàm mới để tạo job đã được lên lịch
  Future<void> _createScheduledJobWithLocation({
    required UserModel customer,
    required UserModel repairer,
    required _ServiceOffering selectedService,
    required Map<String, dynamic> locationData,
    required Timestamp scheduledAt,
  }) async {
    try {
      // Kiểm tra xung đột thời gian trước khi tạo job
      final endTime = scheduledAt.toDate().add(const Duration(hours: 2));
      final conflictResult = await _jobController.checkCustomerTimeConflict(
        repairer.uid,
        scheduledAt.toDate(),
        endTime,
      );

      if (conflictResult.hasConflict) {
        // Hiển thị dialog xung đột thời gian
        _showTimeConflictDialog(conflictResult.conflicts);
        return;
      }

      final addressLine = locationData['address_line'] as String;
      final location = locationData['coordinates'] as GeoPoint;

      final job = await _jobController.createScheduledJob(
        customer: customer,
        locksmith: repairer,
        service: selectedService.serviceName,
        location: location,
        addressLine: addressLine,
        scheduledAt: scheduledAt,
      );

      if (job != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job.id!),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đặt lịch. Vui lòng thử lại.'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đặt lịch: $e')));
    }
  }

  // Dialog hiển thị xung đột thời gian cho customer
  void _showTimeConflictDialog(List<TimeConflict> conflicts) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text('Thời gian không khả dụng'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thời gian bạn chọn đã bị trùng với lịch trình của thợ:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...conflicts
                  .map(
                    (conflict) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            conflict.type == ConflictType.scheduledJob
                                ? Icons.schedule
                                : Icons.work,
                            size: 16,
                            color: conflict.type == ConflictType.scheduledJob
                                ? Colors.blue[600]
                                : Colors.orange[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conflict.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('HH:mm dd/MM').format(conflict.startTime)} - ${DateFormat('HH:mm dd/MM').format(conflict.endTime)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 12),
              const Text(
                'Vui lòng chọn thời gian khác để đặt lịch.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // Hàm helper để lấy vị trí và xử lý quyền
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

  // Widget mới để hiển thị lịch trình của thợ theo timeline
  Widget _buildScheduleList([UserModel? repairer]) {
    final List<Widget> children = [];

    if (repairer?.status == RepairerStatus.busy_instant) {
      children.add(
        ListTile(
          leading: Icon(Icons.work, color: Colors.orange[600]),
          title: Text(
            'Thợ đang làm việc',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.orange[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Thợ đang làm việc với khách hàng khác',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          dense: true,
        ),
      );
    }

    if (_repairerSchedule.isEmpty) {
      // Nếu không bận và không có lịch → hiển thị "thợ đang rảnh"
      if (children.isEmpty) {
        return const ListTile(
          leading: Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(
            'Thợ đang rảnh',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          dense: true,
        );
      }
      // Nếu đang bận nhưng không có lịch sắp tới → vẫn hiển thị một dòng thông tin
      children.add(
        const ListTile(
          leading: Icon(Icons.event_available, color: Colors.blue),
          title: Text('Chưa có lịch hẹn sắp tới'),
          dense: true,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    children.addAll([
      const Text(
        'Lịch hẹn sắp tới của thợ:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _buildTimelineView(),
      const Divider(height: 32),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // Method helper để hiển thị timeline view
  Widget _buildTimelineView() {
    return FutureBuilder<List<WorkSessionModel>>(
      future: _firestoreService.getAllWorkSessionsForRepairer(
        _repairerSchedule.first.locksmithId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final workSessions = snapshot.data!;

          // Kết hợp lịch hẹn và phiên làm việc
          List<TimelineItem> timelineItems = [];

          // Thêm lịch hẹn
          for (var job in _repairerSchedule) {
            timelineItems.add(
              TimelineItem(
                type: TimelineItemType.scheduled,
                title: 'Lịch hẹn',
                subtitle: job.service,
                startTime: job.scheduledAt!.toDate(),
                endTime:
                    job.scheduledEndTime?.toDate() ??
                    job.scheduledAt!.toDate().add(const Duration(hours: 2)),
                description: 'Dịch vụ: ${job.service}',
              ),
            );
          }

          // Thêm phiên làm việc
          for (var session in workSessions) {
            timelineItems.add(
              TimelineItem(
                type: TimelineItemType.workSession,
                title: 'Phiên #${session.sessionNumber}',
                subtitle: session.description,
                startTime: session.startTime.toDate(),
                endTime:
                    session.estimatedEndTime?.toDate() ??
                    session.startTime.toDate().add(const Duration(hours: 2)),
                description: session.description,
              ),
            );
          }

          // Sắp xếp theo thời gian bắt đầu
          timelineItems.sort((a, b) => a.startTime.compareTo(b.startTime));

          return Container(
            height: 300,
            child: ListView.builder(
              itemCount: timelineItems.length,
              itemBuilder: (context, index) {
                final item = timelineItems[index];
                final isLast = index == timelineItems.length - 1;

                return _buildTimelineItem(item, isLast);
              },
            ),
          );
        }

        // Nếu không có phiên làm việc, chỉ hiển thị lịch hẹn
        List<TimelineItem> scheduledItems = _repairerSchedule.map((job) {
          return TimelineItem(
            type: TimelineItemType.scheduled,
            title: 'Lịch hẹn',
            subtitle: job.service,
            startTime: job.scheduledAt!.toDate(),
            endTime:
                job.scheduledEndTime?.toDate() ??
                job.scheduledAt!.toDate().add(const Duration(hours: 2)),
            description: 'Dịch vụ: ${job.service}',
          );
        }).toList();

        scheduledItems.sort((a, b) => a.startTime.compareTo(b.startTime));

        return Container(
          height: 200,
          child: ListView.builder(
            itemCount: scheduledItems.length,
            itemBuilder: (context, index) {
              final item = scheduledItems[index];
              final isLast = index == scheduledItems.length - 1;

              return _buildTimelineItem(item, isLast);
            },
          ),
        );
      },
    );
  }

  // Widget để hiển thị một item trong timeline
  Widget _buildTimelineItem(TimelineItem item, bool isLast) {
    final startTime = DateFormat('HH:mm dd/MM').format(item.startTime);
    final endTime = DateFormat('HH:mm dd/MM').format(item.endTime);
    final duration = item.endTime.difference(item.startTime);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line và dot
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.type == TimelineItemType.scheduled
                    ? Colors.blue[600]
                    : Colors.orange[600],
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.type == TimelineItemType.scheduled
                            ? Icons.schedule
                            : Icons.work,
                        color: item.type == TimelineItemType.scheduled
                            ? Colors.blue[600]
                            : Colors.orange[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.type == TimelineItemType.scheduled
                                    ? Colors.blue[700]
                                    : Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                            if (item.subtitle.isNotEmpty)
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$startTime - $endTime',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${duration.inHours}h ${duration.inMinutes % 60}p',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Enum để phân loại item trong timeline
enum TimelineItemType { scheduled, workSession }

// Class để đại diện cho một item trong timeline
class TimelineItem {
  final TimelineItemType type;
  final String title;
  final String subtitle;
  final DateTime startTime;
  final DateTime endTime;
  final String description;

  TimelineItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.startTime,
    required this.endTime,
    required this.description,
  });
}
