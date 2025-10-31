import 'package:cloud_firestore/cloud_firestore.dart';

class WorkSessionModel {
  final String? id;
  final int sessionNumber;
  final String status;
  final String description;
  final Timestamp startTime;
  final Timestamp? endTime;
  final Timestamp? estimatedEndTime;

  const WorkSessionModel({
    this.id,
    required this.sessionNumber,
    required this.status,
    required this.description,
    required this.startTime,
    this.endTime,
    this.estimatedEndTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionNumber': sessionNumber,
      'status': status,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'estimatedEndTime': estimatedEndTime,
    };
  }

  factory WorkSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    Map<String, dynamic> data = doc.data()!;
    return WorkSessionModel(
      id: doc.id,
      sessionNumber: data['sessionNumber'] ?? 1,
      status: data['status'] ?? 'scheduled',
      description: data['description'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'],
      estimatedEndTime: data['estimatedEndTime'],
    );
  }
}
