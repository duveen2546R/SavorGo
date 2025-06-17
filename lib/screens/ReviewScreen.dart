import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'url.dart';

class OrderDetailsWithReviewScreen extends StatefulWidget {
  final String orderId;
  final String customerId;

  const OrderDetailsWithReviewScreen({
    required this.orderId,
    required this.customerId,
    Key? key,
  }) : super(key: key);

  @override
  State<OrderDetailsWithReviewScreen> createState() => _OrderDetailsWithReviewScreenState();
}

class _OrderDetailsWithReviewScreenState extends State<OrderDetailsWithReviewScreen> {
  double rating = 0.0;
  int distance = 0;
  double totalAmount = 0.0;
  String restaurantId = '';
  String restaurantName = '';
  List<dynamic> items = [];
  final TextEditingController reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  Future<void> fetchOrderDetails() async {
    try {
      final response = await http.get(Uri.parse(
          '$myurl/order/details/${widget.orderId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          restaurantName = data['restaurantName'];
          restaurantId = data['restaurantId'];
          totalAmount = data['total']?.toDouble() ?? 0.0;
          items = data['items'];
        });

        fetchDistance(); // now that restaurantId is available
      } else {
        print("Failed to fetch order details: ${response.body}");
      }
    } catch (e) {
      print("Error fetching order details: $e");
    }
  }

  Future<void> fetchDistance() async {
    try {
      final uri = Uri.parse(
          '$myurl/invoice?restaurant_id=$restaurantId&user_id=${widget.customerId}');

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

  Future<void> submitReview() async {
    final response = await http.post(
      Uri.parse('$myurl/review'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": widget.customerId,
        "restaurant_id": restaurantId,
        "rating": rating,
        "review_text": reviewController.text.trim(),
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Review submitted successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to submit review")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    DateTime deliveryTime = DateTime.now().add(Duration(minutes: distance * 4));
    String formattedDeliveryTime = DateFormat('hh:mm a').format(deliveryTime);

    return Scaffold(
      appBar: AppBar(
        title: Text("Order & Review"),
        backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: items.isEmpty
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Restaurant: $restaurantName",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item["name"], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          subtitle: Text("₹${item["price"].toStringAsFixed(2)} x ${item["quantity"]}"),
                          trailing: Text("₹${(item["price"] * item["quantity"]).toStringAsFixed(2)}"),
                        );
                      },
                    ),
                  ),
                  Divider(),
                  Text("Total: ₹${totalAmount.toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("Delivery Time: $formattedDeliveryTime",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Ratings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemSize: 30,
                        itemCount: 5,
                        itemPadding: EdgeInsets.symmetric(horizontal: 2.0),
                        itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (value) {
                          setState(() {
                            rating = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write your review...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitReview,
                      child: Text("Submit Review"),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
