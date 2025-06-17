import 'package:flutter/material.dart';
import 'package:Savor_Go/screens/CartScreen.dart';
import 'package:Savor_Go/screens/account_screen.dart';
import 'package:Savor_Go/screens/homescreen.dart';
import 'package:Savor_Go/screens/your_orders.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  final String selectedLocation;
  final String enteredAddress;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;

  const MainScreen({
    Key? key,
    required this.userId,
    required this.selectedLocation,
    required this.enteredAddress,
    required this.themeMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final GlobalKey<YourOrdersScreenState> _ordersKey = GlobalKey<YourOrdersScreenState>();

  Map<String, Map<String, dynamic>> cart = {};

  void _updateCart(Map<String, Map<String, dynamic>> updatedCart) {
    setState(() {
      cart = updatedCart;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            userId: widget.userId,
            selectedLocation: widget.selectedLocation,
            enteredAddress: widget.enteredAddress,
            cart: cart,
            updateCart: _updateCart,
            themeMode: widget.themeMode,
            onThemeChanged: widget.onThemeChanged,
          ),
          YourOrdersScreen(
            key: _ordersKey,
            customerId: widget.userId,
          ),
          CartScreen(
            cartItems: cart,
            customerId: widget.userId,
            refreshOrders: () {
              _ordersKey.currentState?.refreshOrders();
            },
          ),
          AccountScreen(
            userId: widget.userId,
            themeMode: widget.themeMode,
            onThemeChanged: widget.onThemeChanged,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "My Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Cart"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Account"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}
