import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  final String id;
  final String customerId;
  final String locksmithId;
  final String locksmithName;
  final String locksmithPhone;
  final String locksmithAddress;

  Contact({
    required this.id,
    required this.customerId,
    required this.locksmithId,
    required this.locksmithName,
    required this.locksmithPhone,
    required this.locksmithAddress,
  });

  factory Contact.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      locksmithId: data['locksmithId'] ?? '',
      locksmithName: data['locksmithName'] ?? '',
      locksmithPhone: data['locksmithPhone'] ?? '',
      locksmithAddress: data['locksmithAddress'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'locksmithId': locksmithId,
      'locksmithName': locksmithName,
      'locksmithPhone': locksmithPhone,
      'locksmithAddress': locksmithAddress,
    };
  }
}