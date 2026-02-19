import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sikendi/mongodb_service.dart';

class DriverTrackingPage extends StatefulWidget {
  const DriverTrackingPage({super.key});

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  LatLng? _currentPosition;
  double _currentSpeed = 0.0;
  Timer? _timer;
  
  final double _speedLimit = 60.0; 
  bool _isOverspeeding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final data = await MongoService.getLatestGpsData();
    if (data == null || !mounted) return;

    final doc = data;
    double? lat, lng;

    try {
      if (doc['gps_location'] != null) {
        final loc = doc['gps_location'];
        if (loc is Map && loc.containsKey('lat') && loc.containsKey('lng')) {
          lat = (loc['lat'] as num).toDouble();
          lng = (loc['lng'] as num).toDouble();
        } else if (loc is Map && loc.containsKey('coordinates')) {
          final List coords = loc['coordinates'];
          if (coords.length >= 2) {
            lng = (coords[0] as num).toDouble();
            lat = (coords[1] as num).toDouble();
          }
        }
      }
      if (lat == null && lng == null) {
        if (doc.containsKey('lat') && doc.containsKey('lng')) {
          lat = (doc['lat'] as num).toDouble();
          lng = (doc['lng'] as num).toDouble();
        }
      }
    } catch (e) {
      print("Error parsing location: $e");
      return;
    }

    if (lat != null && lng != null) {
      final speed = (doc['speed'] as num? ?? 0).toDouble();

      setState(() {
        _currentPosition = LatLng(lat!, lng!);
        _currentSpeed = speed;

        if (_currentSpeed > _speedLimit) {
          if (!_isOverspeeding) {
            _isOverspeeding = true;
            if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                  content: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 10),
                      Text("BAHAYA! Anda melewati batas kecepatan!",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }
          }
        } else {
          _isOverspeeding = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking GPS'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sikendi.driver',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.directions_car, color: Colors.green, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOverspeeding ? Colors.red : Colors.white, 
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
              ),
              child: Column(
                children: [
                  const Text("Kecepatan", style: TextStyle(fontSize: 12)),
                  Text(
                    "${_currentSpeed.toStringAsFixed(1)} km/h",
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: _isOverspeeding ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}