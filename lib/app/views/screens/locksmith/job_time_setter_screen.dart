import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/status_manager.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:flutter_application_test/data/models/work_session_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';
import 'package:intl/intl.dart';

class JobTimeSetterScreen extends StatefulWidget {
  final JobModel job;
  final VoidCallback? onTimeSet;

  const JobTimeSetterScreen({super.key, required this.job, this.onTimeSet});

  @override
  State<JobTimeSetterScreen> createState() => _JobTimeSetterScreenState();
}

class _JobTimeSetterScreenState extends State<JobTimeSetterScreen> {
  final StatusManager _statusManager = StatusManager();
  final FirestoreService _firestoreService = FirestoreService();

  DateTime _selectedEndTime = DateTime.now().add(const Duration(hours: 2));
  Duration _estimatedDuration = const Duration(hours: 2);
  bool _isLoading = false;
  bool _isWorkSessionMode = false;
  WorkSessionModel? _currentWorkSession;

  final List<Duration> _commonDurations = [
    const Duration(minutes: 30),
    const Duration(hours: 1),
    const Duration(hours: 2),
    const Duration(hours: 3),
    const Duration(hours: 4),
    const Duration(hours: 6),
    const Duration(hours: 8),
  ];

  @override
  void initState() {
    super.initState();
    // Tính toán thời gian kết thúc dự kiến ban đầu
    final startTime = widget.job.scheduledAt?.toDate() ?? DateTime.now();
    _selectedEndTime = startTime.add(_estimatedDuration);
    _checkForActiveWorkSession();
  }

  Future<void> _checkForActiveWorkSession() async {
    try {
      // Kiểm tra xem có phiên làm việc đang diễn ra không
      final workSessions = await _firestoreService.getWorkSessionsForJob(
        widget.job.id!,
      );
      final activeSession = workSessions
          .where(
            (session) =>
                session.status == 'in_progress' ||
                session.status == 'scheduled',
          )
          .firstOrNull;

      if (mounted && activeSession != null) {
        setState(() {
          _currentWorkSession = activeSession;
          _isWorkSessionMode = true;
          // Nếu có estimatedEndTime, sử dụng nó
          if (activeSession.estimatedEndTime != null) {
            _selectedEndTime = activeSession.estimatedEndTime!.toDate();
            _estimatedDuration = _selectedEndTime.difference(
              activeSession.startTime.toDate(),
            );
          }
        });
      }
    } catch (e) {
      AppLogger.firestore('Lỗi kiểm tra phiên làm việc: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isWorkSessionMode
              ? 'Cập nhật thời gian phiên làm việc'
              : 'Đặt thời gian kết thúc',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJobInfo(),
            const SizedBox(height: 24),
            if (_isWorkSessionMode) _buildWorkSessionInfo(),
            const SizedBox(height: 24),
            _buildDurationSelector(),
            const SizedBox(height: 24),
            _buildTimeSelector(),
            const SizedBox(height: 24),
            _buildSummary(),
            const Spacer(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobInfo() {
    final startTime = widget.job.scheduledAt?.toDate() ?? DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin công việc',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Khách hàng:', widget.job.customerName),
            _buildInfoRow('Dịch vụ:', widget.job.service),
            _buildInfoRow('Địa chỉ:', widget.job.addressLine),
            _buildInfoRow(
              'Thời gian bắt đầu:',
              DateFormat('dd/MM/yyyy HH:mm').format(startTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkSessionInfo() {
    if (_currentWorkSession == null) return const SizedBox.shrink();

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Phiên làm việc #${_currentWorkSession!.sessionNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mô tả: ${_currentWorkSession!.description}'),
            Text('Trạng thái: ${_getStatusText(_currentWorkSession!.status)}'),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Đã lên lịch';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thời gian dự kiến thực hiện:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonDurations.map((duration) {
            final isSelected = _estimatedDuration == duration;
            return FilterChip(
              label: Text(_formatDuration(duration)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _estimatedDuration = duration;
                    final startTime =
                        widget.job.scheduledAt?.toDate() ?? DateTime.now();
                    _selectedEndTime = startTime.add(duration);
                  });
                }
              },
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thời gian kết thúc:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(_selectedEndTime),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: _selectEndTime,
                child: const Text('Thay đổi'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final startTime = widget.job.scheduledAt?.toDate() ?? DateTime.now();
    final actualDuration = _selectedEndTime.difference(startTime);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tóm tắt',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tổng thời gian: ${_formatDuration(actualDuration)}'),
            Text('Từ: ${DateFormat('HH:mm dd/MM').format(startTime)}'),
            Text('Đến: ${DateFormat('HH:mm dd/MM').format(_selectedEndTime)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _setJobEndTime,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Text('Xác nhận'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectEndTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedEndTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedEndTime),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedEndTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          // Cập nhật estimated duration
          final startTime = widget.job.scheduledAt?.toDate() ?? DateTime.now();
          _estimatedDuration = _selectedEndTime.difference(startTime);
        });
      }
    }
  }

  Future<void> _setJobEndTime() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isWorkSessionMode && _currentWorkSession != null) {
        // Cập nhật thời gian kết thúc dự kiến cho phiên làm việc
        await _firestoreService.updateWorkSessionEstimatedEndTime(
          widget.job.id!,
          _currentWorkSession!.id!,
          _selectedEndTime,
        );

        if (mounted) {
          Navigator.pop(context);
          widget.onTimeSet?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã cập nhật thời gian kết thúc dự kiến cho phiên làm việc',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Cập nhật thời gian kết thúc cho job (logic cũ)
        await _statusManager.setScheduledJobEndTime(
          widget.job.id!,
          _selectedEndTime,
          widget.job.locksmithId,
        );

        if (mounted) {
          Navigator.pop(context);
          widget.onTimeSet?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã đặt thời gian kết thúc và chuyển sang trạng thái bận',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours == 0) {
      return '${minutes}p';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}p';
    }
  }
}
