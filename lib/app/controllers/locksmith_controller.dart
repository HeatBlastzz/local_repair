import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';

class LocksmithController {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Người dùng chưa đăng nhập.';
      }
      await _firestoreService.updateUserData(user.uid, profileData);

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
