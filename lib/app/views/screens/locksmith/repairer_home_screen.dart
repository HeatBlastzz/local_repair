import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/auth_controller.dart';
import 'package:flutter_application_test/app/controllers/job_controller.dart';
import 'package:flutter_application_test/app/controllers/status_manager.dart';
import 'package:flutter_application_test/app/views/screens/common/job_details_screen.dart';

import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_test/data/models/work_session_model.dart';
import 'package:flutter_application_test/utils/logger.dart';

class RepairerHomeScreen extends StatefulWidget {
  const RepairerHomeScreen({super.key});

  @override
  State<RepairerHomeScreen> createState() => _RepairerHomeScreenState();
}

class _RepairerHomeScreenState extends State<RepairerHomeScreen> {
  final AuthController _authController = AuthController();
  final FirestoreService _firestoreService = FirestoreService();
  final JobController _jobController = JobController();
  final StatusManager _statusManager = StatusManager();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  UserModel? _userModel;
  RepairerStatus _currentStatus = RepairerStatus.offline;
  bool _isLoading = true;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _startStatusCheckTimer();
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      try {
        final user = await _firestoreService.getUser(_currentUser.uid);
        if (mounted && user != null) {
          setState(() {
            _userModel = user;
            _currentStatus = user.status;
            _isLoading = false;
          });
        }
      } catch (e) {
        AppLogger.firestore('Lỗi load user data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_userModel == null) return;

    try {
      await _statusManager.toggleOnlineStatus(_userModel!.uid, _currentStatus);

      // Reload user data để lấy status mới
      await _loadUserData();

      if (mounted) {
        final statusText = _getStatusText(_currentStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trạng thái: $statusText'),
            backgroundColor: _getStatusColor(_currentStatus),
          ),
        );
      }
    } catch (e) {
      AppLogger.firestore('Lỗi cập nhật trạng thái: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(RepairerStatus status) {
    switch (status) {
      case RepairerStatus.offline:
        return 'OFFLINE';
      case RepairerStatus.available:
        return 'ONLINE - Sẵn sàng';
      case RepairerStatus.busy_instant:
        return 'BUSY - Đang làm việc tức thời';
    }
  }

  Color _getStatusColor(RepairerStatus status) {
    switch (status) {
      case RepairerStatus.offline:
        return Colors.grey;
      case RepairerStatus.available:
        return Colors.green;
      case RepairerStatus.busy_instant:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildOnlineToggle(),
          Expanded(child: _buildRequestsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: _userModel?.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _userModel!.photoUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.blue,
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 30, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userModel?.name ?? 'Repairer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userModel?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Logout button
              TextButton(
                onPressed: () async {
                  await _authController.signOut();
                  // Điều hướng về login screen sau khi logout
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (Route<dynamic> route) => false,
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(_currentStatus),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(_currentStatus),
                      ),
                    ),
                    if (_currentStatus == RepairerStatus.busy_instant)
                      Text(
                        '⏰ Vẫn có thể đặt lịch hẹn',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              // Toggle chỉ cho offline <-> available, không cho busy_instant
              if (_currentStatus != RepairerStatus.busy_instant)
                Switch(
                  value: _currentStatus == RepairerStatus.available,
                  onChanged: (value) => _toggleOnlineStatus(),
                  activeColor: Colors.white,
                  activeTrackColor: Colors.green,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey[300],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_userModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Nếu busy_instant, hiển thị danh sách công việc đang làm
    if (_currentStatus == RepairerStatus.busy_instant) {
      return _buildBusyJobsList();
    }

    // Luôn hiển thị giao diện offline mode (lịch hẹn + work sessions)
    return _buildScheduledJobsList();
  }

  Widget _buildRequestCard(JobModel request) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: request.id!),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleAcceptRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Chấp nhận'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _jobController.rejectJob(request);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã từ chối yêu cầu'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Từ chối'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.addressLine,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.build, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Dịch vụ: ${request.service}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusyJobsList() {
    if (_userModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.work, color: Colors.orange[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Công việc đang thực hiện & Lịch hẹn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[600],
                ),
              ),
            ],
          ),
        ),

        // Jobs list
        Expanded(
          child: StreamBuilder<List<JobModel>>(
            stream: _firestoreService.getActiveAndScheduledJobs(
              _userModel!.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                AppLogger.job('Lỗi load active jobs: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Lỗi tải danh sách công việc',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không có công việc nào',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final jobs = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return _buildBusyJobCard(job);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBusyJobCard(JobModel job) {
    final isScheduled = job.jobType == JobType.scheduled;
    final hasScheduledTime = job.scheduledAt != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job.id!),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isScheduled
                          ? Colors.blue[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isScheduled ? 'Lên lịch' : 'Trực tiếp',
                      style: TextStyle(
                        fontSize: 12,
                        color: isScheduled
                            ? Colors.blue[800]
                            : Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Address
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.addressLine,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Service
              Row(
                children: [
                  Icon(Icons.build, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Dịch vụ: ${job.service}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),

              // Scheduled time (if available)
              if (hasScheduledTime) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Thời gian: ${DateFormat('dd/MM HH:mm').format(job.scheduledAt!.toDate())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              // End time (if available)
              if (job.scheduledEndTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_off, size: 16, color: Colors.purple[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Kết thúc: ${DateFormat('dd/MM HH:mm').format(job.scheduledEndTime!.toDate())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAcceptRequest(JobModel request) async {
    if (request.jobType == JobType.instant) {
      try {
        await _statusManager.onJobAccepted(request);

        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã chấp nhận yêu cầu. Bạn đã chuyển sang trạng thái bận.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailsScreen(jobId: request.id!),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      final DateTime? endTime = await _showEndTimeInputDialog(request);

      if (endTime != null && mounted) {
        try {
          await _jobController.confirmScheduledJobWithEndTime(
            request.id!,
            endTime,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xác nhận lịch hẹn thành công!'),
              backgroundColor: Colors.blue,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<DateTime?> _showEndTimeInputDialog(JobModel request) async {
    final now = DateTime.now();

    final initialDateTime = request.scheduledAt!.toDate().isAfter(now)
        ? request.scheduledAt!.toDate()
        : now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: initialDateTime,
      lastDate: DateTime(2101),
      helpText: 'CHỌN NGÀY KẾT THÚC',
    );

    if (pickedDate == null) return null;

    if (!context.mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      helpText: 'CHỌN GIỜ KẾT THÚC',
    );

    if (pickedTime == null) return null;

    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Kiểm tra xem thời gian kết thúc có sau thời gian bắt đầu không
    if (finalDateTime.isBefore(request.scheduledAt!.toDate())) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Thời gian kết thúc phải sau thời gian bắt đầu.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return finalDateTime;
  }

  // Hiển thị danh sách các công việc được lên lịch khi offline
  Widget _buildScheduledJobsList() {
    if (_userModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.getScheduledJobsForLocksmith(_userModel!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          AppLogger.job('Lỗi load scheduled jobs: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text(
                  'Lỗi tải dữ liệu',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Không có lịch hẹn nào',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bật trạng thái online để nhận yêu cầu mới',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final scheduledJobs = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị work sessions lên trước để luôn thấy
            _buildWorkSessionsSection(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Lịch hẹn sắp tới (${scheduledJobs.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: scheduledJobs.length,
                itemBuilder: (context, index) {
                  final job = scheduledJobs[index];
                  return _buildScheduledJobCard(job);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Hiển thị section work sessions
  Widget _buildWorkSessionsSection() {
    if (_userModel == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<WorkSessionModel>>(
      future: _firestoreService.getAllWorkSessionsForRepairer(_userModel!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final workSessions = snapshot.data!;
        final activeSessions = workSessions
            .where(
              (session) =>
                  session.status == 'scheduled' ||
                  session.status == 'in_progress',
            )
            .toList();

        if (activeSessions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.work, color: Colors.orange[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Phiên làm việc (${activeSessions.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: activeSessions.length,
                  itemBuilder: (context, index) {
                    final session = activeSessions[index];
                    return _buildWorkSessionCard(session);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkSessionCard(WorkSessionModel session) {
    final startTime = session.startTime.toDate();
    final endTime = session.estimatedEndTime?.toDate();
    final isToday = DateTime.now().difference(startTime).inDays == 0;
    final isUpcoming = startTime.isAfter(DateTime.now());

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: session.status == 'in_progress'
                          ? Colors.green[100]
                          : (isToday ? Colors.orange[100] : Colors.blue[100]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status == 'in_progress'
                          ? 'ĐANG LÀM'
                          : (isToday ? 'HÔM NAY' : 'SẮP TỚI'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: session.status == 'in_progress'
                            ? Colors.green[800]
                            : (isToday ? Colors.orange[800] : Colors.blue[800]),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.work,
                    size: 18,
                    color: session.status == 'in_progress'
                        ? Colors.green[600]
                        : Colors.orange[600],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Phiên #${session.sessionNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                session.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${DateFormat('HH:mm dd/MM').format(startTime)}${endTime != null ? ' - ${DateFormat('HH:mm dd/MM').format(endTime)}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledJobCard(JobModel job) {
    final scheduledTime = job.scheduledAt!.toDate();
    final isToday = DateTime.now().difference(scheduledTime).inDays == 0;
    final isUpcoming = scheduledTime.isAfter(DateTime.now());

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job.id!),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.orange[100] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isToday ? 'HÔM NAY' : 'SẮP TỚI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.orange[800] : Colors.blue[800],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    size: 20,
                    color: isUpcoming ? Colors.blue[600] : Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.service,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.customerName,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.addressLine,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm dd/MM/yyyy').format(scheduledTime),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startStatusCheckTimer() {
    // Hủy timer cũ nếu có để tránh chạy nhiều timer cùng lúc
    _statusCheckTimer?.cancel();

    // Tạo một timer mới chạy mỗi phút
    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      AppLogger.job("Timer check: Checking for upcoming jobs...");
      _checkScheduledJobs();
    });
  }

  Future<void> _checkScheduledJobs() async {
    // Chỉ kiểm tra nếu thợ đang rảnh và đã đăng nhập
    if (_currentStatus != RepairerStatus.available || _userModel == null) {
      return;
    }

    try {
      final upcomingJobs = await _firestoreService.getUpcomingConfirmedJobs(
        _userModel!.uid,
      );
      final now = DateTime.now();

      for (final job in upcomingJobs) {
        final jobStartTime = job.scheduledAt!.toDate();

        // Nếu đã đến giờ làm việc (hoặc trễ một chút)
        if (now.isAfter(jobStartTime) || now.isAtSameMomentAs(jobStartTime)) {
          AppLogger.job("Found an upcoming job to start: ${job.id}");

          // Chuyển trạng thái của thợ thành busy
          await _statusManager.onJobAccepted(job);

          // Tải lại dữ liệu người dùng để cập nhật UI
          await _loadUserData();

          // Dừng vòng lặp vì chúng ta chỉ xử lý một công việc tại một thời điểm
          break;
        }
      }
    } catch (e) {
      AppLogger.job("Lỗi khi kiểm tra lịch hẹn tự động: $e");
    }
  }
}
