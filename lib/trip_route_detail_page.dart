import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TripRouteDetailPage extends StatelessWidget {
  final List<LatLng> routePoints;
  final String title;
  final Map<String, dynamic>? tripData;

  const TripRouteDetailPage({
    super.key,
    required this.routePoints,
    this.title = "Detail Rute Perjalanan",
    this.tripData,
  });

  @override
  Widget build(BuildContext context) {
    LatLngBounds? mapBounds;
    if (routePoints.isNotEmpty) {
      mapBounds = LatLngBounds.fromPoints(routePoints);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: mapBounds != null
                  ? CameraFit.bounds(bounds: mapBounds, padding: const EdgeInsets.all(50.0))
                  : null,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.sikendi.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Colors.blueAccent,
                    strokeWidth: 5.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (routePoints.isNotEmpty)
                    Marker(
                      point: routePoints.first,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                    ),
                  if (routePoints.isNotEmpty)
                    Marker(
                      point: routePoints.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),
          
          // Statistik Ringkas di pojok bawah
          if (tripData != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(Icons.timer_outlined, "${tripData!['trip_duration_minutes'] ?? tripData!['durasi_menit'] ?? '0'} m", "Durasi"),
                      _buildMiniStat(Icons.route_outlined, "${tripData!['trip_distance_km'] ?? tripData!['jarak_km'] ?? '0'} km", "Jarak"),
                      _buildMiniStat(Icons.speed, "${tripData!['kecepatan_maksimal'] ?? tripData!['max_speed'] ?? '0'} km/h", "Kec. Maks"),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.blue[800], size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
