import 'package:cloud_firestore/cloud_firestore.dart';

enum RepairerStatus { offline, available, busy_instant }

class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final Timestamp? dateOfBirth;
  final String? photoUrl;
  final String role;
  final List<String>? majors;
  final Timestamp createdAt;
  final Map<String, dynamic>? defaultAddress;
  final double averageRating;
  final int ratingCount;
  final Map<String, dynamic> services;
  final RepairerStatus status;

  const UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.photoUrl,
    required this.role,
    this.majors,
    required this.createdAt,
    this.defaultAddress,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.services = const {},
    this.status = RepairerStatus.offline,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth,
      'photoUrl': photoUrl,
      'role': role,
      'majors': majors,
      'createdAt': createdAt,
      'defaultAddress': defaultAddress,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'services': services,
      'status': status.name,
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return UserModel(
      uid: doc.id,
      name: data['name'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      dateOfBirth: data['dateOfBirth'],
      photoUrl: data['photoUrl'],
      role: data['role'] ?? 'customer',
      majors: data['majors'] != null ? List<String>.from(data['majors']) : null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      defaultAddress: data['defaultAddress'],
      services: Map<String, dynamic>.from(data['services'] ?? {}),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      status: RepairerStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RepairerStatus.offline,
      ),
    );
  }
}
