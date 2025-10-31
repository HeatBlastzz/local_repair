import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/repairer_contact_controller.dart';
import 'package:flutter_application_test/data/models/repairer_contact_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/chat_screen.dart';

class RepairerContactListScreen extends StatelessWidget {
  const RepairerContactListScreen({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _navigateToChat(BuildContext context, RepairerContactModel contact) async {
    final firestoreService = FirestoreService();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final job = await firestoreService.getMostRecentJob(
        contact.customerId, currentUser.uid);

    if (job != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            jobId: job.id!,
            receiverId: contact.customerId,
            chatPartnerName: contact.customerName,
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy cuộc trò chuyện nào.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RepairerContactController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Danh bạ Khách hàng'),
        ),
        body: Consumer<RepairerContactController>(
          builder: (context, controller, child) {
            return StreamBuilder<List<RepairerContactModel>>(
              stream: controller.getContactsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Đã xảy ra lỗi khi tải danh bạ.'));
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
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(contact.customerName.isNotEmpty ? contact.customerName[0] : '?'),
                        ),
                        title: Text(contact.customerName),
                        subtitle: Text(contact.customerPhone),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () {
                                if (contact.customerPhone != 'Không có SĐT') {
                                  _makePhoneCall(contact.customerPhone);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Khách hàng này không có số điện thoại.')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.message, color: Theme.of(context).primaryColor),
                              onPressed: () => _navigateToChat(context, contact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Xác nhận xóa'),
                                    content: Text('Bạn có chắc muốn xóa "${contact.customerName}" khỏi danh bạ?'),
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
                                );
                                if (confirm == true) {
                                  await controller.deleteContact(contact.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã xóa liên hệ.')),
                                    );
                                  }
                                }
                              },
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
}
