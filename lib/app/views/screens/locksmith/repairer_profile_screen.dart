import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/auth_controller.dart';
import 'package:flutter_application_test/app/controllers/customer_controller.dart';
import 'package:flutter_application_test/data/models/user_model.dart';

import 'my_services_screen.dart'; // For managing services
import 'statistics_screen.dart'; // Import the new statistics screen
import 'repairer_contact_list_screen.dart';
import 'repairer_edit_profile_screen.dart'; // Import the new edit profile screen

class RepairerProfileScreen extends StatefulWidget {
  const RepairerProfileScreen({super.key});

  @override
  State<RepairerProfileScreen> createState() => _RepairerProfileScreenState();
}

class _RepairerProfileScreenState extends State<RepairerProfileScreen> {
  final CustomerController _repairerController = CustomerController();
  final AuthController _authController = AuthController();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // This needs to be a method that gets the current repairer's data
    final user = await _repairerController.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ Thợ'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Không thể tải dữ liệu người dùng.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildUserInfoSection(),
          const SizedBox(height: 32),
          _buildMenuList(),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue,
          backgroundImage: _currentUser?.photoUrl != null
              ? NetworkImage(_currentUser!.photoUrl!)
              : null,
          child: _currentUser?.photoUrl == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          _currentUser!.name ?? 'Chưa cập nhật tên',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currentUser!.email ?? 'Không có email',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList() {
    return Column(
      children: [
        _buildMenuListItem(
          icon: Icons.person_outline,
          title: 'Chỉnh sửa hồ sơ',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RepairerEditProfileScreen(),
              ),
            ).then((_) => _loadUserData());
          },
        ),
        _buildMenuListItem(
          icon: Icons.contacts_outlined,
          title: 'Danh bạ khách hàng',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RepairerContactListScreen(),
              ),
            );
          },
        ),
        _buildMenuListItem(
          icon: Icons.build_circle_outlined,
          title: 'Quản lý dịch vụ',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MyServicesScreen()),
            );
          },
        ),
        _buildMenuListItem(
          icon: Icons.bar_chart_outlined,
          title: 'Thống kê thu nhập',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const StatisticsScreen()),
            );
          },
        ),
        _buildMenuListItem(
          icon: Icons.settings_outlined,
          title: 'Cài đặt',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chức năng sẽ được phát triển sau.'),
              ),
            );
          },
        ),
        const Divider(height: 32),
        _buildMenuListItem(
          icon: Icons.logout,
          title: 'Đăng xuất',
          isLogout: true,
          onTap: () async {
            await _authController.signOut();
            // The AuthGate will handle navigation
          },
        ),
      ],
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final color = isLogout ? Colors.red : Colors.grey[700];
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: color, size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: isLogout ? null : Icon(Icons.chevron_right, color: color),
        onTap: onTap,
      ),
    );
  }
}
