import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_test/data/models/message_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';
import 'package:flutter_application_test/data/models/job_model.dart';

class ChatController {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Gửi tin nhắn
  Future<void> sendMessage(String jobId, String text, String receiverId) async {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      // Người dùng chưa đăng nhập, không thể gửi tin nhắn
      AppLogger.auth("Lỗi: Người dùng chưa đăng nhập.");
      return;
    }

    if (text.trim().isEmpty) {
      return;
    }

    final Timestamp timestamp = Timestamp.now();

    MessageModel newMessage = MessageModel(
      senderId: currentUserId,
      receiverId: receiverId,
      text: text.trim(),
      timestamp: timestamp,
    );

    try {
      await _firestoreService.sendMessage(jobId, newMessage);
    } catch (e) {
      AppLogger.firestore("Lỗi khi gửi tin nhắn từ controller: $e");
      // Có thể hiển thị thông báo lỗi cho người dùng ở đây
    }
  }

  // Lấy stream danh sách các cuộc trò chuyện
  Stream<List<JobModel>> getChatListStream(String userId, String userRole) {
    return _firestoreService.getChatList(userId, userRole);
  }

  Future<void> hideChat(String jobId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestoreService.hideChatForUser(jobId, userId);
    } catch (e) {
      AppLogger.firestore('Error in ChatController hiding chat: $e');
    }
  }
}
