import 'package:Savor_Go/screens/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Savor_Go/screens/track_order.dart';
import 'package:Savor_Go/screens/ReviewScreen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:async';


class YourOrdersScreen extends StatefulWidget {
  final String customerId;

  const YourOrdersScreen({
    Key? key,
    required this.customerId,
  }) : super(key: key);

  @override
  YourOrdersScreenState createState() => YourOrdersScreenState();
}

class YourOrdersScreenState extends State<YourOrdersScreen> {
  List<Map<String, dynamic>> allOrders = [];
  List<Map<String, dynamic>> currentOrders = [];
  List<Map<String, dynamic>> pastOrders = [];
  bool isLoading = true;

  Timer? _autoRefreshTimer;

  @override
void initState() {
  super.initState();
  checkDeliveryStatus().then((_) {
    fetchOrders();
  });

  _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    if (mounted) {
      checkDeliveryStatus().then((_) {
        fetchOrders();
      });
    } else {
      timer.cancel();
    }
  });
}

  void refreshOrders() {
    fetchOrders();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
      super.dispose();
}

  Future<void> fetchOrders() async {
  try {
    setState(() => isLoading = true);
    final response = await http.get(Uri.parse('$myurl/orders/${widget.customerId}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final orders = List<Map<String, dynamic>>.from(data['orders']);

      final prefs = await SharedPreferences.getInstance(); 

      currentOrders = [];
      pastOrders = [];

      for (var order in orders) {
        final orderId = order['orderId'];
        final deliveredKey = 'order_delivered_$orderId';
        final bool deliveredLocally = prefs.getBool(deliveredKey) ?? false;

        final backendStatus = order['status'];

        if (backendStatus == 'Delivered' || backendStatus == 'Cancelled' || deliveredLocally) {
          // ✅ Move to past orders
          order['status'] = 'Delivered'; // Force update if needed
          pastOrders.add(order);
        } else {
          currentOrders.add(order);
        }
      }

      setState(() {
        allOrders = orders;
        isLoading = false;
      });
    } else {
      throw Exception("Failed to load orders");
    }
  } catch (e) {
    setState(() => isLoading = false);
    print("❌ Error loading orders: $e");
  }
}

  // ✅ No extra fetch; pass orderId + customerId
  Future<void> openOrderDetails(String orderId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsWithReviewScreen(
          orderId: orderId,
          customerId: widget.customerId,
        ),
      ),
    );
  }

  Future<void> checkDeliveryStatus() async {
  final prefs = await SharedPreferences.getInstance();

  final response = await http.get(Uri.parse('$myurl/orders/${widget.customerId}'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final orders = List<Map<String, dynamic>>.from(data['orders']);

    for (var order in orders) {
      final orderId = order['orderId'];
      final startMillis = prefs.getInt('delivery_start_time_$orderId');
      final isDelivered = prefs.getBool('order_delivered_$orderId') ?? false;

      if (startMillis != null && !isDelivered) {
        final nowMillis = DateTime.now().millisecondsSinceEpoch;
        final elapsed = (nowMillis - startMillis) ~/ 1000;

        final distanceKm = double.tryParse(order['distance_km'].toString()) ?? 1.0;
        final totalDeliverySeconds = (distanceKm.ceil() * 90);

        if (elapsed >= totalDeliverySeconds) {
          // ✅ Mark in backend
          await http.post(
            Uri.parse('$myurl/track_order/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'orderId': orderId}),
          );

          // ✅ Update local state
          await prefs.remove('delivery_start_time_$orderId');
          await prefs.setBool('order_delivered_$orderId', true);
          print('✅ Order $orderId auto-marked as delivered');
        }
      }
    }
  } else {
    print("❌ Failed to fetch orders for delivery check");
  }
}

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Orders"),
        backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allOrders.isEmpty
              ? const Center(child: Text("No orders found."))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentOrders.isNotEmpty) ...[
                          const Text(
                            "Current Orders",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ...currentOrders.map((order) => Card(
                                child: ListTile(
                                  title: Text("Order ${order["orderId"]}"),
                                  subtitle: Text("Status: ${order["status"]}"),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PersistentOSMDeliveryMap(
                                            orderId: order['orderId'],
                                          ),
                                        ),
                                      );
                                      refreshOrders();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: const Text(
                                      "Track",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  onTap: () => openOrderDetails(order["orderId"]),
                                ),
                              )),
                          const SizedBox(height: 20),
                        ],
                        if (pastOrders.isNotEmpty) ...[
                          const Text(
                            "Past Orders",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ...pastOrders.map((order) => Card(
                                child: ListTile(
                                  title: Text("Order ${order["orderId"]}"),
                                  subtitle: Text("Status: ${order["status"]}"),
                                  trailing: Text("${order["total"]}"),
                                  onTap: () => openOrderDetails(order["orderId"]),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
