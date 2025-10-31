import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/services/vnpay_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VnPayWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String jobId;

  const VnPayWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.jobId,
  });

  @override
  State<VnPayWebViewScreen> createState() => _VnPayWebViewScreenState();
}

class _VnPayWebViewScreenState extends State<VnPayWebViewScreen> {
  late final WebViewController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(VNPayService.vnpReturnUrl)) {
              _handleVnpayReturn(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handleVnpayReturn(String url) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final uri = Uri.parse(url);
    final vnpResponseCode = uri.queryParameters['vnp_ResponseCode'];

    // Đóng WebView và trả về kết quả
    Navigator.of(context).pop(vnpResponseCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán VNPay')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}
