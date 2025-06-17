import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'url.dart';

class FoodItemsScreen extends StatefulWidget {
  final String restaurantName;
  final String restaurantId;
  final String customerId;
  final Map<String, Map<String, dynamic>> cart;
  final Function(Map<String, Map<String, dynamic>>) updateCart;

  const FoodItemsScreen({
    Key? key,
    required this.restaurantName,
    required this.restaurantId,
    required this.cart,
    required this.updateCart,
    required this.customerId,
  }) : super(key: key);

  @override
  _FoodItemsScreenState createState() => _FoodItemsScreenState();
}

class _FoodItemsScreenState extends State<FoodItemsScreen> {
  List<Map<String, dynamic>> foodItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    try {
      final response = await http.get(
        Uri.parse("${myurl}/menu/${widget.restaurantId}"),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse.containsKey("menu")) {
          setState(() {
            foodItems = List<Map<String, dynamic>>.from(jsonResponse["menu"]);
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load menu items");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching menu items: $e");
    }
  }

  void _addToCart(String itemId, String itemName, double itemPrice) async {
    if (widget.cart.isNotEmpty) {
      String existingRestaurantId = widget.cart.values.first["restaurantId"];
      if (existingRestaurantId != widget.restaurantId) {
        _showErrorDialog();
        return;
      }
    }

    setState(() {
      if (widget.cart.containsKey(itemId)) {
        widget.cart[itemId]!['quantity'] += 1;
      } else {
        widget.cart[itemId] = {
          "name": itemName,
          "quantity": 1,
          "price": itemPrice,
          "restaurantId": widget.restaurantId,
          "restaurantName": widget.restaurantName,
        };
      }
    });

    widget.updateCart(widget.cart);

    // API call to add item
    try {
      final response = await http.post(
        Uri.parse('$myurl/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "Customer_ID": widget.customerId, // Replace with real ID
          "Item_ID": itemId,
          "Quantity": 1,
        }),
      );

      if (response.statusCode != 201) {
        print("⚠️ Add error: ${response.body}");
      }
    } catch (e) {
      print("❌ Error adding item: $e");
    }
  }


  void _removeFromCart(String itemId) async {
    if (!widget.cart.containsKey(itemId)) return;

    setState(() {
      if (widget.cart[itemId]!['quantity'] > 1) {
        widget.cart[itemId]!['quantity'] -= 1;
      } else {
        widget.cart.remove(itemId);
      }
    });

    widget.updateCart(widget.cart);

    // API call to remove item
    try {
      final response = await http.post(
        Uri.parse('$myurl/cart/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "Customer_ID": widget.customerId, // Replace with real ID
          "Item_ID": itemId,
        }),
      );

      if (response.statusCode != 200) {
        print("⚠️ Remove error: ${response.body}");
      }
    } catch (e) {
      print("❌ Error removing item: $e");
    }
  }


  // ✅ Show Alert Dialog when user tries to add items from different restaurants
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Order Restriction"),
        content:
            const Text("You can only order from one restaurant at a time."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurantName) , backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange, foregroundColor: Colors.white,),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : foodItems.isEmpty
              ? Center(child: Text("No food items available"))
              : ListView.builder(
                  itemCount: foodItems.length,
                  itemBuilder: (context, index) {
                    final food = foodItems[index];

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      child: ListTile(
                        title: Text(food["Item_Name"] ?? "Unknown Item",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food["Description"] ??
                                "No description available"),
                            SizedBox(height: 5),
                            Text(
                              "₹${(double.tryParse(food["Price"].toString()) ?? 0.0).toStringAsFixed(2)}",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () =>
                                  _removeFromCart(food["Item_ID"] ?? ""),
                            ),
                            Text(widget.cart[food["Item_ID"]]?['quantity']
                                    ?.toString() ??
                                "0"),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => _addToCart(
                                  food["Item_ID"] ?? "",
                                  food["Item_Name"] ?? "",
                                  double.tryParse(food["Price"].toString()) ??
                                      0.0),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
