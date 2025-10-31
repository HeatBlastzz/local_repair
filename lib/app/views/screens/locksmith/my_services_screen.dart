import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:intl/intl.dart';

import 'profile_setup_screen.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final currencyFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VND',
  );

  Future<void> _deleteService(
    UserModel locksmith,
    String majorId,
    Map<String, dynamic> serviceToDelete,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận Xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa dịch vụ "${serviceToDelete['name']}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Tạo một bản sao sâu của map services để sửa đổi
        final updatedServices = Map<String, dynamic>.from(locksmith.services);
        final majorData = Map<String, dynamic>.from(
          updatedServices[majorId] ?? {},
        );
        final offerings = List<Map<String, dynamic>>.from(
          majorData['offerings'] ?? [],
        );

        // Xóa dịch vụ khỏi danh sách offerings
        offerings.removeWhere((s) => s['name'] == serviceToDelete['name']);

        // Nếu chuyên ngành không còn dịch vụ nào, hãy xóa luôn chuyên ngành đó
        if (offerings.isEmpty) {
          updatedServices.remove(majorId);
        } else {
          majorData['offerings'] = offerings;
          updatedServices[majorId] = majorData;
        }

        // Gọi FirestoreService để cập nhật
        await _firestoreService.updateLocksmithServices(
          _currentUserId,
          updatedServices,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa dịch vụ thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          // Tải lại giao diện
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa dịch vụ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch vụ của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa dịch vụ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileSetupScreen(),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: _firestoreService.getUser(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Không thể tải dữ liệu.'));
          }

          final locksmith = snapshot.data!;
          // Lấy ra map services từ cấu trúc mới
          final servicesByMajor = locksmith.services;

          if (servicesByMajor.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bạn chưa có dịch vụ nào.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileSetupScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    child: const Text('Thêm dịch vụ ngay'),
                  ),
                ],
              ),
            );
          }

          final majorIds = servicesByMajor.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: majorIds.length,
            itemBuilder: (context, index) {
              final majorId = majorIds[index];
              final majorData =
                  servicesByMajor[majorId] as Map<String, dynamic>;
              final majorName = majorData['name'] ?? 'Chuyên ngành không tên';
              final offerings =
                  (majorData['offerings'] as List<dynamic>?) ?? [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  title: Text(
                    majorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  children: offerings.map((offering) {
                    final offeringData = offering as Map<String, dynamic>;
                    final serviceName =
                        offeringData['name'] ?? 'Dịch vụ không tên';
                    final basePrice = offeringData['base_price'] ?? 0;

                    return ListTile(
                      title: Text(serviceName),
                      subtitle: Text(currencyFormatter.format(basePrice)),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[400],
                        ),
                        onPressed: () =>
                            _deleteService(locksmith, majorId, offeringData),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
