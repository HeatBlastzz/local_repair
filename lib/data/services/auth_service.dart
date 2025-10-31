import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Đăng ký người dùng mới bằng email và mật khẩu
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Dựa vào mã lỗi của Firebase, ném ra một thông báo lỗi tường minh
      if (e.code == 'weak-password') {
        throw 'Mật khẩu quá yếu. Vui lòng sử dụng ít nhất 6 ký tự.';
      } else if (e.code == 'email-already-in-use') {
        throw 'Địa chỉ email này đã được sử dụng bởi một tài khoản khác.';
      } else if (e.code == 'invalid-email') {
        throw 'Địa chỉ email không hợp lệ.';
      }
      // Lỗi chung cho các trường hợp khác
      throw 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }

  /// Đăng nhập người dùng bằng email và mật khẩu
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Dựa vào mã lỗi của Firebase, ném ra một thông báo lỗi tường minh
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw 'Email hoặc mật khẩu không chính xác.';
      } else if (e.code == 'invalid-email') {
        throw 'Địa chỉ email không hợp lệ.';
      } else {
        // Lỗi chung cho các trường hợp khác
        throw 'Đã xảy ra lỗi, vui lòng thử lại.';
      }
    }
  }

  /// Đăng xuất người dùng hiện tại
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Lấy người dùng hiện tại
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }
}
