import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/trip_route_detail_page.dart';

class DriverRiwayatPerjalananPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DriverRiwayatPerjalananPage({Key? key, required this.user}) : super(key: key);

  @override
  _DriverRiwayatPerjalananPageState createState() => _DriverRiwayatPerjalananPageState();
}

class _DriverRiwayatPerjalananPageState extends State<DriverRiwayatPerjalananPage> {
  late Future<List<Map<String, dynamic>>> _tripHistoryFuture;

  @override
  void initState() {
    super.initState();
    final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? widget.user['username'];
    if (namaSopir != null) {
      _tripHistoryFuture = MongoDBService.getTripHistoryBySopir(namaSopir);
    } else {
      _tripHistoryFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Perjalanan'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Riwayat Perjalanan Anda",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTripHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tripHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat riwayat perjalanan"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text("Belum ada riwayat perjalanan untuk Anda.",
                style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final trips = snapshot.data!;
        return Column(
          children: trips.map((trip) => _buildTripCard(trip)).toList(),
        );
      },
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    List<LatLng> routePoints = [];
    if (trip['route'] != null && trip['route']['coordinates'] != null) {
      for (var coord in trip['route']['coordinates']) {
        if (coord is List && coord.length >= 2) {
          double lng = (coord[0] as num).toDouble();
          double lat = (coord[1] as num).toDouble();
          routePoints.add(LatLng(lat, lng));
        }
      }
    }

    LatLngBounds? mapBounds;
    if (routePoints.isNotEmpty) {
      mapBounds = LatLngBounds.fromPoints(routePoints);
    }

    String date = trip['date'] ?? '-';
    String duration = trip['trip_duration_minutes']?.toString() ?? '0';
    String distance = trip['trip_distance_km']?.toString() ?? '0';
    String namaMobil = trip['model'] ?? 'N/A';
    String platNomor = trip['plat'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: Colors.blue[900]),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Expanded(
                  child: Text(
                    '$namaMobil ($platNomor)',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: routePoints.isEmpty
                ? Container(
                    color: Colors.grey[300],
                    child: const Center(child: Text("Rute tidak tersedia")),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCameraFit: mapBounds != null
                          ? CameraFit.bounds(bounds: mapBounds, padding: const EdgeInsets.all(24.0))
                          : null,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
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
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          if (routePoints.isNotEmpty)
                          Marker(
                            point: routePoints.first,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                          ),
                          if (routePoints.isNotEmpty)
                          Marker(
                            point: routePoints.last,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildTripStat(Icons.timer_outlined, "$duration m", "Durasi"),
                      const SizedBox(width: 12),
                      _buildTripStat(Icons.route_outlined, "$distance km", "Jarak"),
                      const SizedBox(width: 12),
                      _buildTripStat(Icons.speed, "${trip['kecepatan_maksimal'] ?? trip['max_speed'] ?? '0'} km/h", "Kec. Maks"),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (routePoints.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripRouteDetailPage(
                            routePoints: routePoints,
                            title: "Rute - $date",
                            tripData: trip,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Data rute tidak tersedia")),
                      );
                    }
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text("Detail", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blue[900], size: 14),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }
}
