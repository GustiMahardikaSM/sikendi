import 'dart:async'; // Timer untuk refresh data otomatis
import 'package:flutter/material.dart'; // UI Standar
import 'package:flutter_map/flutter_map.dart'; // Peta
import 'package:latlong2/latlong.dart'; // Koordinat
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Database
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/manager_vehicle_tab.dart';

// ==========================================================
// KELAS UTAMA HALAMAN MANAJER
// ==========================================================
class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  int _selectedIndex = 0; // Mengatur Tab yang aktif

  // Daftar Tab Halaman
  static final List<Widget> _pages = <Widget>[
    const ManagerDashboardTab(), // Tab 0: Peta Monitoring Armada
    const ManagerVehicleManagementTab(), // Tab 1: Manajemen Kendaraan
    const ManagerDriversTab(),   // Tab 2: Daftar & Profil Sopir
    const ManagerAlertsTab(),    // Tab 3: Peringatan (Alert System)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Dashboard SiKenDi"),
        backgroundColor: Colors.blue[900], // Warna Biru Tua (Korporat/Undip)
        foregroundColor: Colors.white,
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensure all items are visible
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Monitoring',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Kendaraan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Driver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Alerts',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[900],
        onTap: _onItemTapped,
      ),
    );
  }
}

// ==========================================================
// TAB 1: DASHBOARD MONITORING (DENGAN DETEKSI GPS MATI)
// ==========================================================
class ManagerDashboardTab extends StatefulWidget {
  const ManagerDashboardTab({super.key});

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  List<Map<String, dynamic>> _activeVehicles = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchFleetData(); // Initial fetch
    // Refresh peta setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchFleetData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFleetData() async {
    try {
      final data = await MongoService.getFleetDataForManager();
      if (mounted) {
        setState(() {
          _activeVehicles = data;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error in ManagerDashboardTab: $e");
    }
  }

  // --- LOGIKA BARU: CEK APAKAH GPS OFFLINE ---
  bool _isGpsOffline(String? serverTimeStr) {
    if (serverTimeStr == null) return true; // Tidak ada waktu = Mati
    
    try {
      // Parsing waktu dari format MongoDB (ISO 8601)
      DateTime lastUpdate = DateTime.parse(serverTimeStr).toLocal();
      DateTime now = DateTime.now();

      // Hitung selisih waktu
      Duration diff = now.difference(lastUpdate);

      // JIKA LEBIH DARI 5 MENIT TIDAK ADA DATA -> ANGGAP MATI
      return diff.inMinutes > 5; 
    } catch (e) {
      return true; // Error parsing = Anggap mati
    }
  }

  // LOGIKA WARNA STATUS (UPDATE)
  Color _getStatusColor(double speed, String? serverTimeStr) {
    // 1. Cek dulu apakah GPS Mati (Offline)
    if (_isGpsOffline(serverTimeStr)) {
      return Colors.red; // MERAH (Offline/Mati)
    }

    // 2. Jika GPS Hidup, cek kecepatan
    if (speed > 5) return Colors.green; // Sedang Jalan
    if (speed > 0) return Colors.orange; // Idle (Mesin nyala, berhenti)
    return Colors.red; // Parkir (Speed 0)
  }

  String _getStatusText(double speed, String? serverTimeStr) {
    if (_isGpsOffline(serverTimeStr)) {
      // Hitung sudah mati berapa lama (Opsional, untuk info)
      DateTime last = DateTime.parse(serverTimeStr!).toLocal();
      int minAgo = DateTime.now().difference(last).inMinutes;
      return "GPS Mati / Offline ($minAgo mnt lalu)";
    }

    if (speed > 5) return "Sedang Jalan";
    if (speed > 0) return "Idle";
    return "Parkir";
  }

  // POP-UP DETAIL KENDARAAN
  void _showVehicleDetail(BuildContext context, Map<String, dynamic> vehicle) {
    String deviceName = vehicle['device_id'] ?? "Unknown Device"; // FIX: from gps_1 to device_id
    double speed = (vehicle['speed'] as num? ?? 0).toDouble();
    // Ambil waktu terakhir update
    String? timestamp = vehicle['server_received_at']?.toString();
    
    double lat = 0;
    double lng = 0;
    if (vehicle['gps_location'] != null) {
      lat = (vehicle['gps_location']['lat'] as num).toDouble();
      lng = (vehicle['gps_location']['lng'] as num).toDouble();
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 30, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(deviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.speed),
                title: Text("${speed.toStringAsFixed(1)} km/h"),
                subtitle: Text(
                  _getStatusText(speed, timestamp), 
                  style: TextStyle(
                    color: _getStatusColor(speed, timestamp), // Warna teks menyesuaikan status
                    fontWeight: FontWeight.bold
                  )
                ),
                trailing: CircleAvatar(
                  backgroundColor: _getStatusColor(speed, timestamp), 
                  radius: 10
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text("Terakhir Update"),
                subtitle: Text(timestamp != null 
                    ? DateTime.parse(timestamp).toLocal().toString().split('.')[0] 
                    : "-"),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Posisi Terakhir"),
                subtitle: Text("$lat, $lng"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _activeVehicles.isEmpty
        ? const Center(child: Text("Memuat data armada...")) 
        : FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-7.052219, 110.441481), 
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sikendi.manager',
              ),
              MarkerLayer(
                markers: _activeVehicles.map((vehicle) {
                  double lat = 0;
                  double lng = 0;
                  double speed = 0;
                  String? timestamp = vehicle['server_received_at']?.toString();

                  if (vehicle['gps_location'] != null) {
                    lat = (vehicle['gps_location']['lat'] as num).toDouble();
                    lng = (vehicle['gps_location']['lng'] as num).toDouble();
                  }
                  speed = (vehicle['speed'] as num? ?? 0).toDouble();

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _showVehicleDetail(context, vehicle),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(4),
                               border: Border.all(color: Colors.black12)
                            ),
                            child: Text(
                              vehicle['device_id'] ?? "?", // FIX: from gps_1 to device_id
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.directions_car_filled,
                            color: _getStatusColor(speed, timestamp), 
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
  }
}

// ==========================================================
// TAB 2: DETAIL PENGEMUDI (KARTU DRIVER)
// ==========================================================
class ManagerDriversTab extends StatelessWidget {
  const ManagerDriversTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Data Dummy Driver (Karena di DB MongoDB belum ada collection user)
    final List<Map<String, String>> drivers = [
      {"nama": "Pak Budi", "nip": "1980101", "status": "Aktif", "mobil": "Toyota Avanza"},
      {"nama": "Pak Asep", "nip": "1980202", "status": "Istirahat", "mobil": "-"},
      {"nama": "Pak Joko", "nip": "1980303", "status": "Aktif", "mobil": "HiAce Kampus"},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        var drv = drivers[index];
        return Card(
          elevation: 2,
          child: ExpansionTile(
            leading: CircleAvatar(child: Text(drv["nama"]![0])), // Inisial Nama
            title: Text(drv["nama"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("NIP: ${drv["nip"]} • Status: ${drv["status"]}"),
            children: [
              // Bagian Riwayat / Profil (Kartu Driver)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Detail & Riwayat:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("Kendaraan saat ini: ${drv['mobil']}"),
                    const Text("SIM: B1 Umum (Berlaku s.d 2028)"),
                    const Text("Rating Kinerja: 4.8/5.0"),
                    const Divider(),
                    const Text("Riwayat Perjalanan Terakhir:"),
                    const Text("- 29 Des: Rektorat -> Bandara (Aman)"),
                    const Text("- 28 Des: F. Teknik -> Tembalang (Aman)"),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

// ==========================================================
// TAB 3: SISTEM PERINGATAN (BEHAVIOR ALERT)
// ==========================================================
class ManagerAlertsTab extends StatelessWidget {
  const ManagerAlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulasi Data Pelanggaran (> 120 km/h)
    // Dalam aplikasi nyata, ini diambil dari query MongoDB: { speed: { $gt: 120 } }
    final List<Map<String, dynamic>> alerts = [
      {
        "mobil": "Toyota Innova (H 1234 XY)",
        "driver": "Pak Budi",
        "speed": 125.5,
        "waktu": "Hari ini, 10:45 WIB",
        "lokasi": "Tol Gayamsari"
      },
      {
        "mobil": "Mitsubishi Pajero (H 9999 AB)",
        "driver": "Pak Joko",
        "speed": 132.0,
        "waktu": "Kemarin, 14:20 WIB",
        "lokasi": "Tol Tembalang"
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        var alert = alerts[index];
        return Card(
          color: Colors.red[50], // Latar belakang merah muda (Tanda Bahaya)
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.red, width: 2), // Garis tepi merah
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.red, size: 40),
            title: Text("OVERSPEED DETECTED: ${alert['speed']} km/h", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text("Kendaraan: ${alert['mobil']}"),
                Text("Sopir: ${alert['driver']}"),
                Text("Waktu: ${alert['waktu']}"),
                Text("Lokasi: ${alert['lokasi']}"),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () {
                // Tombol untuk menandai laporan sudah dibaca/ditindaklanjuti
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan ditandai selesai.")));
              },
            ),
          ),
        );
      },
    );
  }
}
