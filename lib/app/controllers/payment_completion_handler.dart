import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';

class PaymentCompletionHandler {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> onPaymentCompleted(String jobId, String repairerId) async {
    try {
      await _firestoreService.updateJob(jobId, {
        'status': 'completed',
        'paymentStatus': 'paid',
        'actualEndTime': DateTime.now(),
      });

      await _firestoreService.updateRepairerStatus(
        repairerId,
        RepairerStatus.available,
      );

      AppLogger.job(
        'Job $jobId completed, repairer $repairerId set to available',
      );
    } catch (e) {
      AppLogger.job('Lỗi khi xử lý completion: $e');
      rethrow;
    }
  }

  Future<void> onJobCancelled(String jobId, String repairerId) async {
    try {
      await _firestoreService.updateJob(jobId, {
        'status': 'cancelled',
        'actualEndTime': DateTime.now(),
      });

      await _firestoreService.updateRepairerStatus(
        repairerId,
        RepairerStatus.available,
      );

      AppLogger.job(
        'Job $jobId cancelled, repairer $repairerId set to available',
      );
    } catch (e) {
      AppLogger.job('Lỗi khi cancel job: $e');
      rethrow;
    }
  }

  Future<void> syncCompletedJobs(String repairerId) async {
    try {
      final completedJobs = await _firestoreService.getCompletedJobsNotSynced(
        repairerId,
      );

      if (completedJobs.isNotEmpty) {
        await _firestoreService.updateRepairerStatus(
          repairerId,
          RepairerStatus.available,
        );
      }
    } catch (e) {
      AppLogger.job('Lỗi sync completed jobs: $e');
    }
  }
}
