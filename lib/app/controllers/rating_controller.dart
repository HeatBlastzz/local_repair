import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/rating_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';

class RatingController {
  final FirestoreService _firestoreService = FirestoreService();

  Future<bool> handleSubmitRating({
    required JobModel job,
    required int ratingValue,
    required String comment,
  }) async {
    try {
      final newRating = RatingModel(
        jobId: job.id!,
        locksmithId: job.locksmithId,
        customerId: job.customerId,
        ratingValue: ratingValue,
        comment: comment,
        createdAt: Timestamp.now(),
      );
      await _firestoreService.submitRatingAndUpdateProfile(newRating);
      return true;
    } catch (e) {
      AppLogger.firestore('Lỗi khi gửi đánh giá: $e');
      return false;
    }
  }
}
