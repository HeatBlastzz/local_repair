import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';

class CustomerController {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Lấy thông tin người dùng hiện tại
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await _firestoreService.getUser(user.uid);
    }
    return null;
  }

  /// Cập nhật thông tin người dùng
  Future<String?> updateUserProfile({
    required String name,
    required String phoneNumber,
    Timestamp? dateOfBirth,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Người dùng chưa đăng nhập.';
    }

    try {
      final Map<String, dynamic> dataToUpdate = {
        'name': name,
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth,
      };

      await _firestoreService.updateUserData(user.uid, dataToUpdate);
      return null; // Trả về null nếu thành công
    } catch (e) {
      return e.toString();
    }
  }
}
