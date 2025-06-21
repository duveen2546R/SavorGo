import 'dart:async';
import 'package:Savor_Go/screens/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'invoiceScreen.dart'; // Ensure this file exists and is correctly implemented

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final String customerId;
  final VoidCallback onPaymentSuccess;


  // Update this to match your local or production backend IP

  const PaymentScreen({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
    required this.customerId,
    required this.onPaymentSuccess,
  }) : super(key: key);


  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  String paymentStatus = "Click the button to start payment";
  String? currentOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
     _startPayment(); // Start payment automatically after screen renders
    });
  }

  Future<String?> placeOrder(String customerId) async {
    final url = Uri.parse('${myurl}/order/place');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"Customer_ID": customerId}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data["Order_ID"];
      } else {
        debugPrint("❌ Order API error: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Order request failed: $e");
      return null;
    }
  }

  Future<void> sendPaymentConfirmation(String orderId, String razorpayPaymentId) async {
    final url = Uri.parse('${myurl}/payment');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "Order_ID": orderId,
          "Razorpay_ID": razorpayPaymentId,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("✅ Payment confirmed to backend");
      } else {
        debugPrint("❌ Payment confirmation failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Payment API error: $e");
    }
  }

  Future<void> _startDeliveryTimer(String orderId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'delivery_start_time_$orderId';
  final deliveredKey = 'order_delivered_$orderId';

  if (!prefs.containsKey(key)) {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, nowMillis);
    await prefs.setBool(deliveredKey, false);
  }

  // Simulate distance-based delay (use backend distance if needed)
  int deliveryTimeSecs = 40 * 60; // 40 minutes (2400 seconds)

  Timer(Duration(seconds: deliveryTimeSecs), () async {
    final delivered = prefs.getBool(deliveredKey) ?? false;
    if (!delivered) {
      try {
        final response = await http.post(
          Uri.parse('${myurl}/track_order/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'orderId': orderId}),
        );
        if (response.statusCode == 200) {
          await prefs.setBool(deliveredKey, true);
          debugPrint("✅ Order auto-marked as delivered");
        } else {
          debugPrint("❌ Delivery update failed: ${response.body}");
        }
      } catch (e) {
        debugPrint("❌ Delivery timer error: $e");
      }
    }
  });
}

  void _startPayment() async {
    final orderId = await placeOrder(widget.customerId);
    if (orderId == null) {
      _showDialog("Order Error", "Failed to place order. Try again.");
      return;
    }

    setState(() {
      currentOrderId = orderId;
    });

    try {
      var options = {
        'key': 'rzp_test_zk5c0q1Ahl5aqc', // Replace with your live Razorpay key
        'amount': (widget.totalAmount * 100).toInt(), // amount in paise
        'currency': 'INR',
        'name': 'SavorGo Food Delivery',
        'description': 'Payment for Order $orderId',
        'prefill': {
          'contact': '9876543210',
          'email': 'test@example.com',
        },
        'theme': {'color': '#F37254'},
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay open error: $e");
      _showDialog("Payment Error", "Failed to start payment. Try again.");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
  setState(() {
    paymentStatus = "✅ Payment Successful: ${response.paymentId}";
  });

  if (currentOrderId != null && response.paymentId != null) {
    await sendPaymentConfirmation(currentOrderId!, response.paymentId!);
    widget.onPaymentSuccess(); // Clear cart

    final prefs = await SharedPreferences.getInstance();
    final key = 'delivery_start_time_${currentOrderId!}';
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, nowMillis);
    await prefs.setBool('order_delivered_${currentOrderId!}', false);

    // Start silent background delivery simulation
    int totalDeliverySeconds = 40 * 60; // 40 minutes default (customize based on distance if needed)

    Future.delayed(Duration(seconds: totalDeliverySeconds), () async {
      final deliveredFlag = 'order_delivered_${currentOrderId!}';
      await prefs.setBool(deliveredFlag, true);

      try {
        final response = await http.post(
          Uri.parse('${myurl}/track_order/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'orderId': currentOrderId!}),
        );

        if (response.statusCode == 200) {
          debugPrint("✅ Order auto-marked as delivered");
        } else {
          debugPrint("❌ Auto delivery update failed: ${response.body}");
        }
      } catch (e) {
        debugPrint("❌ Error during silent delivery update: $e");
      }
    });
  } else {
    debugPrint("⚠️ Either Order ID or Razorpay Payment ID is null");
  }

  Navigator.pop(context, true); // Notify success

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InvoiceScreen(
        cartItems: widget.cartItems,
        totalAmount: widget.totalAmount,
        customerId: widget.customerId,
        restaurantId: widget.cartItems[0]['restaurantId'],
      ),
    ),
  );
}

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      paymentStatus = "❌ Payment Failed: ${response.message}";
    });

    _showDialog(
      "Payment Failed",
      "Error Code: ${response.code}\nMessage: ${response.message}",
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      paymentStatus = "💼 Wallet Used: ${response.walletName}";
    });

    _showDialog("Wallet Used", "Selected Wallet: ${response.walletName}");
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  @override
Widget build(BuildContext context) {
  bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return Scaffold(
    appBar: AppBar(
      title: const Text("Payment"),
      backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
      foregroundColor: Colors.white,
    ),
    body: const Center(
      child: CircularProgressIndicator(), // or a custom loading animation
    ),
  );
}
}
