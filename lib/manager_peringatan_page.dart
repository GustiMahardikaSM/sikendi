import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ManagerPeringatanPage extends StatefulWidget {
  const ManagerPeringatanPage({super.key});

  @override
  State<ManagerPeringatanPage> createState() => _ManagerPeringatanPageState();
}

class _ManagerPeringatanPageState extends State<ManagerPeringatanPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final data = await MongoDBService.getGeofencingAlerts();
    if (mounted) {
      setState(() {
        _alerts = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final speedAlerts = _alerts.where((a) => a['type'] == 'speed').toList();
    final geoAlerts = _alerts.where((a) => a['type'] == 'geofencing').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peringatan & Notifikasi'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(icon: Icon(Icons.speed), text: "Pelanggaran Kecepatan"),
            Tab(icon: Icon(Icons.map), text: "Pelanggaran Geofencing"),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertList(speedAlerts, "speed"),
                _buildAlertList(geoAlerts, "geofencing"),
              ],
            ),
    );
  }

  Widget _buildAlertList(List<Map<String, dynamic>> alerts, String type) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Tidak ada pelanggaran ${type == 'speed' ? 'kecepatan' : 'geofencing'}.",
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final bool isSpeed = alert['type'] == 'speed';
    final DateTime time = DateTime.parse(alert['timestamp']).toLocal();
    final String formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(time);
    
    // Parse location
    LatLng? pos;
    if (alert['location'] != null && alert['location']['coordinates'] != null) {
      final coords = alert['location']['coordinates'];
      pos = LatLng(coords[1].toDouble(), coords[0].toDouble());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSpeed ? Colors.red[50] : Colors.orange[50],
            child: Row(
              children: [
                Icon(isSpeed ? Icons.speed : Icons.warning_amber_rounded, 
                     color: isSpeed ? Colors.red[800] : Colors.orange[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  isSpeed ? "Pelanggaran Kecepatan" : "Pelanggaran Geofencing",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isSpeed ? Colors.red[900] : Colors.orange[900]),
                ),
                const Spacer(),
                Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(alert['peminjam'] ?? "Sopir Tidak Diketahui", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("${alert['model']} (${alert['plat']})"),
                  ],
                ),
                const Divider(height: 24),
                if (isSpeed)
                  Text("Kecepatan: ${alert['value'].toStringAsFixed(1)} km/h (Batas: ${alert['limit']} km/h)",
                      style: const TextStyle(fontSize: 15, color: Colors.red))
                else ...[
                  Text("Jarak: ${(alert['value'] / 1000).toStringAsFixed(2)} km (Batas: ${(alert['limit'] / 1000).toStringAsFixed(1)} km)",
                      style: const TextStyle(fontSize: 15, color: Colors.orange)),
                  const SizedBox(height: 4),
                  Text("Durasi di luar: ${(_formatDuration(alert['duration_seconds'] ?? 0))}",
                      style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          if (pos != null)
            SizedBox(
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pos,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.sikendi.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pos,
                        child: Icon(Icons.location_on, color: isSpeed ? Colors.red : Colors.orange, size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return "-";
    int s = (seconds as num).toInt();
    if (s < 60) return "$s detik";
    if (s < 3600) return "${s ~/ 60} menit ${s % 60} detik";
    return "${s ~/ 3600} jam ${(s % 3600) ~/ 60} menit";
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
