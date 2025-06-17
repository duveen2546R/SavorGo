import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'url.dart';

class InvoiceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final String customerId;
  final String restaurantId;

  const InvoiceScreen({
    required this.cartItems,
    required this.totalAmount,
    required this.customerId,
    required this.restaurantId,
    Key? key,
  }) : super(key: key);

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  int distance = 0;

  @override
  void initState() {
    super.initState();
    fetchDistance();
  }

  Future<void> fetchDistance() async {
    try {
      final uri = Uri.parse(
          '$myurl/invoice?restaurant_id=${widget.restaurantId}&user_id=${widget.customerId}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          double temp = data['distance_km']?.toDouble() ?? 0.0;
          distance = temp.ceil();
        });
      } else {
        print("Failed to fetch distance: ${response.body}");
      }
    } catch (e) {
      print("Exception during distance fetch: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    DateTime deliveryTime = DateTime.now().add(Duration(minutes: distance * 4));
    String formattedDeliveryTime = DateFormat('hh:mm a').format(deliveryTime);

    return Scaffold(
      appBar: AppBar(title: Text("Order Invoice") , backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange, foregroundColor: Colors.white,),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order Summary",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.cartItems.length,
                itemBuilder: (context, index) {
                  final item = widget.cartItems[index];
                  return ListTile(
                    title: Text(item["name"],
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        "₹${item["price"].toStringAsFixed(2)} x ${item["quantity"]}"),
                    trailing: Text(
                        "₹${(item["price"] * item["quantity"]).toStringAsFixed(2)}"),
                  );
                },
              ),
            ),
            Divider(),
            Text("Total: ₹${widget.totalAmount.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Estimated Delivery Time: $formattedDeliveryTime",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text("Back to Home"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
