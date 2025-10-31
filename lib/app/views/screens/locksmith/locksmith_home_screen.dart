import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/common/job_details_screen.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/my_services_screen.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/job_controller.dart';
import 'package:intl/intl.dart';

class LocksmithHomeScreen extends StatefulWidget {
  const LocksmithHomeScreen({super.key});

  @override
  State<LocksmithHomeScreen> createState() => _LocksmithHomeScreenState();
}

class _LocksmithHomeScreenState extends State<LocksmithHomeScreen> {
  final AuthController _authController = AuthController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _promptScheduledEndTimeAndConfirm(JobModel job) async {
    DateTime? selectedEndTime;
    final scheduledStartTime = job.scheduledAt!.toDate();

    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Xác nhận Lịch hẹn'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khách hàng đã đặt lịch vào lúc:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm, dd/MM/yyyy').format(scheduledStartTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Vui lòng chọn thời gian kết thúc dự kiến:'),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedEndTime == null
                          ? 'Nhấn để chọn...'
                          : DateFormat(
                              'HH:mm, dd/MM/yyyy',
                            ).format(selectedEndTime!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: scheduledStartTime,
                        firstDate: scheduledStartTime,
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate == null) return;

                      if (!context.mounted) return;

                      final initialTimeOfDay = TimeOfDay.fromDateTime(
                        scheduledStartTime.add(const Duration(hours: 2)),
                      );
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: initialTimeOfDay,
                      );
                      if (pickedTime == null) return;

