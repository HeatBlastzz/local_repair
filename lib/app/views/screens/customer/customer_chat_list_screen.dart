import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/chat_controller.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:intl/intl.dart';

import '../common/chat_screen.dart';

class CustomerChatListScreen extends StatefulWidget {
  const CustomerChatListScreen({super.key});

  @override
  State<CustomerChatListScreen> createState() => _CustomerChatListScreenState();
}

class _CustomerChatListScreenState extends State<CustomerChatListScreen> {
  final ChatController _chatController = ChatController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final User _currentUser;
  final String _currentUserRole = 'customer';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
  }

  // Helper widget to build each chat item using a FutureBuilder to get locksmith details
  Widget _buildChatItem(JobModel job) {
    return FutureBuilder<UserModel?>(
      future: _firestoreService.getUser(job.locksmithId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(),
            title: Text("Đang tải..."),
            subtitle: Text("..."),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.error)),
            title: Text("Không tìm thấy thông tin thợ"),
          );
        }

        final locksmith = snapshot.data!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                locksmith.name?.substring(0, 1).toUpperCase() ?? 'T',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              locksmith.name ?? 'Thợ sửa chữa',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Yêu cầu tạo lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt.toDate())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            trailing: job.lastMessageTimestamp != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat(
                          'HH:mm',
                        ).format(job.lastMessageTimestamp!.toDate()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      // Có thể thêm icon báo tin nhắn mới ở đây nếu cần
                    ],
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    jobId: job.id!,
                    receiverId: locksmith.uid,
                    chatPartnerName: locksmith.name ?? 'Thợ sửa chữa',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<List<JobModel>>(
        stream: _chatController.getChatListStream(
          _currentUser.uid,
          _currentUserRole,
        ),
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
                    'Đang tải tin nhắn...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn chưa có cuộc trò chuyện nào.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tin nhắn sẽ xuất hiện khi có yêu cầu từ thợ sửa chữa',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final chatList = snapshot.data!;

          return ListView.separated(
            itemCount: chatList.length,
            itemBuilder: (context, index) {
              final job = chatList[index];
              return Dismissible(
                key: Key(job.id!),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _chatController.hideChat(job.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Đã xoá cuộc trò chuyện với ${job.locksmithName}',
                      ),
                    ),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: _buildChatItem(job),
              );
            },
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 80),
          );
        },
      ),
    );
  }
}
