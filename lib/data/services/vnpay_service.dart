import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class VNPayService {
  String createVnpayUrl({
    required double amount,
    required String orderInfo,
    required String orderType,
    String? bankCode,
  }) {
    final vnpParams = <String, String>{};

    // Tạo mã giao dịch duy nhất
    final txnRef = 'JOB${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}';

    vnpParams['vnp_Version'] = '2.1.0';
    vnpParams['vnp_Command'] = 'pay';
    vnpParams['vnp_TmnCode'] = _vnpTmnCode;
    vnpParams['vnp_Amount'] = (amount * 100).toInt().toString();
    vnpParams['vnp_CurrCode'] = 'VND';
    vnpParams['vnp_TxnRef'] = txnRef;
    vnpParams['vnp_OrderInfo'] = 'Thanh toan don hang $txnRef';
    vnpParams['vnp_OrderType'] = orderType;
    vnpParams['vnp_ReturnUrl'] = vnpReturnUrl;
    vnpParams['vnp_IpAddr'] = '127.0.0.1';
    vnpParams['vnp_Locale'] = 'vn';
    vnpParams['vnp_CreateDate'] = DateFormat(
      'yyyyMMddHHmmss',
    ).format(DateTime.now());

    if (bankCode != null && bankCode.isNotEmpty) {
      vnpParams['vnp_BankCode'] = bankCode;
    }

    final sortedParams = vnpParams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // ✅ Sử dụng Uri.encodeComponent để mã hóa giá trị tham số đúng chuẩn
    final hashData = sortedParams
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final hmacSha512 = Hmac(sha512, utf8.encode(_vnpHashSecret));
    final digest = hmacSha512.convert(utf8.encode(hashData));
    final secureHash = hex.encode(digest.bytes);

    // Thêm chữ ký vào tham số cuối cùng
    final queryString = sortedParams
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final paymentUrl = '$_vnpUrl?$queryString&vnp_SecureHash=$secureHash';

    return paymentUrl;
  }
}
