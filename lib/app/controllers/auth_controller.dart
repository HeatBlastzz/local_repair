import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../utils/logger.dart';

class AuthController {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  /// Đăng ký người dùng với thông tin cơ bản
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
    Map<String, dynamic>? defaultAddress,
  }) async {
    try {
      User? user = await _authService.signUpWithEmailAndPassword(
        email,
        password,
      );

      if (user != null) {
        final newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phoneNumber: phoneNumber,
          role: role,
          createdAt: Timestamp.now(),
          defaultAddress: defaultAddress,
        );

        await _firestoreService.createUserRecord(newUser);
        return user;
      }
      return null;
    } catch (e) {
      AppLogger.auth("Lỗi từ AuthController khi đăng ký: $e");
      rethrow;
    }
  }

  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      return null;
    } catch (e) {
      AppLogger.auth('Lỗi từ AuthController khi đăng nhập: $e');
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final User? currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      try {
        final userModel = await _firestoreService.getUser(currentUser.uid);
        if (userModel != null && userModel.role == 'repairer') {
          await _firestoreService.updateRepairerStatus(
            currentUser.uid,
            RepairerStatus.offline,
          );
        }
      } catch (e) {
        AppLogger.auth("Lỗi khi cập nhật trạng thái offline lúc đăng xuất: $e");
      }
    }
    await _authService.signOut();
  }
}
