import 'package:cloud_firestore/cloud_firestore.dart';

class RepairerContactModel {
  final String id;
  final String repairerId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  RepairerContactModel({
    required this.id,
    required this.repairerId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  factory RepairerContactModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RepairerContactModel(
      id: doc.id,
      repairerId: data['repairerId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'repairerId': repairerId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
    };
  }
}
