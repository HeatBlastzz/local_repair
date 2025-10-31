import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/common/job_details_screen.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:intl/intl.dart';

class CompletedJobsListScreen extends StatelessWidget {
  final List<JobModel> completedJobs;

  const CompletedJobsListScreen({super.key, required this.completedJobs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Việc Đã Hoàn Thành'),
        centerTitle: true,
      ),
      body: completedJobs.isEmpty
          ? const Center(
              child: Text('Không có công việc nào trong khoảng thời gian này.'),
            )
          : ListView.builder(
              itemCount: completedJobs.length,
              itemBuilder: (context, index) {
                final job = completedJobs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      job.service,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Khách hàng: ${job.customerName}'),
                        const SizedBox(height: 4),
                        Text(
                          'Hoàn thành: ${job.paymentTimestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(job.paymentTimestamp!.toDate()) : 'N/A'}',
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => JobDetailsScreen(jobId: job.id!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
} 