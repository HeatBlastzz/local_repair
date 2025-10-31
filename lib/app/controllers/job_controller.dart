import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/message_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/models/work_session_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_test/utils/logger.dart';
import 'package:flutter_application_test/data/models/user_model.dart'
    show RepairerStatus;

enum StatisticsTimeFilter { week, month, all }

class JobController {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getRepairerStatistics(
    StatisticsTimeFilter filter, {
    DateTime? targetDate,
  }) async {
    final repairerId = _auth.currentUser?.uid;
    if (repairerId == null) {
      throw Exception("User not logged in");
    }

    DateTime now = targetDate ?? DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (filter) {
      case StatisticsTimeFilter.week:
        // Monday of the week
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        // Sunday of the week
        endDate = startDate.add(
          const Duration(days: 6, hours: 23, minutes: 59),
        );
        break;
      case StatisticsTimeFilter.month:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59);
        break;
      case StatisticsTimeFilter.all:
        break;
    }

    final QuerySnapshot snapshot = await _firestoreService
        .getCompletedJobsForRepairer(
          repairerId,
          startDate: startDate,
          endDate: endDate,
        );

    if (snapshot.docs.isEmpty && filter != StatisticsTimeFilter.all) {}

    double totalRevenue = 0;
    List<JobModel> jobs = snapshot.docs.map((doc) {
      return JobModel.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );
    }).toList();

    for (var job in jobs) {
      totalRevenue += job.finalPrice ?? 0;
    }

    Map<String, double> dailyRevenue = {};

    // 1. Initialize the date range with 0 revenue
    if (filter == StatisticsTimeFilter.month) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i++) {
        final dayString = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, i));
        dailyRevenue[dayString] = 0.0;
      }
    } else if (filter == StatisticsTimeFilter.week) {
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final dayString = DateFormat(
          'yyyy-MM-dd',
        ).format(startOfWeek.add(Duration(days: i)));
        dailyRevenue[dayString] = 0.0;
      }
    }

    // 2. Populate the map with actual revenue from jobs
    for (var job in jobs) {
      if (job.paymentTimestamp != null) {
        String dayKey = DateFormat(
          'yyyy-MM-dd',
        ).format(job.paymentTimestamp!.toDate());
        // Use update to add revenue to existing days
        if (dailyRevenue.containsKey(dayKey)) {
          dailyRevenue.update(dayKey, (value) => value + (job.finalPrice ?? 0));
        } else if (filter == StatisticsTimeFilter.all) {
          // For 'all' filter, add entries as they come
          dailyRevenue.update(
            dayKey,
            (value) => value + (job.finalPrice ?? 0),
            ifAbsent: () => job.finalPrice ?? 0,
          );
        }
      }
    }

    // 3. Convert map to list and sort
    final chartData = dailyRevenue.entries
        .map((e) => {'day': e.key, 'revenue': e.value})
        .toList();
    chartData.sort(
      (a, b) => (a['day'] as String).compareTo(b['day'] as String),
    );

    return {
      'totalRevenue': totalRevenue,
      'completedJobs': jobs.length,
      'chartData': chartData,
      'completedJobsList': jobs,
    };
  }

  Future<void> _sendSystemWelcomeMessage(
    String jobId,
    String text,
    String customerId,
  ) async {
    final welcomeMessage = MessageModel(
      senderId: 'system',
      receiverId: customerId,
      text: text,
      timestamp: Timestamp.now(),
    );
    await _firestoreService.addMessage(jobId, welcomeMessage);
    await _firestoreService.updateJob(jobId, {
      'lastMessage': text,
      'lastMessageTimestamp': welcomeMessage.timestamp,
    });
  }

  Future<JobModel?> createNewJob({
    required UserModel customer,
    required UserModel locksmith,
    required String service,
    required GeoPoint location,
    required String addressLine,
  }) async {
    try {
      final newJob = JobModel(
        customerId: customer.uid,
        locksmithId: locksmith.uid,
        customerName: customer.name ?? 'Khách hàng',
        locksmithName: locksmith.name ?? 'Thợ sửa khóa',
        status: 'pending',
        createdAt: Timestamp.now(),
        location: location,
        addressLine: addressLine,
        service: service,
        jobType: JobType.instant,
      );

      final createdJob = await _firestoreService.createJob(newJob);
      final welcomeText =
          'Yêu cầu cho dịch vụ "${newJob.service}" đã được tạo. Cả hai có thể nhắn tin với nhau.';
      await _sendSystemWelcomeMessage(
        createdJob.id!,
        welcomeText,
        customer.uid,
      );

      return createdJob;
    } catch (e) {
      AppLogger.job('JobController gặp lỗi: $e');
      return null;
    }
  }

  Future<void> acceptJob(JobModel job) async {
    if (job.jobType == JobType.scheduled) {
      await _firestoreService.updateJob(job.id!, {'status': 'confirmed'});
    } else {
      await _firestoreService.updateJob(job.id!, {'status': 'accepted'});
    }
  }

  Future<void> startInstantJob(JobModel job) async {
    try {
      await _firestoreService.updateJob(job.id!, {'status': 'in_progress'});
      await _firestoreService.updateUserStatus(
        job.locksmithId,
        RepairerStatus.busy_instant,
      );

      AppLogger.job(
        'Repairer ${job.locksmithId} đã bắt đầu instant job ${job.id}',
      );
    } catch (e) {
      AppLogger.job('Lỗi khi bắt đầu instant job: $e');
      rethrow;
    }
  }

  Future<void> rejectJob(JobModel job) async {
    await _firestoreService.updateJob(job.id!, {'status': 'rejected'});
  }

  Future<void> completeJobAndRequestPayment(
    String jobId,
    double finalPrice,
  ) async {
    await _firestoreService.updateJob(jobId, {
      'status': 'payment_pending',
      'finalPrice': finalPrice,
      'paymentStatus': 'pending',
    });
  }

  Future<JobModel?> createScheduledJob({
    required UserModel customer,
    required UserModel locksmith,
    required Timestamp scheduledAt,
    required String service,
    required GeoPoint location,
    required String addressLine,
  }) async {
    try {
      final newScheduledJob = JobModel(
        customerId: customer.uid,
        locksmithId: locksmith.uid,
        customerName: customer.name ?? 'Khách hàng',
        locksmithName: locksmith.name ?? 'Thợ sửa khóa',
        status: 'scheduled',
        createdAt: Timestamp.now(),
        scheduledAt: scheduledAt,
        location: location,
        addressLine: addressLine,
        service: service,
        jobType: JobType.scheduled,
      );

      final createdJob = await _firestoreService.createJob(newScheduledJob);
      final formattedTime = DateFormat(
        'HH:mm dd/MM/yyyy',
      ).format(scheduledAt.toDate());
      final welcomeText =
          'Lịch hẹn cho dịch vụ "${newScheduledJob.service}" đã được đặt vào lúc $formattedTime.';
      await _sendSystemWelcomeMessage(
        createdJob.id!,
        welcomeText,
        customer.uid,
      );

      return createdJob;
    } catch (e) {
      AppLogger.job('JobController gặp lỗi khi tạo lịch hẹn: $e');
      return null;
    }
  }

  Future<void> cancelScheduledJob(JobModel job) async {
    await _firestoreService.updateJob(job.id!, {'status': 'rejected'});
  }

  Future<void> confirmScheduledJobWithEndTime(
    String jobId,
    DateTime endTime,
  ) async {
    await _firestoreService.updateJob(jobId, {
      'status': 'confirmed',
      'scheduledEndTime': Timestamp.fromDate(endTime),
    });
  }

  Future<void> confirmPayment(String jobId, String paymentMethod) async {
    await _firestoreService.updateJob(jobId, {
      'status': 'completed',
      'paymentStatus': 'paid',
      'paymentMethod': paymentMethod,
      'paymentTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> createNewWorkSession({
    required String jobId,
    required int sessionNumber,
    required String description,
    required DateTime startTime,
    DateTime? estimatedEndTime,
  }) async {
    try {
      final job = await _firestoreService.getJob(jobId);
      if (job == null) {
        return 'Không tìm thấy thông tin job';
      }

      final conflictResult = await _firestoreService.checkTimeConflict(
        job.locksmithId,
        startTime,
        estimatedEndTime ?? startTime.add(const Duration(hours: 2)),
        excludeJobId: jobId,
      );

      if (conflictResult.hasConflict) {
        final conflictDetails = conflictResult.conflicts
            .map(
              (c) =>
                  '${c.title}: ${DateFormat('HH:mm dd/MM').format(c.startTime)} - ${DateFormat('HH:mm dd/MM').format(c.endTime)}',
            )
            .join('\n');

        return 'Xung đột thời gian:\n$conflictDetails';
      }

      final newSession = WorkSessionModel(
        sessionNumber: sessionNumber,
        description: description,
        startTime: Timestamp.fromDate(startTime),
        status: 'scheduled',
        estimatedEndTime: estimatedEndTime != null
            ? Timestamp.fromDate(estimatedEndTime)
            : null,
      );

      await _firestoreService.createWorkSession(jobId, newSession);

      await _sendWorkSessionNotification(jobId, newSession, job);

      return null;
    } catch (e) {
      AppLogger.job("Lỗi khi tạo phiên làm việc mới: $e");
      return e.toString();
    }
  }

  Future<void> _sendWorkSessionNotification(
    String jobId,
    WorkSessionModel session,
    JobModel job,
  ) async {
    try {
      final startTimeFormatted = DateFormat(
        'HH:mm dd/MM/yyyy',
      ).format(session.startTime.toDate());
      final endTimeFormatted = session.estimatedEndTime != null
          ? DateFormat(
              'HH:mm dd/MM/yyyy',
            ).format(session.estimatedEndTime!.toDate())
          : 'Chưa xác định';

      final notificationText =
          '''🔧 **Phiên làm việc mới được tạo**

📋 **Thông tin phiên làm việc:**
• Số phiên: #${session.sessionNumber}
• Mô tả: ${session.description}
• Thời gian bắt đầu: $startTimeFormatted
• Thời gian kết thúc dự kiến: $endTimeFormatted

💬 Bạn có thể nhắn tin với thợ để trao đổi thêm chi tiết.''';

      final notificationMessage = MessageModel(
        senderId: 'system',
        receiverId: job.customerId,
        text: notificationText,
        timestamp: Timestamp.now(),
      );

      await _firestoreService.addMessage(jobId, notificationMessage);
      await _firestoreService.updateJob(jobId, {
        'lastMessage': 'Phiên làm việc mới được tạo',
        'lastMessageTimestamp': notificationMessage.timestamp,
      });
    } catch (e) {
      AppLogger.firestore('Lỗi khi gửi thông báo phiên làm việc: $e');
    }
  }

  Future<TimeConflictResult> checkCustomerTimeConflict(
    String repairerId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    return await _firestoreService.checkCustomerTimeConflict(
      repairerId,
      startTime,
      endTime,
    );
  }

  Future<TimeConflictResult> checkRepairerTimeConflict(
    String repairerId,
    DateTime startTime,
    DateTime endTime, {
    String? excludeJobId,
  }) async {
    return await _firestoreService.checkTimeConflict(
      repairerId,
      startTime,
      endTime,
      excludeJobId: excludeJobId,
    );
  }
}
