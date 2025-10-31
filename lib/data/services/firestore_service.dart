import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/rating_model.dart';
import 'package:flutter_application_test/data/models/shop_model.dart';
import 'package:flutter_application_test/data/models/message_model.dart';
import 'package:flutter_application_test/data/models/work_session_model.dart';
import 'package:flutter_application_test/data/models/contact_model.dart';
import 'package:flutter_application_test/data/models/repairer_contact_model.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_test/utils/logger.dart';

// Enum để phân loại loại xung đột
enum ConflictType { scheduledJob, workSession }

// Class để đại diện cho một xung đột thời gian
class TimeConflict {
  final ConflictType type;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? jobId;
  final String? sessionId;

  TimeConflict({
    required this.type,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.jobId,
    this.sessionId,
  });
}

// Class để đại diện cho kết quả kiểm tra xung đột
class TimeConflictResult {
  final bool hasConflict;
  final List<TimeConflict> conflicts;

  TimeConflictResult({required this.hasConflict, required this.conflicts});
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _jobsCollection = FirebaseFirestore.instance
      .collection('jobs');
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference _ratingsCollection = FirebaseFirestore.instance
      .collection('ratings');
  final CollectionReference _contactsCollection = FirebaseFirestore.instance
      .collection('contacts');
  final CollectionReference _repairerContactsCollection = FirebaseFirestore
      .instance
      .collection('repairer_contacts');

