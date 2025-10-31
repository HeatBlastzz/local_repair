import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/contact_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/app/controllers/customer_controller.dart';
import 'package:flutter_application_test/app/controllers/job_controller.dart';
import 'package:flutter_application_test/data/models/contact_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide ScreenCoordinate;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/chat_screen.dart';
import '../common/job_details_screen.dart';
import '../common/place_picker_screen.dart';
import 'package:flutter_application_test/data/models/job_model.dart';

// Helper class to flatten service data
class _ServiceOffering {
  final String majorId;
  final String serviceName;
  final num basePrice;

  _ServiceOffering({
    required this.majorId,
    required this.serviceName,
    required this.basePrice,
  });
}

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Assuming CustomerController can fetch the current user's data
    final user = await CustomerController().getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContactController(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Danh bạ Thợ')),
        body: Consumer<ContactController>(
          builder: (context, controller, child) {
            return StreamBuilder<List<Contact>>(
              stream: controller.getContactsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Đã xảy ra lỗi khi tải danh bạ.'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Danh bạ của bạn trống.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                final contacts = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.locksmithName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.phone, contact.locksmithPhone),
                            const SizedBox(height: 4),
                            _buildInfoRow(
                              Icons.location_on,
                              contact.locksmithAddress,
                            ),
                            const SizedBox(height: 8),
                            _buildRepairerStatus(contact.locksmithId),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Action Icons
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Gọi điện',
                                      onPressed: () {
                                        if (contact.locksmithPhone !=
                                            'Không có SĐT') {
                                          _makePhoneCall(
                                            contact.locksmithPhone,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Thợ này không có số điện thoại.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.message,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      tooltip: 'Nhắn tin',
                                      onPressed: () =>
                                          _navigateToChat(context, contact),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Xóa khỏi danh bạ',
                                      onPressed: () => _showDeleteConfirmation(
                                        context,
                                        contact,
                                        controller,
                                      ),
                                    ),
                                  ],
                                ),
                                // Request Button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Yêu cầu'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _currentUser == null
                                      ? null
                                      : () => _handleRequest(context, contact),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRepairerStatus(String repairerId) {
    return StreamBuilder<UserModel?>(
      stream: _firestoreService.streamUser(repairerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text(
            'Đang tải trạng thái...',
            style: TextStyle(color: Colors.grey),
          );
        }
        final repairer = snapshot.data!;

        IconData icon;
        String text;
        Color color;

        switch (repairer.status) {
          case RepairerStatus.offline:
            icon = Icons.circle;
            text = 'Ngoại tuyến';
            color = Colors.grey;
            break;
          case RepairerStatus.available:
            icon = Icons.check_circle;
            text = 'Sẵn sàng';
            color = Colors.green.shade600;
            break;
          case RepairerStatus.busy_instant:
            icon = Icons.work;
            text = 'Đang bận';
            color = Colors.orange.shade600;
            break;
        }

        return Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Contact contact,
    ContactController controller,
  ) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa "${contact.locksmithName}" khỏi danh bạ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        controller.deleteContact(contact.id).then((_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Đã xóa liên hệ.')));
          }
        });
      }
    });
  }

  Future<void> _navigateToChat(BuildContext context, Contact contact) async {
    if (_currentUser?.uid == null) return;

    final job = await _firestoreService.getMostRecentJob(
      _currentUser!.uid,
      contact.locksmithId,
    );

    if (job != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            jobId: job.id!,
            receiverId: contact.locksmithId,
            chatPartnerName: contact.locksmithName,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy cuộc trò chuyện nào.')),
      );
    }
  }

  Future<void> _handleRequest(BuildContext context, Contact contact) async {
    final repairer = await _firestoreService.getUser(contact.locksmithId);
    if (!mounted) return;

    if (repairer != null) {
      _showServiceSelectionSheet(repairer);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải thông tin chi tiết của thợ.'),
        ),
      );
    }
  }

  void _showServiceSelectionSheet(UserModel repairer) {
    final List<_ServiceOffering> serviceOfferings = [];
    repairer.services.forEach((majorId, majorData) {
      final offerings = majorData['offerings'] as List<dynamic>?;
      if (offerings != null) {
        for (var offering in offerings) {
          if (offering is Map<String, dynamic>) {
            serviceOfferings.add(
              _ServiceOffering(
                majorId: majorId,
                serviceName: offering['name'] as String,
                basePrice: offering['base_price'] as num,
              ),
            );
          }
        }
      }
    });

    if (serviceOfferings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể yêu cầu: Dữ liệu dịch vụ của thợ này chưa được cập nhật.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _ServiceOffering? selectedService;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Yêu cầu dịch vụ từ ${repairer.name}",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<_ServiceOffering>(
                      decoration: const InputDecoration(
                        labelText: 'Chọn một dịch vụ',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedService,
                      items: serviceOfferings.map((offering) {
                        return DropdownMenuItem<_ServiceOffering>(
                          value: offering,
                          child: Text(offering.serviceName),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setStateSheet(() => selectedService = newValue);
                      },
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn một dịch vụ' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: selectedService == null
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _showRequestTypeDialog(
                                  repairer,
                                  selectedService!,
                                );
                              },
                        child: const Text("Tiếp tục"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRequestTypeDialog(
    UserModel repairer,
    _ServiceOffering selectedService,
  ) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chọn loại yêu cầu'),
          content: const Text(
            'Bạn muốn yêu cầu ngay bây giờ hay đặt lịch hẹn?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showLocationConfirmationDialog(repairer, selectedService);
              },
              child: const Text('Yêu cầu ngay'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showDateTimePicker(repairer, selectedService);
              },
              child: const Text('Đặt lịch hẹn'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDateTimePicker(
    UserModel repairer,
    _ServiceOffering selectedService,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (time == null || !mounted) return;

    final scheduledDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể chọn thời gian trong quá khứ.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final scheduledTimestamp = Timestamp.fromDate(scheduledDateTime);
    _showLocationConfirmationDialog(
      repairer,
      selectedService,
      scheduledAt: scheduledTimestamp,
    );
  }

  Future<void> _showLocationConfirmationDialog(
    UserModel repairer,
    _ServiceOffering selectedService, {
    Timestamp? scheduledAt,
  }) async {
    final customer = _currentUser;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin khách hàng.')),
      );
      return;
    }

    final bool useDefault = customer.defaultAddress != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận vị trí'),
          content: const Text('Bạn muốn sử dụng vị trí nào cho yêu cầu này?'),
          actions: [
            if (useDefault)
              TextButton(
                child: const Text('Vị trí đã lưu'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _createJobWithLocation(
                    customer: customer,
                    repairer: repairer,
                    selectedService: selectedService,
                    locationData: customer.defaultAddress!,
                    scheduledAt: scheduledAt,
                  );
                },
              ),
            ElevatedButton(
              child: const Text('Chọn vị trí khác'),
              onPressed: () async {
                Navigator.pop(dialogContext);

                final newLocationResult =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlacePickerScreen(),
                      ),
                    );

                if (newLocationResult != null && mounted) {
                  final latLng = newLocationResult['coordinates'] as LatLng;
                  final locationData = {
                    'address_line': newLocationResult['address'] as String,
                    'coordinates': GeoPoint(latLng.latitude, latLng.longitude),
                  };
                  _createJobWithLocation(
                    customer: customer,
                    repairer: repairer,
                    selectedService: selectedService,
                    locationData: locationData,
                    scheduledAt: scheduledAt,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showBusyRepairerWarning(UserModel repairer) async {
    if (repairer.status == RepairerStatus.busy_instant) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Thợ đang bận'),
              ],
            ),
            content: Text(
              '${repairer.name} đang làm việc. Yêu cầu của bạn có thể phải đợi. Bạn có muốn tiếp tục không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          );
        },
      );
      return result ?? false;
    }
    return true;
  }

  Future<void> _createJobWithLocation({
    required UserModel customer,
    required UserModel repairer,
    required _ServiceOffering selectedService,
    required Map<String, dynamic> locationData,
    Timestamp? scheduledAt,
  }) async {
    final shouldContinue = await _showBusyRepairerWarning(repairer);
    if (!shouldContinue || !mounted) return;

    final jobController = JobController();
    try {
      final addressLine = locationData['address_line'] as String;
      final location = locationData['coordinates'] as GeoPoint;

      final JobModel? job;
      if (scheduledAt != null) {
        // Create scheduled job
        job = await jobController.createScheduledJob(
          customer: customer,
          locksmith: repairer,
          service: selectedService.serviceName,
          location: location,
          addressLine: addressLine,
          scheduledAt: scheduledAt,
        );
      } else {
        // Create instant job
        job = await jobController.createNewJob(
          customer: customer,
          locksmith: repairer,
          service: selectedService.serviceName,
          location: location,
          addressLine: addressLine,
        );
      }

      // Check if job and job.id are not null before navigating
      if (job?.id != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job!.id!),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo yêu cầu. Vui lòng thử lại.'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo yêu cầu: $e')));
    }
  }
}