                      setStateDialog(() {
                        selectedEndTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: selectedEndTime == null
                      ? null
                      : () {
                          if (selectedEndTime!.isBefore(scheduledStartTime)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Thời gian kết thúc phải sau thời gian bắt đầu.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(true);
                        },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );

    if (isConfirmed == true && selectedEndTime != null) {
      try {
        final jobController = JobController();
        await jobController.confirmScheduledJobWithEndTime(
          job.id!,
          selectedEndTime!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã xác nhận lịch hẹn và lưu thời gian kết thúc dự kiến.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController là widget cha để quản lý các tab
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bảng điều khiển'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.miscellaneous_services),
              tooltip: 'Dịch vụ của tôi',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyServicesScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: () {
                _authController.signOut();
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.new_releases), text: 'Yêu cầu Mới'),
              Tab(icon: Icon(Icons.construction), text: 'Đang thực hiện'),
              Tab(icon: Icon(Icons.history), text: 'Lịch sử'),
              Tab(icon: Icon(Icons.check_box), text: 'Đã xác nhận'),
            ],
          ),
        ),
        // TabBarView chứa nội dung của các tab tương ứng
        body: TabBarView(
          children: [
            _buildJobsList(status: 'pending'),
            _buildJobsList(status: 'in_progress'),
            _buildJobsList(status: 'history'),
            _buildJobsList(status: 'confirmed'),
          ],
        ),
      ),
    );
  }

  /// Widget trợ giúp để xây dựng danh sách công việc dựa trên trạng thái
  Widget _buildJobsList({required String status}) {
    final FirestoreService firestoreService = FirestoreService();
    final JobController jobController = JobController();

    // Lấy đúng stream dựa trên trạng thái được truyền vào
    Stream<List<JobModel>> jobsStream;
    if (status == 'pending') {
      jobsStream = firestoreService.getJobsForLocksmith(_currentUser!.uid);
    } else if (status == 'accepted') {
      jobsStream = firestoreService.getAcceptedJobsForLocksmith(
        _currentUser!.uid,
      );
    } else if (status == 'in_progress') {
      // Tab "Đang thực hiện" bao gồm cả accepted và in_progress
      jobsStream = firestoreService.getActiveAndScheduledJobs(
        _currentUser!.uid,
      );
    } else if (status == 'confirmed') {
      jobsStream = firestoreService.getScheduledJobsForLocksmith(
        _currentUser!.uid,
      );
    } else {
      // status == 'history'
      jobsStream = firestoreService.getJobHistoryForLocksmith(
        _currentUser!.uid,
      );
    }

    /// Widget trợ giúp để tạo widget trailing cho ListTile
    Widget? _buildTrailingForStatus(
      String status,
      JobModel job,
      JobController jobController,
    ) {
      // Kiểm tra trạng thái thực tế của job thay vì chỉ kiểm tra status parameter của tab
      final actualJobStatus = job.status;

      switch (actualJobStatus) {
        case 'pending':
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  onPressed: () {
                    if (job.jobType == JobType.scheduled ||
                        job.status == 'scheduled') {
                      _promptScheduledEndTimeAndConfirm(job);
                    } else {
                      jobController.acceptJob(job);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: () => jobController.rejectJob(job),
                ),
              ),
            ],
          );
        case 'accepted':
          return Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () => jobController.startInstantJob(job),
              tooltip: 'Bắt đầu công việc',
            ),
          );
        case 'in_progress':
          return Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work, color: Colors.white),
          );
        case 'scheduled':
          // Job đã được lên lịch nhưng chưa được xác nhận
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  onPressed: () => _promptScheduledEndTimeAndConfirm(job),
                  tooltip: 'Xác nhận lịch hẹn',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: () => jobController.rejectJob(job),
                  tooltip: 'Từ chối lịch hẹn',
                ),
              ),
            ],
          );
        case 'confirmed':
          return null;
        case 'history':
        case 'completed':
        case 'rated':
        case 'rejected':
          return Chip(
            label: Text(
              _getStatusChipText(job.status),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: _getStatusChipColor(job.status),
          );
        default:
          return null;
      }
    }

    return StreamBuilder<List<JobModel>>(
      stream: jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 16),
                Text(
                  'Đang tải dữ liệu...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          AppLogger.job('${snapshot.error}');
          return const Center(child: Text('Đã xảy ra lỗi khi tải dữ liệu.'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có yêu cầu nào trong mục này.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hãy chờ yêu cầu mới từ khách hàng',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final jobs = snapshot.data!;
        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            // Bọc Card trong GestureDetector để có thể nhấn vào
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
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    'Khách hàng: ${job.customerName} (${job.jobType == JobType.instant ? 'Tức thì' : 'Đặt lịch'}) - ${_getStatusDisplayText(job.status)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (status == 'confirmed' || job.status == 'confirmed')
                              ? 'Thời gian: ${DateFormat('HH:mm dd/MM/yyyy').format(job.scheduledAt!.toDate())}'
                              : "Địa chỉ: ${job.addressLine}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        if (job.status == 'accepted')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đã chấp nhận - Nhấn để bắt đầu công việc',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (job.status == 'scheduled')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đã lên lịch - Chờ xác nhận',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (job.status == 'confirmed')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đã xác nhận - Chờ đến giờ làm việc',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (job.status == 'in_progress')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đang thực hiện công việc',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (status == 'history' &&
                            (job.status == 'completed' ||
                                job.status == 'rated'))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Thu nhập: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(job.finalPrice ?? 0)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: _buildTrailingForStatus(status, job, jobController),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getStatusChipText(String status) {
    switch (status) {
      case 'completed':
      case 'rated':
        return 'Hoàn thành';
      case 'rejected':
        return 'Đã từ chối';
      case 'cancelled_by_locksmith':
        return 'Đã hủy';
      default:
        return 'Lịch sử';
    }
  }

  Color _getStatusChipColor(String status) {
    switch (status) {
      case 'completed':
      case 'rated':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'cancelled_by_locksmith':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'pending':
        return 'Yêu cầu mới';
      case 'accepted':
        return 'Đã chấp nhận';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'scheduled':
        return 'Đã lên lịch';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'history':
        return 'Lịch sử';
      default:
        return status;
    }
  }
}
