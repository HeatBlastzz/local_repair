import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String? id;
  final String jobId;
  final String locksmithId;
  final String customerId;
  final int ratingValue;
  final String? comment;
  final Timestamp createdAt;

  RatingModel({
    this.id,
    required this.jobId,
    required this.locksmithId,
    required this.customerId,
    required this.ratingValue,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'locksmithId': locksmithId,
      'customerId': customerId,
      'ratingValue': ratingValue,
      'comment': comment,
      'createdAt': createdAt,
    };
  }
}
