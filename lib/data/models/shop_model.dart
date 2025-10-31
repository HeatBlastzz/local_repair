import 'package:cloud_firestore/cloud_firestore.dart';

class ShopModel {
  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final String? phone;
  final String? openingHours;

  ShopModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.phone,
    this.openingHours,
  });

  factory ShopModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return ShopModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      location: data['location'] as GeoPoint,
      phone: data['phone'],
      openingHours: data['openingHours'],
    );
  }
}
