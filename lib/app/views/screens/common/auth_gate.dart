import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/customer/main_screen.dart';

import 'package:flutter_application_test/app/views/screens/locksmith/profile_setup_screen.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/repairer_main_screen.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firestore_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return RoleBasedRedirect(uid: snapshot.data!.uid);
        }

        return const LoginScreen();
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  final String uid;
  const RoleBasedRedirect({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return FutureBuilder<UserModel?>(
      future: firestoreService.getUser(uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (userSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Lỗi kết nối dữ liệu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Chi tiết: ${userSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Đăng xuất và thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!userSnapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Không tìm thấy thông tin người dùng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng liên hệ admin để được hỗ trợ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          );
        }

        final userModel = userSnapshot.data!;
        if (userModel.role == 'customer') {
          return const MainScreen();
        } else if (userModel.role == 'repairer') {
          if (userModel.majors == null || userModel.majors!.isEmpty) {
            return const ProfileSetupScreen();
          }
          return const RepairerMainScreen();
        } else {
          return const RepairerMainScreen();
        }
      },
    );
  }
}
