import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/services/service_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_test/app/controllers/locksmith_controller.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/repairer_main_screen.dart';
import 'package:flutter_application_test/data/models/user_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ServiceOfferingController {
  final TextEditingController nameController;
  final TextEditingController priceController;

  ServiceOfferingController()
    : nameController = TextEditingController(),
      priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;

  UserModel? _currentUser;

  // State cho chuyên ngành và dịch vụ (Bước 1 & 2)
  final Set<String> _selectedMajors = {};
  final Map<String, List<ServiceOfferingController>> _serviceControllers = {};

  final LocksmithController _locksmithController = LocksmithController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userModel = await _firestoreService.getUser(
        user.uid,
      ); // Sử dụng trực tiếp
      if (mounted) {
        setState(() {
          _currentUser = userModel;
        });
      }
    }
  }

  @override
  void dispose() {
    // không còn name và phone controller để dispose
    _serviceControllers.values.forEach((controllers) {
      for (var controller in controllers) {
        controller.dispose();
      }
    });
    super.dispose();
  }

  List<Step> get _steps => [
    Step(
      title: Text(
        'Thông tin',
        style: TextStyle(
          color: _currentStep >= 0
              ? Colors.lightBlue.shade600
              : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 0,
      content: _buildStep1(),
    ),
    Step(
      title: Text(
        'Dịch vụ',
        style: TextStyle(
          color: _currentStep >= 1
              ? Colors.lightBlue.shade600
              : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 1,
      content: _buildStep2(),
    ),
  ];

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn chuyên ngành của bạn:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        ...serviceDefinitions.map((service) {
          return CheckboxListTile(
            title: Text(
              service.name,
              style: TextStyle(color: Colors.grey[700]),
            ),
            value: _selectedMajors.contains(service.id),
            activeColor: Colors.lightBlue.shade600,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedMajors.add(service.id);
                  _serviceControllers[service.id] = [
                    ServiceOfferingController(),
                  ];
                } else {
                  _selectedMajors.remove(service.id);
                  _serviceControllers.remove(service.id);
                }
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStep2() {
    if (_selectedMajors.isEmpty) {
      return Center(
        child: Text(
          'Vui lòng quay lại Bước 1 và chọn ít nhất một chuyên ngành.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    for (var majorId in _selectedMajors) {
      _serviceControllers.putIfAbsent(majorId, () => []);
    }

    return SingleChildScrollView(
      child: Column(
        children: _selectedMajors.map((majorId) {
          final serviceDef = serviceDefinitions.firstWhere(
            (s) => s.id == majorId,
          );
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceDef.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._serviceControllers[majorId]!.asMap().entries.map((entry) {
                    int idx = entry.key;
                    ServiceOfferingController controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller.nameController,
                              decoration: InputDecoration(
                                labelText: 'Tên dịch vụ ${idx + 1}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: controller.priceController,
                              decoration: InputDecoration(
                                labelText: 'Giá (VND)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[600]),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          if (_serviceControllers[majorId]!.length > 1)
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red[400],
                              ),
                              onPressed: () => setState(
                                () =>
                                    _serviceControllers[majorId]!.removeAt(idx),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(Icons.add, color: Colors.lightBlue.shade600),
                      label: Text(
                        'Thêm dịch vụ',
                        style: TextStyle(
                          color: Colors.lightBlue.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => setState(
                        () => _serviceControllers[majorId]!.add(
                          ServiceOfferingController(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onStepContinue() {
    bool isStepValid = false;
    if (_currentStep == 0) {
      if (_selectedMajors.isNotEmpty) {
        isStepValid = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất một chuyên ngành.'),
          ),
        );
      }
    }

    if (isStepValid && _currentStep < _steps.length - 1) {
      setState(() => _currentStep += 1);
    }
  }

  void _submitProfile() async {
    if (_selectedMajors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một chuyên ngành.'),
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }
    if (_isServiceStepEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm dịch vụ ở Bước 2.')),
      );
      setState(() => _currentStep = 1);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> serviceDetails = {};
      for (var majorId in _selectedMajors) {
        final serviceDef = serviceDefinitions.firstWhere(
          (s) => s.id == majorId,
        );
        final offerings = _serviceControllers[majorId]
            ?.map(
              (c) => {
                'name': c.nameController.text.trim(),
                'base_price': num.tryParse(c.priceController.text.trim()) ?? 0,
              },
            )
            .where((o) => (o['name'] as String).isNotEmpty)
            .toList();

        if (offerings != null && offerings.isNotEmpty) {
          serviceDetails[majorId] = {
            'name': serviceDef.name,
            'offerings': offerings,
          };
        }
      }

      final defaultAddress = _currentUser?.defaultAddress;

      final Map<String, dynamic> profileData = {
        'role': 'repairer',
        'name': _currentUser!.name,
        'phoneNumber': _currentUser!.phoneNumber,
        'majors': _selectedMajors.toList(),
        'services': serviceDetails,

        if (defaultAddress != null) 'defaultAddress': defaultAddress,
        'createdAt': FieldValue.serverTimestamp(),
        'averageRating': 0.0,
        'ratingCount': 0,
      };

      final result = await _locksmithController.updateProfile(profileData);

      if (result == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const RepairerMainScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $result')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi không mong muốn: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _isServiceStepEmpty() {
    if (_selectedMajors.isEmpty) return true;

    for (var majorId in _selectedMajors) {
      final services = _serviceControllers[majorId];
      if (services == null || services.isEmpty) {
        return true;
      }

      if (services.every((s) => s.nameController.text.trim().isEmpty)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết Lập Hồ Sơ'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.lightBlue.shade600,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        onStepTapped: (step) => setState(() => _currentStep = step),
        steps: _steps,
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == _steps.length - 1;
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                if (!isLastStep)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue.shade400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Tiếp tục',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (_isSubmitting)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue.shade400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Hoàn tất',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                if (_currentStep > 0 && !_isSubmitting)
                  TextButton(
                    onPressed: details.onStepCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      'Quay lại',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
