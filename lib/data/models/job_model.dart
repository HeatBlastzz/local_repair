import 'package:cloud_firestore/cloud_firestore.dart';

enum JobType { instant, scheduled }

class JobModel {
  final String? id;
  final String customerId;
  final String customerName;
  final String? customerAvatarUrl;
  final String locksmithId;
  final String locksmithName;
  final String service;
  final GeoPoint location;
  final String addressLine;
  final String status;
  final Timestamp createdAt;
  final int sessionCount;
  final double? finalPrice;
  final String paymentStatus;
  final String? paymentMethod;
  final Timestamp? paymentTimestamp;
  final String? lastMessage;
  final Timestamp? lastMessageTimestamp;
  final List<String> deletedFor;
  final Timestamp? scheduledAt;
  final Timestamp? scheduledEndTime;
  final Timestamp? actualStartTime;
  final Timestamp? actualEndTime;
  final JobType jobType;
  final bool isSynced;
  final Timestamp? syncedAt;

  const JobModel({
    this.id,
    required this.customerId,
    required this.customerName,
    this.customerAvatarUrl,
    required this.locksmithId,
    required this.locksmithName,
    required this.service,
    required this.location,
    required this.addressLine,
    required this.status,
    required this.createdAt,
    this.sessionCount = 0,
    this.finalPrice,
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    this.paymentTimestamp,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.deletedFor = const [],
    this.scheduledAt,
    this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.jobType = JobType.instant,
    this.isSynced = false,
    this.syncedAt,
  });

  JobModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerAvatarUrl,
    String? locksmithId,
    String? locksmithName,
    String? service,
    GeoPoint? location,
    String? addressLine,
    String? status,
    Timestamp? createdAt,
    int? sessionCount,
    double? finalPrice,
    String? paymentStatus,
    String? paymentMethod,
    Timestamp? paymentTimestamp,
    String? lastMessage,
    Timestamp? lastMessageTimestamp,
    List<String>? deletedFor,
    Timestamp? scheduledAt,
    Timestamp? scheduledEndTime,
    Timestamp? actualStartTime,
    Timestamp? actualEndTime,
    JobType? jobType,
    bool? isSynced,
    Timestamp? syncedAt,
  }) {
    return JobModel(
      id: id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAvatarUrl: customerAvatarUrl ?? this.customerAvatarUrl,
      locksmithId: locksmithId ?? this.locksmithId,
      locksmithName: locksmithName ?? this.locksmithName,
      service: service ?? this.service,
      location: location ?? this.location,
      addressLine: addressLine ?? this.addressLine,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      sessionCount: sessionCount ?? this.sessionCount,
      finalPrice: finalPrice ?? this.finalPrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTimestamp: paymentTimestamp ?? this.paymentTimestamp,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      deletedFor: deletedFor ?? this.deletedFor,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      jobType: jobType ?? this.jobType,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerAvatarUrl': customerAvatarUrl,
      'locksmithId': locksmithId,
      'locksmithName': locksmithName,
      'service': service,
      'location': location,
      'addressLine': addressLine,
      'status': status,
      'createdAt': createdAt,
      'sessionCount': sessionCount,
      'finalPrice': finalPrice,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentTimestamp': paymentTimestamp,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
      'deletedFor': deletedFor,
      'scheduledAt': scheduledAt,
      'scheduledEndTime': scheduledEndTime,
      'actualStartTime': actualStartTime,
      'actualEndTime': actualEndTime,
      'jobType': jobType.name,
      'isSynced': isSynced,
      'syncedAt': syncedAt,
    };
  }

  factory JobModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;

    GeoPoint location;
    if (data['location'] is GeoPoint) {
      location = data['location'];
    } else if (data['location'] is Map) {
      final map = data['location'] as Map<String, dynamic>;
      final lat = (map['latitude'] ?? 0.0).toDouble();
      final lng = (map['longitude'] ?? 0.0).toDouble();
      location = GeoPoint(lat, lng);
    } else {
      location = const GeoPoint(0, 0);
    }

    return JobModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerAvatarUrl: data['customerAvatarUrl'],
      locksmithId: data['locksmithId'] ?? '',
      locksmithName: data['locksmithName'] ?? '',
      service: data['service'] ?? '',
      location: location,
      addressLine: data['addressLine'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      sessionCount: data['sessionCount'] ?? 0,
      finalPrice: (data['finalPrice'] ?? 0.0).toDouble(),
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      paymentMethod: data['paymentMethod'],
      paymentTimestamp: data['paymentTimestamp'],
      lastMessage: data['lastMessage'],
      lastMessageTimestamp: data['lastMessageTimestamp'],
      deletedFor: List<String>.from(data['deletedFor'] ?? []),
      scheduledAt: data['scheduledAt'],
      scheduledEndTime: data['scheduledEndTime'],
      actualStartTime: data['actualStartTime'],
      actualEndTime: data['actualEndTime'],
      jobType: JobType.values.firstWhere(
        (e) => e.name == data['jobType'],
        orElse: () => JobType.instant,
      ),
      isSynced: data['isSynced'] ?? false,
      syncedAt: data['syncedAt'],
    );
  }
}
