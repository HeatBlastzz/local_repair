import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';

class StatusManager {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> onJobAccepted(JobModel job) async {
    try {
      await _firestoreService.updateJob(job.id!, {
        'actualStartTime': DateTime.now(),
        'status': 'accepted',
      });

      await _firestoreService.updateUserStatus(
        job.locksmithId,
        RepairerStatus.busy_instant,
      );
    } catch (e) {
      AppLogger.job('Lỗi khi accept job: $e');
      rethrow;
    }
  }

  Future<void> toggleOnlineStatus(
    String repairerId,
    RepairerStatus currentStatus,
  ) async {
    RepairerStatus newStatus;

    if (currentStatus == RepairerStatus.offline) {
      newStatus = RepairerStatus.available;
    } else if (currentStatus == RepairerStatus.available) {
      newStatus = RepairerStatus.offline;
    } else {
      return;
    }

    await _firestoreService.updateUserStatus(repairerId, newStatus);
  }

  Future<void> onInstantJobAccepted(JobModel job) async {
    await _firestoreService.updateUserStatus(
      job.locksmithId,
      RepairerStatus.busy_instant,
    );
  }

  Future<void> onJobCompleted(String repairerId) async {
    await _firestoreService.updateUserStatus(
      repairerId,
      RepairerStatus.available,
    );
  }

  Future<void> onJobRejected(String repairerId) async {}

  Future<void> pauseWorkSession(String repairerId) async {
    await _firestoreService.updateUserStatus(
      repairerId,
      RepairerStatus.available,
    );
  }

  Future<void> resumeWorkSession(String repairerId) async {
    await _firestoreService.updateUserStatus(
      repairerId,
      RepairerStatus.busy_instant,
    );
  }

  Future<void> completeWorkSession(
    String jobId,
    String sessionId,
    String repairerId,
  ) async {
    try {
      await _firestoreService.updateWorkSessionStatus(
        jobId,
        sessionId,
        'completed',
      );

      final activeSessions = await _firestoreService
          .getActiveWorkSessionsForJob(jobId);

      if (activeSessions.isEmpty) {
        await _firestoreService.updateUserStatus(
          repairerId,
          RepairerStatus.available,
        );
      }
    } catch (e) {
      AppLogger.firestore('Lỗi khi hoàn thành phiên làm việc: $e');
      rethrow;
    }
  }

  Future<void> setRepairerAvailable(String repairerId) async {
    try {
      await _firestoreService.updateRepairerStatus(
        repairerId,
        RepairerStatus.available,
      );
    } catch (e) {
      AppLogger.firestore('Lỗi khi set available: $e');
      rethrow;
    }
  }

  bool canAcceptNewJob(RepairerStatus status) {
    return status == RepairerStatus.available;
  }

  Future<void> setScheduledJobEndTime(
    String jobId,
    DateTime endTime,
    String repairerId,
  ) async {
    try {
      await _firestoreService.updateJob(jobId, {'scheduledEndTime': endTime});
      await _firestoreService.updateUserStatus(
        repairerId,
        RepairerStatus.busy_instant,
      );
    } catch (e) {
      AppLogger.job('Lỗi set scheduled end time: $e');
      rethrow;
    }
  }
}
