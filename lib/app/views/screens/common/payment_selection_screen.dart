import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/services/stripe_service.dart';
import 'package:flutter_application_test/data/services/vnpay_service.dart';
import 'package:flutter_application_test/app/views/screens/common/vnpay_webview_screen.dart';

import '../../../../data/models/job_model.dart';
import '../../../../app/controllers/job_controller.dart';
import 'package:flutter_application_test/utils/logger.dart';

class PaymentSelectionScreen extends StatefulWidget {
  final JobModel job;
  const PaymentSelectionScreen({super.key, required this.job});

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  bool _isProcessing = false;

  Future<void> _handleStripePayment() async {
    setState(() => _isProcessing = true);

    final stripeService = StripeService();
    final jobController = JobController();

    try {
      final paymentIntent = await stripeService.createPaymentIntent(
        amount: widget.job.finalPrice ?? 0,
      );

      final success = await stripeService.presentPaymentSheet(
        paymentIntent['client_secret'],
      );

      if (success) {
        await jobController.confirmPayment(widget.job.id!, 'stripe');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanh toán qua Stripe thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanh toán qua Stripe đã bị hủy hoặc thất bại.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn phương thức thanh toán')),
      body: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('Thanh toán bằng Thẻ'),
                    subtitle: const Text('Sử dụng Stripe'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleStripePayment,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Thanh toán bằng VNPay'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final vnPayService = VNPayService();
                      final paymentUrl = vnPayService.createVnpayUrl(
                        amount: widget.job.finalPrice ?? 0,
                        orderInfo: 'Thanh toan cho cong viec #${widget.job.id}',
                        orderType: 'other',
                      );

                      // In URL ra để kiểm tra
                      AppLogger.payment('--- VNPay URL ---');
                      AppLogger.payment(paymentUrl);
                      AppLogger.payment('-----------------');

                      // Chờ kết quả trả về từ màn hình WebView
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VnPayWebViewScreen(
                            paymentUrl: paymentUrl,
                            jobId: widget.job.id!,
                          ),
                        ),
                      );

                      // Xử lý kết quả
                      if (result == '00') {
                        // Thanh toán thành công
                        await JobController().confirmPayment(
                          widget.job.id!,
                          'vnpay',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanh toán thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } else {
                        // Thanh toán thất bại hoặc bị hủy
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thanh toán thất bại hoặc đã bị hủy.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.money),
                    title: const Text('Thanh toán bằng tiền mặt'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Xác nhận Thanh toán'),
                            content: const Text(
                              'Bạn có chắc chắn muốn xác nhận đã thanh toán bằng tiền mặt không?',
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Hủy'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                              TextButton(
                                child: const Text('Xác nhận'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true) {
                        setState(() => _isProcessing = true);
                        try {
                          await JobController().confirmPayment(
                            widget.job.id!,
                            'cash',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã xác nhận thanh toán bằng tiền mặt!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã xảy ra lỗi: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isProcessing = false);
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
