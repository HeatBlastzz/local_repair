import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  /// Tạo một "ý định thanh toán" (Payment Intent)
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    String currency = 'vnd',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount).toInt().toString(),
          'currency': currency,
          'payment_method_types[]': 'card',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create PaymentIntent: ${response.body}');
      }
    } catch (e) {
      print('Error creating PaymentIntent: $e');
      rethrow;
    }
  }

  /// Hiển thị giao diện nhập thẻ và xác nhận thanh toán
  Future<bool> presentPaymentSheet(String clientSecret) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Fixer App',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Nếu không có lỗi, coi như thanh toán thành công
      return true;
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        // Lỗi không phải do người dùng hủy
        print('Error from Stripe: ${e.error.localizedMessage}');
      }
      return false;
    } catch (e) {
      print('Unforeseen error: $e');
      return false;
    }
  }
}
