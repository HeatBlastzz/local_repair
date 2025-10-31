import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/job_controller.dart';
import 'package:flutter_application_test/app/controllers/status_manager.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/utils/logger.dart';
import 'package:flutter_application_test/data/models/work_session_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../data/models/job_model.dart';
import 'package:intl/intl.dart';
import '../common/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_test/app/controllers/contact_controller.dart';
import 'package:flutter_application_test/app/controllers/repairer_contact_controller.dart';
import 'package:flutter_application_test/data/models/contact_model.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/payment_request_screen.dart';
import 'package:flutter_application_test/app/views/screens/common/payment_selection_screen.dart';
import 'package:flutter_application_test/data/models/repairer_contact_model.dart';

import 'navigation_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;

  const JobDetailsScreen({super.key, required this.jobId});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final JobController _jobController = JobController();
  final StatusManager _statusManager = StatusManager();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userModel = await _firestoreService.getUser(user.uid);
      AppLogger.debug(
        '[Debug] Đã tải người dùng: ${userModel?.name}, Role: ${userModel?.role}',
      );
      if (mounted) {
        setState(() {
          _currentUser = userModel;
        });
      }
    }
  }

  void _showAddSessionDialog(JobModel job) {
    final descriptionController = TextEditingController();
    DateTime? selectedStartTime;
    DateTime? selectedEndTime;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Tạo Phiên Làm Việc Mới'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả công việc',
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Vui lòng nhập mô tả' : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        selectedStartTime == null
                            ? 'Chọn thời gian bắt đầu'
                            : DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(selectedStartTime!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(DateTime.now()),
                        );
                        if (time == null) return;

                        setStateDialog(() {
                          selectedStartTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          selectedEndTime = selectedStartTime!.add(
                            const Duration(hours: 2),
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        selectedEndTime == null
                            ? 'Chọn thời gian kết thúc dự kiến'
                            : DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(selectedEndTime!),
                      ),
                      subtitle:
                          selectedStartTime != null && selectedEndTime != null
                          ? Text(
                              'Thời gian dự kiến: ${selectedEndTime!.difference(selectedStartTime!).inHours}h ${selectedEndTime!.difference(selectedStartTime!).inMinutes % 60}p',
                            )
                          : null,
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        if (selectedStartTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng chọn thời gian bắt đầu trước',
                              ),
                            ),
                          );
                          return;
                        }

                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStartTime!,
                          firstDate: selectedStartTime!,
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            selectedStartTime!.add(const Duration(hours: 2)),
                          ),
                        );
                        if (time == null) return;

                        final endTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );

                        // Kiểm tra thời gian kết thúc phải sau thời gian bắt đầu
                        if (endTime.isBefore(selectedStartTime!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thời gian kết thúc phải sau thời gian bắt đầu',
                              ),
                            ),
                          );
                          return;
                        }

                        setStateDialog(() {
                          selectedEndTime = endTime;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() &&
                        selectedStartTime != null &&
                        selectedEndTime != null) {
                      final result = await _jobController.createNewWorkSession(
                        jobId: widget.jobId,
                        sessionNumber: job.sessionCount + 1,
                        description: descriptionController.text,
                        startTime: selectedStartTime!,
                        estimatedEndTime: selectedEndTime!,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (result != null &&
                            result.contains('Xung đột thời gian')) {
                          // Hiển thị dialog xung đột thời gian
                          _showTimeConflictDialog(result);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result == null
                                    ? 'Tạo phiên thành công!'
                                    : 'Lỗi: $result',
                              ),
                              backgroundColor: result == null
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      }
                    } else if (selectedStartTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn thời gian bắt đầu'),
                        ),
                      );
                    } else if (selectedEndTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng chọn thời gian kết thúc dự kiến',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Tạo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog hiển thị xung đột thời gian
  void _showTimeConflictDialog(String conflictMessage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text('Xung đột thời gian'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thời gian bạn chọn đã bị trùng với lịch trình hiện tại:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                conflictMessage.replaceAll('Xung đột thời gian:\n', ''),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Vui lòng chọn thời gian khác để tránh xung đột.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JobModel?>(
      stream: _firestoreService.getJobStream(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Không tìm thấy yêu cầu.')),
          );
        }

        final job = snapshot.data!;
        bool isRepairer = _currentUser?.role == 'repairer';
        bool isJobCompleted =
            job.status == 'completed' || job.status == 'rated';
        bool canNavigate =
            isRepairer &&
            (job.status == 'in_progress' ||
                job.status == 'ongoing' ||
                job.status == 'confirmed');
        AppLogger.debug(
          '[Debug] Navigation conditions: isRepairer=$isRepairer, job.status=${job.status}, canNavigate=$canNavigate',
        );

        bool canRequestPayment =
            isRepairer &&
            (job.status == 'in_progress' ||
                job.status == 'ongoing' ||
                job.status == 'confirmed') &&
            job.paymentStatus == 'unpaid';

        // Thêm điều kiện cho khách hàng thanh toán
        bool canCustomerPay = !isRepairer && job.status == 'payment_pending';

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ContactController()),
            ChangeNotifierProvider(create: (_) => RepairerContactController()),
          ],
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                job.service,
                style: TextStyle(
                  color: Colors.lightBlue.shade600,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.lightBlue.shade600,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          jobId: job.id!,
                          receiverId: isRepairer
                              ? job.customerId
                              : job.locksmithId,
                          chatPartnerName: isRepairer
                              ? job.customerName
                              : job.locksmithName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJobSummary(job, isRepairer, isJobCompleted),
                  const Divider(height: 32, thickness: 1, color: Colors.grey),
                  Text(
                    'Các Phiên Làm Việc',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSessionsList(job.id!, isRepairer),
                ],
              ),
            ),
            floatingActionButton: (isRepairer && !isJobCompleted)
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddSessionDialog(job),
                    label: const Text('Thêm Phiên'),
                    icon: const Icon(Icons.add),
                    backgroundColor: Colors.lightBlue.shade400,
                    foregroundColor: Colors.white,
                  )
                : null,
            bottomNavigationBar: _buildBottomBar(
              context,
              job,
              canRequestPayment,
              canCustomerPay,
              canNavigate,
              isRepairer,
            ),
          ),
        );
      },
    );
  }

  Widget? _buildBottomBar(
    BuildContext context,
    JobModel job,
    bool canRequestPayment,
    bool canCustomerPay,
    bool canNavigate,
    bool isRepairer,
  ) {
    List<Widget> buttons = [];

    // Thêm nút Dẫn đường nếu điều kiện thỏa mãn
    AppLogger.debug('[Debug] Building bottom bar: canNavigate=$canNavigate');

    if (canNavigate) {
      buttons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Dẫn đường'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.lightBlue.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            AppLogger.debug(
              '[Debug] Repairer location data: ${_currentUser?.defaultAddress}',
            );
            final repairerLocationData =
                _currentUser?.defaultAddress?['coordinates'];
            if (repairerLocationData == null) {
              AppLogger.debug('[Debug] No repairer location found');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Không tìm thấy vị trí của bạn. Vui lòng cập nhật hồ sơ.',
                  ),
                ),
              );
              return;
            }

            double repairerLat, repairerLng;
            AppLogger.debug(
              '[Debug] Repairer location data type: ${repairerLocationData.runtimeType}',
            );
            if (repairerLocationData is GeoPoint) {
              repairerLat = repairerLocationData.latitude;
              repairerLng = repairerLocationData.longitude;
              AppLogger.debug(
                '[Debug] Using GeoPoint: lat=$repairerLat, lng=$repairerLng',
              );
            } else if (repairerLocationData is Map) {
              repairerLat = (repairerLocationData['latitude'] ?? 0.0)
                  .toDouble();
              repairerLng = (repairerLocationData['longitude'] ?? 0.0)
                  .toDouble();
              AppLogger.debug(
                '[Debug] Using Map: lat=$repairerLat, lng=$repairerLng',
              );
            } else {
              AppLogger.debug('[Debug] Invalid location data format');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Định dạng vị trí của bạn không hợp lệ.'),
                ),
              );
              return;
            }

            final repairerPoint = Point(
              coordinates: Position(repairerLng, repairerLat),
            );
            final customerPoint = Point(
              coordinates: Position(
                job.location.longitude,
                job.location.latitude,
              ),
            );

            AppLogger.debug(
              '[Debug] Navigation: Repairer($repairerLat, $repairerLng) -> Customer(${job.location.latitude}, ${job.location.longitude})',
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NavigationScreen(
                  startPoint: repairerPoint,
                  endPoint: customerPoint,
                  destinationAddress: job.addressLine,
                ),
              ),
            );
          },
        ),
      );
    }

    // Thêm nút Bắt đầu công việc cho instant jobs đã được chấp nhận
    if (isRepairer &&
        job.status == 'accepted' &&
        job.jobType == JobType.instant) {
      buttons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Bắt đầu công việc'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            try {
              await _jobController.startInstantJob(job);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã bắt đầu công việc!'),
                    backgroundColor: Colors.green,
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
        ),
      );
    }

    if (canRequestPayment) {
      buttons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Hoàn thành công việc'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            try {
              // Chuyển trạng thái thợ về available ngay khi hoàn thành
              await _statusManager.onJobCompleted(job.locksmithId);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
                );
              }
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentRequestScreen(job: job),
                ),
              );
            }
          },
        ),
      );
    }

    if (canCustomerPay) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.credit_card),
          label: Text(
            'Thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(job.finalPrice)}',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.lightBlue.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentSelectionScreen(job: job),
              ),
            );
          },
        ),
      );
    }

    AppLogger.debug('[Debug] Bottom bar buttons count: ${buttons.length}');
    if (buttons.isNotEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(buttons.length, (index) {
              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? 8.0 : 0),
                child: buttons[index],
              );
            }),
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildJobSummary(JobModel job, bool isRepairer, bool isJobCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.lightBlue.shade50, Colors.lightBlue.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.lightBlue.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.work,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.service,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trạng thái: ${_getStatusText(job.status)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.lightBlue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin Chi tiết',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.person_outline,
                  'Thợ sửa chữa',
                  job.locksmithName,
                ),
                _buildInfoRow(
                  context,
                  Icons.location_on_outlined,
                  'Địa chỉ',
                  job.addressLine,
                ),
                _buildInfoRow(
                  context,
                  Icons.calendar_today_outlined,
                  'Ngày tạo',
                  DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt.toDate()),
                ),
                _buildInfoRow(
                  context,
                  Icons.info_outline,
                  'Trạng thái công việc',
                  _getStatusText(job.status),
                ),
                if (isJobCompleted && job.finalPrice != null)
                  _buildInfoRow(
                    context,
                    Icons.attach_money,
                    'Tổng chi phí',
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: 'VNĐ',
                    ).format(job.finalPrice),
                  ),
                if (isJobCompleted) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: isRepairer
                        ? Consumer<RepairerContactController>(
                            builder: (context, contactController, child) {
                              return ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                                label: const Text('Lưu khách hàng'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  final customerUser = await _firestoreService
                                      .getUser(job.customerId);
                                  if (customerUser == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Không tìm thấy thông tin khách hàng!',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final newContact = RepairerContactModel(
                                    id: '',
                                    repairerId: _currentUser!.uid,
                                    customerId: customerUser.uid,
                                    customerName:
                                        customerUser.name ?? 'Không có tên',
                                    customerPhone:
                                        customerUser.phoneNumber ??
                                        'Không có SĐT',
                                    customerAddress:
                                        customerUser
                                            .defaultAddress?['address_line'] ??
                                        'Không có địa chỉ',
                                  );

                                  final result = await contactController
                                      .addContact(newContact);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result ??
                                              'Đã lưu khách hàng vào danh bạ!',
                                        ),
                                        backgroundColor: result == null
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          )
                        : Consumer<ContactController>(
                            builder: (context, contactController, child) {
                              return ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                                label: const Text('Lưu vào danh bạ'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue.shade400,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  // Fetch the locksmith's full details to get their phone number
                                  final locksmithUser = await _firestoreService
                                      .getUser(job.locksmithId);
                                  if (locksmithUser == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Không tìm thấy thông tin thợ!',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final newContact = Contact(
                                    id: '', // Firestore will generate
                                    customerId: job.customerId,
                                    locksmithId: job.locksmithId,
                                    locksmithName: job.locksmithName,
                                    locksmithPhone:
                                        locksmithUser.phoneNumber ??
                                        'Không có SĐT',
                                    locksmithAddress: job.addressLine,
                                  );

                                  final result = await contactController
                                      .addContact(newContact);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result ?? 'Đã lưu thợ vào danh bạ!',
                                        ),
                                        backgroundColor: result == null
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'accepted':
        return 'Đã chấp nhận';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'ongoing':
        return 'Đang diễn ra';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'completed':
        return 'Hoàn thành';
      case 'rated':
        return 'Đã đánh giá';
      case 'payment_pending':
        return 'Chờ thanh toán';
      default:
        return status;
    }
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.lightBlue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.lightBlue.shade600, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey[800], fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(String jobId, bool isRepairer) {
    return StreamBuilder<List<WorkSessionModel>>(
      stream: _firestoreService.getWorkSessionsStream(jobId),
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
                  'Đang tải phiên làm việc...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Lỗi: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Xử lý khi stream đã active nhưng không có dữ liệu
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.work_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có phiên làm việc nào được tạo.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhấn nút "Thêm Phiên" để tạo phiên làm việc mới.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final sessions = snapshot.data!;
        return Column(
          children: sessions.map((session) {
            final startTime = DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(session.startTime.toDate());
            final endTime = session.estimatedEndTime != null
                ? DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(session.estimatedEndTime!.toDate())
                : 'Chưa xác định';
            final duration = session.estimatedEndTime != null
                ? session.estimatedEndTime!.toDate().difference(
                    session.startTime.toDate(),
                  )
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getSessionStatusColor(
                            session.status,
                          ),
                          radius: 20,
                          child: Text(
                            '${session.sessionNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.description,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildSessionInfoRow(
                                Icons.access_time,
                                'Bắt đầu: $startTime',
                              ),
                              const SizedBox(height: 4),
                              _buildSessionInfoRow(
                                Icons.schedule,
                                'Kết thúc dự kiến: $endTime',
                              ),
                              if (duration != null) ...[
                                const SizedBox(height: 4),
                                _buildSessionInfoRow(
                                  Icons.timer,
                                  'Thời gian dự kiến: ${duration.inHours}h ${duration.inMinutes % 60}p',
                                ),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getSessionStatusColor(
                                    session.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getSessionStatusColor(
                                      session.status,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _getSessionStatusText(session.status),
                                  style: TextStyle(
                                    color: _getSessionStatusColor(
                                      session.status,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Buttons cho repairer
                    if (isRepairer && session.status != 'completed') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (session.status == 'scheduled')
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Bắt đầu'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () =>
                                    _startWorkSession(jobId, session.id!),
                              ),
                            ),
                          if (session.status == 'in_progress') ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.pause),
                                label: const Text('Tạm dừng'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () =>
                                    _pauseWorkSession(jobId, session.id!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Hoàn thành'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () =>
                                    _completeWorkSession(jobId, session.id!),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSessionInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }

  Color _getSessionStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getSessionStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Đã lên lịch';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  // Bắt đầu phiên làm việc
  Future<void> _startWorkSession(String jobId, String sessionId) async {
    try {
      await _firestoreService.updateWorkSessionStatus(
        jobId,
        sessionId,
        'in_progress',
      );
      final job = await _firestoreService.getJob(jobId);
      if (job != null) {
        await _statusManager.onInstantJobAccepted(job);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bắt đầu phiên làm việc')),
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

  // Tạm dừng phiên làm việc
  Future<void> _pauseWorkSession(String jobId, String sessionId) async {
    try {
      await _firestoreService.updateWorkSessionStatus(
        jobId,
        sessionId,
        'scheduled',
      );
      final job = await _firestoreService.getJob(jobId);
      if (job != null) {
        await _statusManager.pauseWorkSession(job.locksmithId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạm dừng phiên làm việc')),
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

  // Hoàn thành phiên làm việc
  Future<void> _completeWorkSession(String jobId, String sessionId) async {
    try {
      final job = await _firestoreService.getJob(jobId);
      if (job != null) {
        await _statusManager.completeWorkSession(
          jobId,
          sessionId,
          job.locksmithId,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hoàn thành phiên làm việc')),
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
