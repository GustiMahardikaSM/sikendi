import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Untuk Peta
import 'package:latlong2/latlong.dart';       // Untuk Koordinat
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Driver Database

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DirectMongoTracking(),
  ));
}

class DirectMongoTracking extends StatefulWidget {
  const DirectMongoTracking({super.key});

  @override
  State<DirectMongoTracking> createState() => _DirectMongoTrackingState();
}

class _DirectMongoTrackingState extends State<DirectMongoTracking> {
  // ====================================================================
  // 1. KONFIGURASI DATABASE (Sesuai Data Anda)
  // ====================================================================
  // Kita hubungkan langsung ke Cloud, jadi bisa diakses dari manapun.
  final String _mongoUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/gps_1?retryWrites=true&w=majority";
  
  final String _collectionName = "gps_location";

  mongo.Db? _db;
  List<LatLng> _routePoints = []; // Menyimpan jejak rute
  LatLng? _currentPosition;       // Posisi marker terakhir
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _connectToMongo(); // Koneksi awal
    
    // Auto-refresh data setiap 5 detik agar terlihat bergerak
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLatestData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _db?.close(); // Tutup koneksi saat aplikasi ditutup
    super.dispose();
  }

  // LOGIKA 1: Membuka Koneksi (Mirip: client = MongoClient(URI))
  Future<void> _connectToMongo() async {
    try {
      _db = await mongo.Db.create(_mongoUrl);
      await _db!.open();
      print("✅ Berhasil terkoneksi ke MongoDB Atlas!");
      _fetchLatestData();
    } catch (e) {
      print("❌ Gagal Konek DB: $e");
      // Tampilkan error di layar jika perlu
    }
  }

  // LOGIKA 2: Mengambil Data (Mirip: collection.find())
  Future<void> _fetchLatestData() async {
    if (_db == null || !_db!.isConnected) return;

    try {
      var collection = _db!.collection(_collectionName);

      // Ambil 50 data terakhir, diurutkan dari yang terbaru
      // Sort: -1 artinya Descending (Terbaru di atas)
      final data = await collection
          .find(mongo.where.sortBy('server_received_at', descending: true).limit(50))
          .toList();

      if (data.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Proses data JSON dari MongoDB ke List LatLng Flutter
      List<LatLng> tempPoints = [];
      
      for (var doc in data) {
        // Cek struktur data sesuai screenshot Anda sebelumnya
        // (Ada object 'gps_location' yang berisi 'lat' dan 'lng')
        if (doc['gps_location'] != null) {
          var loc = doc['gps_location'];
          // Pastikan dikonversi ke double
          double lat = (loc['lat'] as num).toDouble();
          double lng = (loc['lng'] as num).toDouble();
          tempPoints.add(LatLng(lat, lng));
        }
      }

      // Karena kita ambil dari 'Terbaru', urutannya terbalik.
      // Kita balik lagi agar garis rute nyambung dari Lama -> Baru.
      tempPoints = tempPoints.reversed.toList();

      if (tempPoints.isNotEmpty) {
        setState(() {
          _routePoints = tempPoints;
          _currentPosition = tempPoints.last; // Posisi paling ujung (terbaru)
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error mengambil data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tracking"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? const Center(child: Text("Belum ada data GPS masuk."))
              : FlutterMap(
                  options: MapOptions(
                    // Fokus kamera ke posisi terakhir
                    initialCenter: _currentPosition!,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tracking.app',
                    ),
                    
                    // LAYER 1: Garis Rute (Biru)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),

                    // LAYER 2: Marker Posisi (Merah)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.navigation, // Ikon Panah
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}