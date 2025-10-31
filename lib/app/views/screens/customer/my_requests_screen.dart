import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/rating_controller.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';
import 'package:flutter_application_test/app/views/screens/common/payment_selection_screen.dart';
import 'package:flutter_application_test/app/views/screens/common/job_details_screen.dart';
import 'package:intl/intl.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<JobModel> _previousJobs = [];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yêu cầu của tôi'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.lightBlue.shade600,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          bottom: TabBar(
            labelColor: Colors.lightBlue.shade600,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.lightBlue.shade600,
            tabs: const [
              Tab(icon: Icon(Icons.schedule), text: 'Lịch hẹn'),
              Tab(icon: Icon(Icons.payment), text: 'Chờ thanh toán'),
              Tab(icon: Icon(Icons.list_alt), text: 'Tất cả'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildJobsList(isScheduledTab: true),
            _buildPaymentPendingJobsList(),
            _buildJobsList(isScheduledTab: false),
          ],
        ),
      ),
    );
  }

  // Hàm trợ giúp để lấy màu theo trạng thái
  Color getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'rated':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Hàm trợ giúp để lấy text theo trạng thái
  String getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Đã chấp nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'pending':
        return 'Đang chờ';
      case 'rated':
        return 'Đã đánh giá';
      case 'scheduled':
        return 'Đã lên lịch';
      case 'confirmed':
        return 'Thợ đã xác nhận';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'cancelled_by_locksmith':
        return 'Thợ đã hủy';
      default:
        return status;
    }
  }

  // Hàm trợ giúp để xây dựng widget ở cuối ListTile
  Widget _buildTrailingWidget(JobModel job) {
    if (job.status == 'payment_pending') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Thanh Toán', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSelectionScreen(job: job),
            ),
          );
        },
      );
    }
    if (job.status == 'completed') {
      return ElevatedButton(
        child: const Text('Đánh giá'),
        onPressed: () {
          _showRatingDialog(context, job);
        },
      );
    }
    if (job.status == 'rated') {
      return const Chip(
        label: Text('Đã đánh giá'),
        backgroundColor: Colors.grey,
      );
    }
    return Chip(
      label: Text(
        getStatusText(job.status),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: getStatusColor(job.status),
    );
  }

  Widget _buildJobsList({required bool isScheduledTab}) {
    final FirestoreService firestoreService = FirestoreService();
    final Stream<List<JobModel>> jobsStream = isScheduledTab
        ? firestoreService.getScheduledJobsForCustomer(_currentUserId)
        : firestoreService.getAllJobsForCustomer(_currentUserId);

    return StreamBuilder<List<JobModel>>(
      stream: jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.lightBlue.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đang tải danh sách...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          AppLogger.job('${snapshot.error}');
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Đã xảy ra lỗi.',
                  style: TextStyle(color: Colors.red[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  isScheduledTab ? Icons.schedule : Icons.list_alt,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  isScheduledTab
                      ? 'Bạn chưa có lịch hẹn nào.'
                      : 'Bạn chưa có yêu cầu nào.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isScheduledTab
                      ? 'Các lịch hẹn sẽ xuất hiện ở đây.'
                      : 'Các yêu cầu sẽ xuất hiện ở đây.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final jobs = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
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
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isScheduledTab ? Icons.schedule : Icons.work,
                              color: Colors.lightBlue.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thợ: ${job.locksmithName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isScheduledTab
                                      ? 'Dịch vụ: ${job.service}'
                                      : 'Địa chỉ: ${job.addressLine}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (job.status == 'completed' || job.status == 'rated')
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đã thanh toán: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(job.finalPrice ?? 0)}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Trạng thái: ${getStatusText(job.status)}',
                              style: TextStyle(
                                color: getStatusColor(job.status),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTrailingWidget(job),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _detectAndNotifyJobRejection(List<JobModel> currentJobs) {
    // Chỉ hoạt động nếu đã có dữ liệu trước đó
    if (_previousJobs.isEmpty) return;

    for (var currentJob in currentJobs) {
      // Tìm công việc tương ứng trong danh sách cũ
      final previousJob = _previousJobs.firstWhere(
        (job) => job.id == currentJob.id,
        orElse: () => currentJob, // Nếu là job mới, không so sánh
      );

      // Kiểm tra nếu trạng thái thay đổi từ bất kỳ trạng thái nào sang 'rejected'
      if (previousJob.status != 'rejected' && currentJob.status == 'rejected') {
        // Sử dụng WidgetsBinding để đảm bảo context hợp lệ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Yêu cầu cho "${currentJob.service}" đã bị thợ từ chối.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  Widget _buildPaymentPendingJobsList() {
    final FirestoreService firestoreService = FirestoreService();
    final Stream<List<JobModel>> jobsStream = firestoreService
        .getPaymentPendingJobsForCustomer(_currentUserId);

    return StreamBuilder<List<JobModel>>(
      stream: jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.lightBlue.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đang tải danh sách...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          AppLogger.job('${snapshot.error}');
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Đã xảy ra lỗi.',
                  style: TextStyle(color: Colors.red[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.payment, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Bạn chưa có yêu cầu chờ thanh toán nào.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Các công việc hoàn thành sẽ xuất hiện ở đây.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final jobs = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
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
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.payment,
                              color: Colors.lightBlue.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thợ: ${job.locksmithName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dịch vụ: ${job.service}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.addressLine,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (job.finalPrice != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Số tiền: ${job.finalPrice!.toStringAsFixed(0)} VNĐ',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.credit_card),
                          label: const Text('Thanh toán ngay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PaymentSelectionScreen(job: job),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRatingDialog(BuildContext context, JobModel job) {
    int _currentRating = 5;
    final TextEditingController _commentController = TextEditingController();
    final RatingController _ratingController = RatingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // setStateDialog là hàm setState cục bộ
            return AlertDialog(
              title: const Text('Đánh giá thợ sửa khóa'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Bạn đánh giá "${job.locksmithName}" thế nào?'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _currentRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 35,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              _currentRating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Viết bình luận (không bắt buộc)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Hủy'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Gửi'),
                  onPressed: () {
                    _ratingController
                        .handleSubmitRating(
                          job: job,
                          ratingValue: _currentRating,
                          comment: _commentController.text.trim(),
                        )
                        .then((success) {
                          Navigator.of(context).pop();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cảm ơn bạn đã đánh giá!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Có lỗi xảy ra, vui lòng thử lại.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
