import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/payment_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';

class RazorpayService {
  late Razorpay _razorpay;
  final PaymentRepository _paymentRepository;
  final OrderRepository _orderRepository;

  // Razorpay TEST API credentials
  static const String _keyId = 'rzp_test_SMMO0Ad99u0YG3';
  static const String _keySecret = 'sj0dYkSnLzSCcOu2TMG62vc4';

  // Callback functions
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;

  RazorpayService(this._paymentRepository, this._orderRepository) {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Callback for payment success with order creation
  Function(String paymentTransactionId, String razorpayPaymentId)?
  _onOrderCreation;
  Function(String error)? _onPaymentFailed;

  /// Create a Razorpay order and initiate payment with callbacks for payment-first flow
  Future<RazorpayPaymentResult> processPaymentWithCallback({
    required String userId,
    required String vendorId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required Map<String, dynamic> metadata,
    required Future<void> Function(
      String paymentTransactionId,
      String razorpayPaymentId,
    )
    onPaymentSuccess,
    required void Function(String error) onPaymentFailure,
  }) async {
    try {
      // Store callbacks for later use
      _onOrderCreation = onPaymentSuccess;
      _onPaymentFailed = onPaymentFailure;

      // Create payment transaction record WITHOUT order/booking ID (payment-first approach)
      final paymentTransaction = await _paymentRepository.createPaymentTransaction(
        userId: userId,
        vendorId: vendorId,
        paymentMethod: 'razorpay',
        amount: amount,
        metadata: metadata,
      );

      // Create Razorpay order
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final receiptId = 'P_$timestamp'; // P for Payment-first

      final razorpayOrderId = await _createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          'user_id': userId,
          'vendor_id': vendorId,
          'payment_transaction_id': paymentTransaction.id,
          'payment_first': 'true',
        },
      );

      if (razorpayOrderId == null) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to create Razorpay order',
        );
        _onPaymentFailed?.call('Failed to create payment order');
        return RazorpayPaymentResult.error('Failed to create payment order');
      }

      // Update payment transaction with order ID
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransaction.id,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      // Configure payment options
      final options = {
        'key': _keyId,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'order_id': razorpayOrderId,
        'name': 'Sylonow',
        'description': 'Booking Payment (60%)',
        'timeout': 300,
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName,
        },
        'theme': {'color': '#FF0080'},
        'notes': {
          'payment_type': 'razorpay_60_percent',
          'payment_transaction_id': paymentTransaction.id,
          'payment_first': 'true',
        },
      };

      _setupPaymentCallbacksWithOrderCreation(paymentTransaction.id);

      // Small delay to reduce race between DB update and checkout launch
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        _razorpay.open(options);
      } catch (e) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to open Razorpay: $e',
        );
        _onPaymentFailed?.call('Failed to open payment gateway: $e');
        throw Exception('Failed to open Razorpay checkout: $e');
      }

      return RazorpayPaymentResult.processing(
        paymentTransaction.id,
        razorpayOrderId,
      );
    } catch (e) {
      _onPaymentFailed?.call('Failed to process payment: ${e.toString()}');
      return RazorpayPaymentResult.error(
        'Failed to process payment: ${e.toString()}',
      );
    }
  }

  /// Create a Razorpay order and initiate payment
  Future<RazorpayPaymentResult> processPayment({
    String? bookingId,
    String? orderId,
    required String userId,
    required String vendorId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      if (bookingId == null && orderId == null) {
        return RazorpayPaymentResult.error(
          'Either bookingId or orderId must be provided',
        );
      }

      final paymentTransaction = await _paymentRepository.createPaymentTransaction(
        bookingId: bookingId,
        orderId: orderId,
        userId: userId,
        vendorId: vendorId,
        paymentMethod: 'razorpay',
        amount: amount,
        metadata: metadata,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final receiptId = '${bookingId != null ? 'B' : 'O'}_$timestamp';

      final razorpayOrderId = await _createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          if (bookingId != null) 'booking_id': bookingId,
          if (orderId != null) 'order_id': orderId,
          'user_id': userId,
          'vendor_id': vendorId,
          'payment_transaction_id': paymentTransaction.id,
        },
      );

      if (razorpayOrderId == null) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransaction.id,
          status: 'failed',
          failureReason: 'Failed to create Razorpay order',
        );
        return RazorpayPaymentResult.error('Failed to create payment order');
      }

      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransaction.id,
        status: 'processing',
        processedAt: DateTime.now(),
      );

      final options = {
        'key': _keyId,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'order_id': razorpayOrderId,
        'name': 'Sylonow',
        'description': 'Booking Payment (60%)',
        'timeout': 300,
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName,
        },
        'theme': {'color': '#FF0080'},
        'notes': {
          if (bookingId != null) 'booking_id': bookingId,
          if (orderId != null) 'order_id': orderId,
          'payment_type': 'razorpay_60_percent',
          'payment_transaction_id': paymentTransaction.id,
        },
      };

      _setupPaymentCallbacks(paymentTransaction.id);
      _razorpay.open(options);

      return RazorpayPaymentResult.processing(
        paymentTransaction.id,
        razorpayOrderId,
      );
    } catch (e) {
      return RazorpayPaymentResult.error(
        'Failed to process payment: ${e.toString()}',
      );
    }
  }

  /// Create Razorpay order using Razorpay Orders API
  Future<String?> _createRazorpayOrder({
    required double amount,
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final url = Uri.parse('https://api.razorpay.com/v1/orders');
      final basicAuth =
          'Basic ${base64Encode(utf8.encode('$_keyId:$_keySecret'))}';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(),
          'currency': currency,
          'receipt': receipt,
          'notes': notes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _setupPaymentCallbacks(String paymentTransactionId) {
    _onPaymentSuccess =
        (response) => _handleSpecificPaymentSuccess(response, paymentTransactionId);
    _onPaymentError =
        (response) => _handleSpecificPaymentError(response, paymentTransactionId);
    _onExternalWallet = (response) =>
        _handleSpecificExternalWallet(response, paymentTransactionId);
  }

  void _setupPaymentCallbacksWithOrderCreation(String paymentTransactionId) {
    _onPaymentSuccess = (response) =>
        _handlePaymentSuccessWithOrderCreation(response, paymentTransactionId);
    _onPaymentError = (response) =>
        _handlePaymentErrorWithFailureCallback(response, paymentTransactionId);
    _onExternalWallet = (response) =>
        _handleSpecificExternalWallet(response, paymentTransactionId);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_onPaymentSuccess != null) {
      _onPaymentSuccess!(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (_onPaymentError != null) {
      _onPaymentError!(response);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (_onExternalWallet != null) {
      _onExternalWallet!(response);
    }
  }

  Future<void> _handleSpecificPaymentSuccess(
    PaymentSuccessResponse response,
    String paymentTransactionId,
  ) async {
    try {
      final isSignatureValid = _verifyPaymentSignature(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!isSignatureValid) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransactionId,
          status: 'failed',
          failureReason: 'Invalid payment signature',
        );
        return;
      }

      final updatedPayment = await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'completed',
        razorpayPaymentId: response.paymentId,
        razorpaySignature: response.signature,
        processedAt: DateTime.now(),
      );

      if (updatedPayment.orderId != null) {
        await _orderRepository.updateOrderPayment(
          orderId: updatedPayment.orderId!,
          paymentStatus: 'advance_paid',
        );
      }
    } catch (_) {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: 'Error processing successful payment',
      );
    }
  }

  Future<void> _handleSpecificPaymentError(
    PaymentFailureResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: '${response.code}: ${response.message}',
      );
    } catch (_) {}
  }

  Future<void> _handleSpecificExternalWallet(
    ExternalWalletResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'processing',
        failureReason:
            'Payment redirected to external wallet: ${response.walletName}',
      );
    } catch (_) {}
  }

  Future<void> _handlePaymentSuccessWithOrderCreation(
    PaymentSuccessResponse response,
    String paymentTransactionId,
  ) async {
    try {
      final isSignatureValid = _verifyPaymentSignature(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );

      if (!isSignatureValid) {
        await _paymentRepository.updatePaymentStatus(
          paymentId: paymentTransactionId,
          status: 'failed',
          failureReason: 'Invalid payment signature',
        );
        _onPaymentFailed?.call('Invalid payment signature');
        return;
      }

      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'completed',
        razorpayPaymentId: response.paymentId,
        razorpaySignature: response.signature,
        processedAt: DateTime.now(),
      );

      if (_onOrderCreation != null) {
        await _onOrderCreation!(paymentTransactionId, response.paymentId ?? '');
      }
    } catch (e) {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: 'Error processing successful payment',
      );
      _onPaymentFailed?.call('Error processing payment: ${e.toString()}');
    }
  }

  Future<void> _handlePaymentErrorWithFailureCallback(
    PaymentFailureResponse response,
    String paymentTransactionId,
  ) async {
    try {
      await _paymentRepository.updatePaymentStatus(
        paymentId: paymentTransactionId,
        status: 'failed',
        failureReason: '${response.code}: ${response.message}',
      );

      _onPaymentFailed?.call('${response.code}: ${response.message}');
    } catch (e) {
      _onPaymentFailed?.call('Payment failed: ${e.toString()}');
    }
  }

  bool _verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    try {
      final data = '$orderId|$paymentId';
      final key = utf8.encode(_keySecret);
      final bytes = utf8.encode(data);

      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final generatedSignature = digest.toString();

      return generatedSignature == signature;
    } catch (_) {
      return false;
    }
  }

  Future<PaymentModel?> getPaymentStatus(String paymentTransactionId) async {
    try {
      return await _paymentRepository.getPaymentById(paymentTransactionId);
    } catch (_) {
      return null;
    }
  }

  Future<RefundResult> processRefund({
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    try {
      final refundId = 'rfnd_${DateTime.now().millisecondsSinceEpoch}';

      await _paymentRepository.processRefund(
        paymentId: paymentId,
        refundAmount: amount,
        refundId: refundId,
        reason: reason,
      );

      return RefundResult.success(refundId);
    } catch (e) {
      return RefundResult.error('Failed to process refund: ${e.toString()}');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

class RazorpayPaymentResult {
  final bool isSuccess;
  final String message;
  final String? paymentTransactionId;
  final String? orderId;

  RazorpayPaymentResult._({
    required this.isSuccess,
    required this.message,
    this.paymentTransactionId,
    this.orderId,
  });

  factory RazorpayPaymentResult.processing(
    String paymentTransactionId,
    String orderId,
  ) {
    return RazorpayPaymentResult._(
      isSuccess: true,
      message: 'Payment processing initiated',
      paymentTransactionId: paymentTransactionId,
      orderId: orderId,
    );
  }

  factory RazorpayPaymentResult.error(String message) {
    return RazorpayPaymentResult._(isSuccess: false, message: message);
  }
}

class RefundResult {
  final bool isSuccess;
  final String message;
  final String? refundId;

  RefundResult._({
    required this.isSuccess,
    required this.message,
    this.refundId,
  });

  factory RefundResult.success(String refundId) {
    return RefundResult._(
      isSuccess: true,
      message: 'Refund processed successfully',
      refundId: refundId,
    );
  }

  factory RefundResult.error(String message) {
    return RefundResult._(isSuccess: false, message: message);
  }
}
