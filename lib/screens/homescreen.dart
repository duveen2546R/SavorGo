import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:Savor_Go/screens/FoodItemsScreen.dart';
import 'package:Savor_Go/screens/LocationPickerScreen.dart';
import 'url.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final String userId;
  String selectedLocation;
  String enteredAddress;
  final Map<String, Map<String, dynamic>> cart;
  final Function(Map<String, Map<String, dynamic>>) updateCart;

  HomeScreen({
    Key? key,
    required this.userId,
    required this.selectedLocation,
    required this.enteredAddress,
    required this.cart,
    required this.updateCart,
    required this.themeMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> filteredRestaurants = [];
  bool isLoading = true;

  // ✅ List of restaurant images
  final List<String> restaurantImages = [
    "assets/images/real/rice2.jpg",
    "assets/images/real/western.png",
    "assets/images/real/fruit.jpg",
    "assets/images/real/dessert.jpg",
    "assets/images/real/biryani.jpeg",
    "assets/images/real/apple_pie.jpg",
    "assets/images/real/coffee.jpg",
    "assets/images/real/coffee2.jpg",
    "assets/images/real/hamburger.jpg"
  ];

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    try {
      final response = await http.get(Uri.parse('$myurl/restaurants/${widget.userId}'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body)["restaurants"];
        setState(() {
          restaurants = List<Map<String, dynamic>>.from(data);
          filteredRestaurants = restaurants;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load restaurants');
      }
    } catch (e) {
      print("Error fetching restaurants: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _searchRestaurants(String query) {
    setState(() {
      filteredRestaurants = restaurants.where((restaurant) {
        return restaurant["name"].toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPickerScreen(userId: widget.userId ,  themeMode: widget.themeMode,
                            onThemeChanged: widget.onThemeChanged,), 
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    "Delivering to: ",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    widget.enteredAddress,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchRestaurants,
                decoration: InputDecoration(
                  hintText: "Search restaurants",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Restaurant List
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredRestaurants.isEmpty
                      ? Center(child: Text("No restaurants found"))
                      : ListView.builder(
                          itemCount: filteredRestaurants.length,
                          itemBuilder: (context, index) {
                            final restaurant = filteredRestaurants[index];

                            String imagePath = restaurantImages[index % restaurantImages.length];

                            return _buildRestaurantItem(
                              restaurant["name"],
                              restaurant["id"], 
                              imagePath,
                              restaurant["distance_km"],
                              restaurant["rating"]
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantItem(
    String restaurantName,
    String restaurantId,
    String imagePath,
    double distance,
    double rating,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodItemsScreen(
              customerId: widget.userId,
              restaurantName: restaurantName,
              restaurantId: restaurantId,
              cart: widget.cart,
              updateCart: widget.updateCart,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.black38,
        elevation: 5,
        shadowColor: Colors.grey.withOpacity(0.5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imagePath,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.yellowAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(2)} km',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}