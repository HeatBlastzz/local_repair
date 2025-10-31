import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/profile_setup_screen.dart';
import '../../../controllers/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'place_picker_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/app/views/screens/customer/main_screen.dart';

enum UserRole { customer, repairer }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = AuthController();

  // State mới cho địa chỉ
  LatLng? _addressCoordinates;
  String? _addressText;

  UserRole _selectedRole = UserRole.customer;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Kiểm tra đã chọn địa chỉ chưa
    if (_addressCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn địa chỉ mặc định của bạn.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final User? user = await _authController.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole.name,
        // Gửi thêm thông tin địa chỉ
        defaultAddress: {
          'address_line': _addressText,
          'coordinates': GeoPoint(
            _addressCoordinates!.latitude,
            _addressCoordinates!.longitude,
          ),
        },
      );

      if (mounted) Navigator.pop(context);

      if (user != null && mounted) {
        if (_selectedRole == UserRole.repairer) {
          // Điều hướng đến màn hình thiết lập hồ sơ
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        } else {
          // Chủ động điều hướng customer đến màn hình chính
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address =
            '${place.name}, ${place.street}, ${place.subAdministrativeArea}, ${place.administrativeArea}';
        if (mounted) {
          setState(() {
            _addressCoordinates = LatLng(position.latitude, position.longitude);
            _addressText = address;
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lấy vị trí tự động. Vui lòng chọn trên bản đồ.',
            ),
          ),
        );
        _pickLocationFromMap();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã xảy ra lỗi: $e')));
    }
  }

  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const PlacePickerScreen()),
    );

    if (result != null && result.containsKey('address')) {
      if (mounted) {
        setState(() {
          _addressCoordinates = result['coordinates'];
          _addressText = result['address'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Ký Tài Khoản'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Tạo Tài Khoản Mới!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng điền thông tin để tạo tài khoản mới.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // Ô nhập liệu cho Họ và tên
              const Text(
                'Họ và tên',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Họ và tên',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Ô nhập liệu cho Số điện thoại
              const Text(
                'Số điện thoại',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Số điện thoại',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số điện thoại.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Ô nhập liệu cho Email
              const Text(
                'Email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Vui lòng nhập một email hợp lệ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Ô nhập liệu cho Mật khẩu
              const Text(
                'Mật khẩu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              Text(
                'Địa chỉ mặc định của bạn:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),

              if (_addressText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _addressText!,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Chưa chọn địa chỉ',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500],
                    ),
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Hiện tại'),
                      onPressed: _getCurrentLocation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Bản đồ'),
                      onPressed: _pickLocationFromMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Text(
                'Bạn là:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              RadioListTile<UserRole>(
                title: Text(
                  'Khách hàng',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                value: UserRole.customer,
                groupValue: _selectedRole,
                activeColor: Colors.lightBlue.shade600,
                onChanged: (UserRole? value) {
                  setState(() => _selectedRole = value!);
                },
              ),
              RadioListTile<UserRole>(
                title: Text(
                  'Thợ sửa chữa',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                value: UserRole.repairer,
                groupValue: _selectedRole,
                activeColor: Colors.lightBlue.shade600,
                onChanged: (UserRole? value) {
                  setState(() => _selectedRole = value!);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text(
                    'Đăng Ký',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