  Future<void> createUserRecord(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      AppLogger.firestore('Lỗi Firestore: ${e.toString()}');
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final docSnapshot = await _usersCollection.doc(uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(
          docSnapshot as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
    } catch (e) {
      AppLogger.firestore('Lỗi lấy thông tin người dùng: $e');
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromFirestore(
          snapshot as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    });
  }

  Future<List<UserModel>> getAllRepairers() async {
    try {
      final querySnapshot = await _usersCollection
          .where('role', isEqualTo: 'repairer')
          .get();
      return querySnapshot.docs
          .map(
            (doc) => UserModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.firestore('Lỗi khi lấy danh sách thợ khóa: $e');
      return [];
    }
  }

  // --- Các hàm cho Job ---
  Future<JobModel> createJob(JobModel job) async {
    try {
      final docRef = await _jobsCollection.add(job.toMap());
      return job.copyWith(id: docRef.id);
    } catch (e) {
      AppLogger.job('Lỗi khi tạo công việc mới: $e');
      rethrow;
    }
  }

  Stream<JobModel?> getJobStream(String jobId) {
    return _jobsCollection.doc(jobId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return JobModel.fromFirestore(
          snapshot as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    });
  }

  Future<void> updateUserLocation(String uid, GeoPoint location) async {
    try {
      await _usersCollection.doc(uid).set({
        'defaultAddress': {'coordinates': location},
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.firestore("Lỗi cập nhật vị trí người dùng: $e");
    }
  }

  Stream<List<JobModel>> getJobsForLocksmith(String locksmithId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: locksmithId)
        .where('status', whereIn: ['pending', 'scheduled'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Future<void> updateJob(
    String jobId,
    Map<String, dynamic> dataToUpdate,
  ) async {
    try {
      await _jobsCollection.doc(jobId).update(dataToUpdate);
    } catch (e) {
      AppLogger.job('Lỗi khi cập nhật công việc: $e');
      throw e;
    }
  }

  Stream<List<JobModel>> getAcceptedJobsForLocksmith(String locksmithId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: locksmithId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Stream<List<JobModel>> getInProgressJobsForLocksmith(String locksmithId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: locksmithId)
        .where('status', isEqualTo: 'in_progress')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Stream<List<JobModel>> getAllJobsForCustomer(String customerId) {
    return _jobsCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Future<void> submitRatingAndUpdateProfile(RatingModel rating) async {
    final locksmithRef = _usersCollection.doc(rating.locksmithId);
    final jobRef = _jobsCollection.doc(rating.jobId);
    final newRatingRef = _ratingsCollection.doc();

    return _firestore.runTransaction((transaction) async {
      final locksmithSnapshot = await transaction.get(locksmithRef);
      if (!locksmithSnapshot.exists) {
        throw Exception("Thợ khóa không tồn tại!");
      }
      final locksmithData = locksmithSnapshot.data() as Map<String, dynamic>;
      final oldRatingCount = locksmithData['ratingCount'] ?? 0;
      final oldAverageRating = (locksmithData['averageRating'] ?? 0.0)
          .toDouble();
      final newRatingCount = oldRatingCount + 1;
      final newAverageRating =
          ((oldAverageRating * oldRatingCount) + rating.ratingValue) /
          newRatingCount;

      transaction.set(newRatingRef, rating.toMap());
      transaction.update(jobRef, {'status': 'rated'});
      transaction.update(locksmithRef, {
        'ratingCount': newRatingCount,
        'averageRating': newAverageRating,
      });
    });
  }

  Stream<List<JobModel>> getJobHistoryForLocksmith(String locksmithId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: locksmithId)
        .where(
          'status',
          whereIn: ['completed', 'rejected', 'cancelled_by_locksmith'],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Stream<List<JobModel>> getScheduledJobsForLocksmith(String locksmithId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: locksmithId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Stream<List<JobModel>> getScheduledJobsForCustomer(String customerId) {
    return _jobsCollection
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: ['scheduled', 'confirmed'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Stream<List<JobModel>> getPaymentPendingJobsForCustomer(String customerId) {
    return _jobsCollection
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: 'payment_pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  Future<void> updateLocksmithServices(
    String locksmithId,
    Map<String, dynamic> services,
  ) async {
    try {
      await _usersCollection.doc(locksmithId).update({'services': services});
    } catch (e) {
      AppLogger.firestore('Lỗi khi cập nhật dịch vụ: $e');
      throw e;
    }
  }

  Future<List<ShopModel>> getShops() async {
    try {
      final snapshot = await _firestore.collection('shops').get();
      return snapshot.docs
          .map(
            (doc) => ShopModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.firestore('Lỗi khi lấy danh sách cửa hàng: $e');
      return [];
    }
  }

  Future<void> sendMessage(String jobId, MessageModel message) async {
    try {
      final jobRef = _jobsCollection.doc(jobId);
      await jobRef.collection('messages').add(message.toMap());
      await jobRef.update({
        'lastMessage': message.text,
        'lastMessageTimestamp': message.timestamp,
      });
    } catch (e) {
      AppLogger.firestore('Lỗi khi gửi tin nhắn: $e');
      throw e;
    }
  }

  Stream<QuerySnapshot> getChatMessagesStream(String jobId) {
    return _jobsCollection
        .doc(jobId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      AppLogger.firestore('Lỗi khi cập nhật thông tin người dùng: $e');
      throw Exception('Không thể cập nhật thông tin. Vui lòng thử lại.');
    }
  }

  Future<void> hideChatForUser(String jobId, String userId) async {
    try {
      await _jobsCollection.doc(jobId).update({
        'deletedFor': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      AppLogger.firestore('Error hiding chat for user: $e');
      rethrow;
    }
  }

  Stream<List<JobModel>> getChatList(String userId, String userRole) {
    String fieldToQuery = userRole == 'customer' ? 'customerId' : 'locksmithId';
    return _jobsCollection
        .where(fieldToQuery, isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
          return jobs.where((job) => !job.deletedFor.contains(userId)).toList();
        });
  }

  Future<void> createWorkSession(String jobId, WorkSessionModel session) async {
    await _jobsCollection
        .doc(jobId)
        .collection('work_sessions')
        .add(session.toMap());
    await _jobsCollection.doc(jobId).update({
      'sessionCount': FieldValue.increment(1),
    });
  }

  Stream<List<WorkSessionModel>> getWorkSessionsStream(String jobId) {
    return _jobsCollection
        .doc(jobId)
        .collection('work_sessions')
        .orderBy('sessionNumber', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => WorkSessionModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // --- Tin nhắn ---
  Future<void> addMessage(String jobId, MessageModel message) async {
    await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('messages')
        .add(message.toMap());
  }

  Stream<List<MessageModel>> getMessagesStream(String jobId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<JobModel?> getMostRecentJob(
    String customerId,
    String locksmithId,
  ) async {
    try {
      final querySnapshot = await _jobsCollection
          .where('customerId', isEqualTo: customerId)
          .where('locksmithId', isEqualTo: locksmithId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return JobModel.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      AppLogger.job('Error getting most recent job: $e');
      return null;
    }
  }

  Future<void> addContact(Contact contact) async {
    try {
      final existingContact = await _contactsCollection
          .where('customerId', isEqualTo: contact.customerId)
          .where('locksmithId', isEqualTo: contact.locksmithId)
          .get();

      if (existingContact.docs.isEmpty) {
        await _contactsCollection.add(contact.toFirestore());
      } else {
        AppLogger.firestore('Contact already exists.');
      }
    } catch (e) {
      AppLogger.firestore("Error adding contact: $e");
      rethrow;
    }
  }

  Stream<List<Contact>> getContacts(String customerId) {
    return _contactsCollection
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Contact.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _contactsCollection.doc(contactId).delete();
    } catch (e) {
      AppLogger.firestore("Error deleting contact: $e");
      rethrow;
    }
  }

  Future<void> addRepairerContact(RepairerContactModel contact) async {
    try {
      final existingContact = await _repairerContactsCollection
          .where('repairerId', isEqualTo: contact.repairerId)
          .where('customerId', isEqualTo: contact.customerId)
          .get();

      if (existingContact.docs.isEmpty) {
        await _repairerContactsCollection.add(contact.toFirestore());
      } else {
        AppLogger.firestore('Repairer contact already exists.');
      }
    } catch (e) {
      AppLogger.firestore("Error adding repairer contact: $e");
      rethrow;
    }
  }

  Stream<List<RepairerContactModel>> getRepairerContacts(String repairerId) {
    return _repairerContactsCollection
        .where('repairerId', isEqualTo: repairerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RepairerContactModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> deleteRepairerContact(String contactId) async {
    try {
      await _repairerContactsCollection.doc(contactId).delete();
    } catch (e) {
      AppLogger.firestore("Error deleting repairer contact: $e");
      rethrow;
    }
  }

  // Lấy các công việc đã được xác nhận và sắp diễn ra để kiểm tra tự động
  Future<List<JobModel>> getUpcomingConfirmedJobs(String repairerId) async {
    try {
      final querySnapshot = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where('status', isEqualTo: 'confirmed')
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('scheduledAt')
          .get();

      return querySnapshot.docs
          .map(
            (doc) => JobModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.job('Lỗi khi lấy các công việc đã xác nhận sắp tới: $e');
      return [];
    }
  }

  // Lấy danh sách các công việc đã lên lịch hoặc đã xác nhận trong tương lai của thợ
  Future<List<JobModel>> getScheduledAndConfirmedJobsForRepairer(
    String repairerId,
  ) async {
    try {
      final querySnapshot = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where('status', whereIn: ['scheduled', 'confirmed'])
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('scheduledAt')
          .get();

      return querySnapshot.docs
          .map(
            (doc) => JobModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.job('Lỗi khi lấy lịch hẹn của thợ: $e');
      return [];
    }
  }

  Future<QuerySnapshot> getCompletedJobsForRepairer(
    String repairerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _jobsCollection
        .where('locksmithId', isEqualTo: repairerId)
        .where('status', isEqualTo: 'completed');

    if (startDate != null) {
      query = query.where(
        'paymentTimestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'paymentTimestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.orderBy('paymentTimestamp', descending: true);

    return query.get();
  }

  // Lấy danh sách công việc đang thực hiện và đã lên lịch
  Stream<List<JobModel>> getActiveAndScheduledJobs(String repairerId) {
    return _jobsCollection
        .where('locksmithId', isEqualTo: repairerId)
        .where('status', whereIn: ['accepted', 'confirmed', 'in_progress'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => JobModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
        });
  }

  // Cập nhật trạng thái của repairer
  Future<void> updateRepairerStatus(
    String repairerId,
    RepairerStatus status, {
    String? currentJobId,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status.name};

      // Nếu có currentJobId, thêm vào update
      if (currentJobId != null) {
        updateData['currentJobId'] = currentJobId;
      } else if (status != RepairerStatus.busy_instant) {
        // Nếu không busy_instant, xóa currentJobId
        updateData['currentJobId'] = null;
      }

      await _usersCollection.doc(repairerId).update(updateData);
    } catch (e) {
      AppLogger.firestore('Lỗi cập nhật trạng thái repairer: $e');
      rethrow;
    }
  }

  // Cập nhật trạng thái user
  Future<void> updateUserStatus(String userId, RepairerStatus status) async {
    try {
      await _usersCollection.doc(userId).update({'status': status.name});
    } catch (e) {
      AppLogger.firestore('Lỗi khi cập nhật trạng thái user: $e');
      rethrow;
    }
  }

  // Cập nhật trạng thái work session
  Future<void> updateWorkSessionStatus(
    String jobId,
    String sessionId,
    String status,
  ) async {
    try {
      await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('work_sessions')
          .doc(sessionId)
          .update({'status': status});
    } catch (e) {
      AppLogger.firestore('Lỗi khi cập nhật trạng thái work session: $e');
      rethrow;
    }
  }

  // Lấy các work sessions đang active cho một job
  Future<List<WorkSessionModel>> getActiveWorkSessionsForJob(
    String jobId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('work_sessions')
          .where('status', whereIn: ['scheduled', 'in_progress'])
          .get();

      return querySnapshot.docs
          .map(
            (doc) => WorkSessionModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.firestore('Lỗi khi lấy active work sessions: $e');
      return [];
    }
  }

  Future<List<JobModel>> getCompletedJobsNotSynced(String repairerId) async {
    try {
      final querySnapshot = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where('status', isEqualTo: 'completed')
          .where('isSynced', isEqualTo: false)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => JobModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.job('Error getting unsynced completed jobs: $e');
      return [];
    }
  }

  // Lấy danh sách phiên làm việc cho một job
  Future<List<WorkSessionModel>> getWorkSessionsForJob(String jobId) async {
    try {
      final querySnapshot = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('work_sessions')
          .orderBy('sessionNumber')
          .get();

      return querySnapshot.docs
          .map(
            (doc) => WorkSessionModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.firestore('Lỗi khi lấy phiên làm việc: $e');
      return [];
    }
  }

  // Lấy job theo ID
  Future<JobModel?> getJob(String jobId) async {
    try {
      final docSnapshot = await _jobsCollection.doc(jobId).get();
      if (docSnapshot.exists) {
        return JobModel.fromFirestore(
          docSnapshot as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      AppLogger.job('Lỗi khi lấy job: $e');
      return null;
    }
  }

  // Lấy tất cả các phiên làm việc của thợ từ tất cả các job
  Future<List<WorkSessionModel>> getAllWorkSessionsForRepairer(
    String repairerId,
  ) async {
    try {
      // Lấy tất cả các job của thợ (cả instant và scheduled)
      final jobsSnapshot = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where(
            'status',
            whereIn: [
              'pending',
              'accepted',
              'confirmed',
              'scheduled',
              'in_progress',
            ],
          )
          .get();

      List<WorkSessionModel> allWorkSessions = [];

      // Lấy phiên làm việc từ mỗi job
      for (var jobDoc in jobsSnapshot.docs) {
        final workSessionsSnapshot = await _firestore
            .collection('jobs')
            .doc(jobDoc.id)
            .collection('work_sessions')
            .where('status', whereIn: ['scheduled', 'in_progress'])
            .get();

        for (var sessionDoc in workSessionsSnapshot.docs) {
          final workSession = WorkSessionModel.fromFirestore(
            sessionDoc as DocumentSnapshot<Map<String, dynamic>>,
          );
          allWorkSessions.add(workSession);
        }
      }

      // Sắp xếp theo thời gian bắt đầu
      allWorkSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      return allWorkSessions;
    } catch (e) {
      AppLogger.firestore('Lỗi khi lấy tất cả phiên làm việc của thợ: $e');
      return [];
    }
  }

  // Kiểm tra xung đột thời gian cho repairer
  Future<TimeConflictResult> checkTimeConflict(
    String repairerId,
    DateTime startTime,
    DateTime endTime, {
    String? excludeJobId,
    Duration bufferTime = const Duration(minutes: 30),
  }) async {
    try {
      List<TimeConflict> conflicts = [];

      // 1. Kiểm tra với lịch hẹn (scheduled jobs)
      final scheduledJobs = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where('status', whereIn: ['scheduled', 'confirmed'])
          .get();

      for (var jobDoc in scheduledJobs.docs) {
        final job = JobModel.fromFirestore(
          jobDoc as DocumentSnapshot<Map<String, dynamic>>,
        );

        // Bỏ qua job hiện tại nếu đang cập nhật
        if (excludeJobId != null && job.id == excludeJobId) continue;

        final jobStart = job.scheduledAt!.toDate();
        final jobEnd =
            job.scheduledEndTime?.toDate() ??
            jobStart.add(const Duration(hours: 2));

        if (_hasTimeOverlap(startTime, endTime, jobStart, jobEnd, bufferTime)) {
          conflicts.add(
            TimeConflict(
              type: ConflictType.scheduledJob,
              title: 'Lịch hẹn',
              description: 'Dịch vụ: ${job.service}',
              startTime: jobStart,
              endTime: jobEnd,
              jobId: job.id,
            ),
          );
        }
      }

      // 2. Kiểm tra với phiên làm việc
      final workSessions = await getAllWorkSessionsForRepairer(repairerId);

      for (var session in workSessions) {
        final sessionStart = session.startTime.toDate();
        final sessionEnd =
            session.estimatedEndTime?.toDate() ??
            sessionStart.add(const Duration(hours: 2));

        if (_hasTimeOverlap(
          startTime,
          endTime,
          sessionStart,
          sessionEnd,
          bufferTime,
        )) {
          conflicts.add(
            TimeConflict(
              type: ConflictType.workSession,
              title: 'Phiên làm việc #${session.sessionNumber}',
              description: session.description,
              startTime: sessionStart,
              endTime: sessionEnd,
              sessionId: session.id,
            ),
          );
        }
      }

      return TimeConflictResult(
        hasConflict: conflicts.isNotEmpty,
        conflicts: conflicts,
      );
    } catch (e) {
      AppLogger.firestore('Lỗi khi kiểm tra xung đột thời gian: $e');
      return TimeConflictResult(hasConflict: false, conflicts: []);
    }
  }

  // Kiểm tra xung đột thời gian cho customer khi đặt lịch
  Future<TimeConflictResult> checkCustomerTimeConflict(
    String repairerId,
    DateTime startTime,
    DateTime endTime, {
    Duration bufferTime = const Duration(minutes: 30),
  }) async {
    try {
      List<TimeConflict> conflicts = [];

      // Chỉ kiểm tra với lịch hẹn đã được xác nhận
      final confirmedJobs = await _jobsCollection
          .where('locksmithId', isEqualTo: repairerId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      for (var jobDoc in confirmedJobs.docs) {
        final job = JobModel.fromFirestore(
          jobDoc as DocumentSnapshot<Map<String, dynamic>>,
        );

        final jobStart = job.scheduledAt!.toDate();
        final jobEnd =
            job.scheduledEndTime?.toDate() ??
            jobStart.add(const Duration(hours: 2));

        if (_hasTimeOverlap(startTime, endTime, jobStart, jobEnd, bufferTime)) {
          conflicts.add(
            TimeConflict(
              type: ConflictType.scheduledJob,
              title: 'Lịch hẹn đã xác nhận',
              description: 'Dịch vụ: ${job.service}',
              startTime: jobStart,
              endTime: jobEnd,
              jobId: job.id,
            ),
          );
        }
      }

      return TimeConflictResult(
        hasConflict: conflicts.isNotEmpty,
        conflicts: conflicts,
      );
    } catch (e) {
      AppLogger.firestore(
        'Lỗi khi kiểm tra xung đột thời gian cho customer: $e',
      );
      return TimeConflictResult(hasConflict: false, conflicts: []);
    }
  }

  // Helper method để kiểm tra overlap
  bool _hasTimeOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
    Duration bufferTime,
  ) {
    // Thêm buffer time vào thời gian
    final adjustedStart1 = start1.subtract(bufferTime);
    final adjustedEnd1 = end1.add(bufferTime);
    final adjustedStart2 = start2.subtract(bufferTime);
    final adjustedEnd2 = end2.add(bufferTime);

    // Kiểm tra overlap
    return adjustedStart1.isBefore(adjustedEnd2) &&
        adjustedEnd1.isAfter(adjustedStart2);
  }

  // Cập nhật thời gian kết thúc dự kiến cho phiên làm việc
  Future<void> updateWorkSessionEstimatedEndTime(
    String jobId,
    String sessionId,
    DateTime estimatedEndTime,
  ) async {
    try {
      await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('work_sessions')
          .doc(sessionId)
          .update({'estimatedEndTime': Timestamp.fromDate(estimatedEndTime)});

      // Gửi thông báo cập nhật thời gian
      await _sendWorkSessionTimeUpdateNotification(
        jobId,
        sessionId,
        estimatedEndTime,
      );
    } catch (e) {
      AppLogger.firestore('Lỗi khi cập nhật thời gian kết thúc dự kiến: $e');
      rethrow;
    }
  }

  // Gửi thông báo khi cập nhật thời gian phiên làm việc
  Future<void> _sendWorkSessionTimeUpdateNotification(
    String jobId,
    String sessionId,
    DateTime newEstimatedEndTime,
  ) async {
    try {
      // Lấy thông tin job và session
      final jobDoc = await _jobsCollection.doc(jobId).get();
      final sessionDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('work_sessions')
          .doc(sessionId)
          .get();

      if (!jobDoc.exists || !sessionDoc.exists) return;

      final job = JobModel.fromFirestore(
        jobDoc as DocumentSnapshot<Map<String, dynamic>>,
      );
      final session = WorkSessionModel.fromFirestore(
        sessionDoc as DocumentSnapshot<Map<String, dynamic>>,
      );

      final newTimeFormatted = DateFormat(
        'HH:mm dd/MM/yyyy',
      ).format(newEstimatedEndTime);

      final notificationText =
          '''⏰ **Cập nhật thời gian phiên làm việc**

📋 **Thông tin cập nhật:**
• Số phiên: #${session.sessionNumber}
• Thời gian kết thúc mới: $newTimeFormatted
• Mô tả: ${session.description}

💬 Bạn có thể nhắn tin với thợ để trao đổi thêm chi tiết.''';

      final notificationMessage = MessageModel(
        senderId: 'system',
        receiverId: job.customerId,
        text: notificationText,
        timestamp: Timestamp.now(),
      );

      await addMessage(jobId, notificationMessage);
      await updateJob(jobId, {
        'lastMessage': 'Thời gian phiên làm việc được cập nhật',
        'lastMessageTimestamp': notificationMessage.timestamp,
      });
    } catch (e) {
      AppLogger.firestore('Lỗi khi gửi thông báo cập nhật thời gian: $e');
    }
  }
}
