import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/chat_controller.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_test/app/controllers/contact_controller.dart';
import 'package:flutter_application_test/app/controllers/repairer_contact_controller.dart';
import 'package:flutter_application_test/data/models/contact_model.dart';
import 'package:flutter_application_test/data/models/repairer_contact_model.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/utils/logger.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;
  final String receiverId;
  final String chatPartnerName;

  const ChatScreen({
    super.key,
    required this.jobId,
    required this.receiverId,
    required this.chatPartnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatController _chatController = ChatController();
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    // In ra Job ID để kiểm tra
    AppLogger.debug(
      '[ChatScreen Debug] Loading chat for Job ID: ${widget.jobId}',
    );
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userModel = await _firestoreService.getUser(_currentUserId);
    if (mounted) {
      setState(() {
        _currentUser = userModel;
      });
    }
  }

  void _sendMessage() {
    _chatController.sendMessage(
      widget.jobId,
      _messageController.text,
      widget.receiverId,
    );
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    bool isCustomer = _currentUser?.role == 'customer';
    bool isRepairer = _currentUser?.role == 'repairer';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContactController()),
        ChangeNotifierProvider(create: (_) => RepairerContactController()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chatPartnerName),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            if (isCustomer)
              Consumer<ContactController>(
                builder: (context, contactController, child) {
                  return IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    tooltip: 'Lưu vào danh bạ',
                    onPressed: () async {
                      final locksmithUser = await _firestoreService.getUser(
                        widget.receiverId,
                      );
                      if (locksmithUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không tìm thấy thông tin thợ!'),
                          ),
                        );
                        return;
                      }

                      final newContact = Contact(
                        id: '',
                        customerId: _currentUserId,
                        locksmithId: locksmithUser.uid,
                        locksmithName: locksmithUser.name ?? 'Không có tên',
                        locksmithPhone:
                            locksmithUser.phoneNumber ?? 'Không có SĐT',
                        locksmithAddress:
                            locksmithUser.defaultAddress?['address_line'] ??
                            'Không có địa chỉ',
                      );

                      final result = await contactController.addContact(
                        newContact,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result ?? 'Đã lưu thợ vào danh bạ!'),
                            backgroundColor: result == null
                                ? Colors.green
                                : Colors.orange,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            if (isRepairer)
              Consumer<RepairerContactController>(
                builder: (context, contactController, child) {
                  return IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    tooltip: 'Lưu khách hàng',
                    onPressed: () async {
                      final customerUser = await _firestoreService.getUser(
                        widget.receiverId,
                      );
                      if (customerUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Không tìm thấy thông tin khách hàng!',
                            ),
                          ),
                        );
                        return;
                      }

                      final newContact = RepairerContactModel(
                        id: '',
                        repairerId: _currentUserId,
                        customerId: customerUser.uid,
                        customerName: customerUser.name ?? 'Không có tên',
                        customerPhone:
                            customerUser.phoneNumber ?? 'Không có SĐT',
                        customerAddress:
                            customerUser.defaultAddress?['address_line'] ??
                            'Không có địa chỉ',
                      );

                      final result = await contactController.addContact(
                        newContact,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result ?? 'Đã lưu khách hàng vào danh bạ!',
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
              ),
          ],
        ),
        body: Column(
          children: [
            // Phần hiển thị tin nhắn
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getChatMessagesStream(widget.jobId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Đã có lỗi xảy ra."));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
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
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            'Chưa có tin nhắn nào.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bắt đầu cuộc trò chuyện với ${widget.chatPartnerName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    reverse: true,
                    children: snapshot.data!.docs
                        .map((doc) => _buildMessageItem(doc))
                        .toList(),
                  );
                },
              ),
            ),
            // Phần nhập tin nhắn
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isSender = data['senderId'] == _currentUserId;

    return Container(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        crossAxisAlignment: isSender
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isSender ? Colors.blue : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data['text'],
              style: TextStyle(color: isSender ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Nhập tin nhắn...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
