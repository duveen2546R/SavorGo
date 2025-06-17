import 'dart:async';
import 'dart:convert';
import 'package:Savor_Go/screens/url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PersistentOSMDeliveryMap extends StatefulWidget {
  final String orderId;

  const PersistentOSMDeliveryMap({Key? key, required this.orderId}) : super(key: key);

  @override
  _PersistentOSMDeliveryMapState createState() => _PersistentOSMDeliveryMapState();
}

class _PersistentOSMDeliveryMapState extends State<PersistentOSMDeliveryMap> with SingleTickerProviderStateMixin {
  LatLng? restaurant;
  LatLng? user;
  LatLng? currentPosition;
  double distance = 0.0;
  static int totalDeliverySeconds = 0;
  int elapsedSeconds = 0;
  bool orderDelivered = false;
  Timer? _timer;
  List<LatLng> routeCurve = [];

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    getLocation();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  Future<void> getLocation() async {
    try {
      final response = await http.get(Uri.parse('$myurl/track_order/${widget.orderId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final restaurantCoords = data['restaurant'];
        final userCoords = data['user'];
        final orderTimeStr = data['order_time'];
        DateTime orderTime = DateTime.parse(orderTimeStr);

        setState(() {
          restaurant = LatLng(double.parse(restaurantCoords['latitude'].toString()), double.parse(restaurantCoords['longitude'].toString()));
          user = LatLng(double.parse(userCoords['latitude'].toString()), double.parse(userCoords['longitude'].toString()));
          currentPosition = restaurant;
          distance = double.tryParse(data['distance_km'].toString()) ?? 0.0;
          totalDeliverySeconds = distance.ceil() * 90;
        });

        await _generateOptimalRoute();
        await _loadOrStartTracking(orderTime);
      } else {
        print('❌ Failed to load coordinates: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching location: $e');
    }
  }

  Future<void> _generateOptimalRoute() async {
    if (restaurant == null || user == null) {
      print('❌ Cannot generate route. Coordinates are null.');
      return;
    }

    const apiKey = '5b3ce3597851110001cf62480492eeeace504633beb00781de0fdf1a';
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${restaurant!.longitude},${restaurant!.latitude}&end=${user!.longitude},${user!.latitude}'
    );

    try {
      final response = await http.get(uri);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['features'] != null && data['features'].isNotEmpty) {
        final coordinates = data['features'][0]['geometry']['coordinates'];

        setState(() {
          routeCurve = coordinates
              .map<LatLng>((point) => LatLng(point[1].toDouble(), point[0].toDouble()))
              .toList();
        });
      } else {
        print('❌ No features found in route data.');
      }
    } catch (e) {
      print('❌ Failed to get optimized route: $e');
    }
  }

  Future<void> _loadOrStartTracking(DateTime fallbackOrderTime) async {
  final prefs = await SharedPreferences.getInstance();
  
  final key = 'delivery_start_time_${widget.orderId}';
  int? storedMillis = prefs.getInt(key);

  if (storedMillis == null) {
    // Store local time only if not already present
    storedMillis = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, storedMillis);
  }

  _startSimulation(storedMillis, prefs);
  }

  void _startSimulation(int startMillis, SharedPreferences prefs) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      elapsedSeconds = ((nowMillis - startMillis) / 1000).floor();

      double t = elapsedSeconds / totalDeliverySeconds;
      t = t.clamp(0.0, 1.0);

      int index = (t * (routeCurve.length - 1)).floor();
      if (index >= 0 && index < routeCurve.length) {
        currentPosition = routeCurve[index];
      }

      setState(() {});

      if (t >= 1.0) {
        timer.cancel();
        prefs.remove('delivery_start_time_${widget.orderId}');
        prefs.setBool('order_delivered_${widget.orderId}', true);
        setState(() {
          orderDelivered = true;
        });
        await _markOrderAsDelivered();
        Navigator.pop(context);
      }
    });
  }

  Future<void> _markOrderAsDelivered() async {
    try {
      final response = await http.post(
        Uri.parse('$myurl/track_order/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': widget.orderId}),
      );

      if (response.statusCode == 200) {
        print("✅ Order status updated to Delivered");
      } else {
        print("❌ Failed to update status: ${response.body}");
      }
    } catch (e) {
      print("❌ Error updating order status: $e");
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = (totalDeliverySeconds - elapsedSeconds).clamp(0, totalDeliverySeconds);
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Order: ${widget.orderId}'),
        foregroundColor: Colors.white,
        backgroundColor: isDarkMode ? Colors.black : Colors.deepOrange,
      ),
      body: restaurant == null || user == null || currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: currentPosition!,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.savorgo',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routeCurve,
                          strokeWidth: 4.0,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: restaurant!,
                          width: 50,
                          height: 50,
                          child: Image.asset('assets/images/real/restaurant.png'),
                        ),
                        Marker(
                          point: user!,
                          width: 50,
                          height: 50,
                          child: Image.asset('assets/images/real/pin-map.png'),
                        ),
                        if (!orderDelivered)
                          Marker(
                            point: currentPosition!,
                            width: 50,
                            height: 50,
                            child: Image.asset('assets/images/real/food-delivery.png'),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 80,
                  left: 20,
                  right: 20,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Card(
                      color: Colors.blueGrey.withOpacity(0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            orderDelivered
                                ? 'Order Delivered!'
                                : 'Delivery in: ${_formatDuration(remainingSeconds)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
