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
  final LatLng? initialCenter;
  final String? focusDeviceId;

  const ManagerPage({super.key, this.initialCenter, this.focusDeviceId});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  int _selectedIndex = 0; // Mengatur Tab yang aktif

  // Daftar Tab Halaman
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Jika ada initialCenter, pastikan tab monitor yang terbuka
    if (widget.initialCenter != null) {
      _selectedIndex = 0;
    }
    _pages = <Widget>[
      ManagerDashboardTab(
        initialCenter: widget.initialCenter,
        focusDeviceId: widget.focusDeviceId,
      ), // Tab 0: Peta Monitoring Armada
      const ManagerVehicleManagementTab(), // Tab 1: Manajemen Kendaraan
      const ManagerDriversTab(),   // Tab 2: Daftar & Profil Sopir
      const ManagerAlertsTab(),    // Tab 3: Peringatan (Alert System)
    ];
  }


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
  final LatLng? initialCenter;
  final String? focusDeviceId;

  const ManagerDashboardTab({super.key, this.initialCenter, this.focusDeviceId});

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  final MapController _mapController = MapController();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCenter != null) {
        _mapController.move(widget.initialCenter!, 16.0);
      }
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

  // POP-UP DETAIL KENDARAAN (DIPERBAIKI)
  void _showVehicleDetail(BuildContext context, Map<String, dynamic> vehicle) {
    // 1. Ambil Nama & Identitas
    String displayName = vehicle['plat'] ?? vehicle['model'] ?? vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown Device";
    String? plat = vehicle['plat'];
    String? model = vehicle['model'];
    String deviceId = vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown";
    
    // 2. Ambil Data Statistik
    double speed = (vehicle['speed'] as num? ?? 0).toDouble();
    String? timestamp = vehicle['server_received_at']?.toString();
    
    // 3. AMBIL KOORDINAT DENGAN CARA AMAN (Menggunakan fungsi helper _parseLocation)
    // Jika Anda belum membuat _parseLocation, lihat instruksi di bawah kode ini*
    LatLng? pos = _parseLocation(vehicle); 
    
    double lat = pos?.latitude ?? 0.0;
    double lng = pos?.longitude ?? 0.0;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 350, // Sedikit dipertinggi agar muat
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Ikon & Nama Mobil
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 30, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (plat != null && model != null)
                          Text("$model • $plat", style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                        else
                          Text("ID: $deviceId", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // Item 1: Kecepatan
              ListTile(
                dense: true,
                leading: const Icon(Icons.speed),
                title: Text("${speed.toStringAsFixed(1)} km/h"),
                subtitle: Text(
                  _getStatusText(speed, timestamp), 
                  style: TextStyle(
                    color: _getStatusColor(speed, timestamp),
                    fontWeight: FontWeight.bold
                  )
                ),
              ),

              // Item 2: Waktu Update
              ListTile(
                dense: true,
                leading: const Icon(Icons.access_time),
                title: const Text("Terakhir Update"),
                subtitle: Text(timestamp != null 
                    ? DateTime.parse(timestamp).toLocal().toString().split('.')[0] 
                    : "-"),
              ),

              // Item 3: Koordinat (YANG DIPERBAIKI)
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_on),
                title: const Text("Posisi Koordinat"),
                // Tampilkan lat, lng dengan 6 angka di belakang koma agar rapi
                subtitle: Text("${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}"),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                     // Opsional: Copy koordinat ke clipboard
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Koordinat disalin!"))
                     );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Tambahkan fungsi helper ini di dalam class _ManagerDashboardTabState
  // Fungsinya: Mencari koordinat dengan segala cara (GeoJSON atau Key-Value)
  LatLng? _parseLocation(Map<String, dynamic> vehicle) {
    try {
      // Cek 1: Apakah ada field 'gps_location'?
      if (vehicle['gps_location'] != null) {
        final loc = vehicle['gps_location'];
        
        // Format A: { "lat": -7.0, "lng": 110.0 } (Standar Key-Value)
        if (loc is Map && loc.containsKey('lat') && loc.containsKey('lng')) {
          return LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
        
        // Format B: GeoJSON { "coordinates": [110.0, -7.0] } (Perhatikan: Lng dulu!)
        if (loc is Map && loc.containsKey('coordinates')) {
          final List coords = loc['coordinates'];
          if (coords.length >= 2) {
            return LatLng(
              (coords[1] as num).toDouble(), // Index 1 = Latitude
              (coords[0] as num).toDouble(), // Index 0 = Longitude
            );
          }
        }
      }
      
      // Cek 2: Apakah lat/lng ada langsung di root dokumen?
      if (vehicle.containsKey('lat') && vehicle.containsKey('lng')) {
        return LatLng(
          (vehicle['lat'] as num).toDouble(),
          (vehicle['lng'] as num).toDouble(),
        );
      }
    } catch (e) {
      print("Error parsing lokasi untuk ${vehicle['plat']}: $e");
    }
    return null; // Gagal mendapatkan lokasi
  }

  @override
  Widget build(BuildContext context) {
    return _activeVehicles.isEmpty
        ? const Center(child: Text("Memuat data armada..."))
        : FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-7.052219, 110.441481), // Default Undip
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sikendi.manager',
              ),
              MarkerLayer(
                markers: _activeVehicles.map((vehicle) {
                  // GUNAKAN FUNGSI HELPER BARU KITA
                  final LatLng? position = _parseLocation(vehicle);
                  
                  // Jika posisi null (tidak ada data GPS), JANGAN buat marker (skip)
                  if (position == null) {
                    return const Marker(
                      point: LatLng(0, 0), 
                      child: SizedBox(), // Marker kosong tak terlihat
                    ); 
                  }

                  // Ambil data lainnya
                  double speed = (vehicle['speed'] as num? ?? 0).toDouble();
                  String? timestamp = vehicle['server_received_at']?.toString();
                  String label = vehicle['plat'] ?? vehicle['model'] ?? vehicle['gps_1'] ?? "?";

                  return Marker(
                    point: position, // Gunakan posisi yang valid
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
                              label,
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
// TAB 2: DETAIL PENGEMUDI (KARTU DRIVER) - dari MongoDB
// ==========================================================
class ManagerDriversTab extends StatefulWidget {
  const ManagerDriversTab({super.key});

  @override
  State<ManagerDriversTab> createState() => _ManagerDriversTabState();
}

class _ManagerDriversTabState extends State<ManagerDriversTab> {
  late Future<List<Map<String, dynamic>>> _driversFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _driversFuture = MongoService.getSemuaSopir();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  // Fungsi untuk memfilter driver berdasarkan nama
  List<Map<String, dynamic>> _filterDrivers(List<Map<String, dynamic>> drivers) {
    if (_searchQuery.isEmpty) {
      return drivers;
    }

    return drivers.where((driver) {
      final nama = (driver['nama_lengkap'] ?? '').toString().toLowerCase().replaceAll(' ', '');
      final searchQueryNoSpace = _searchQuery.replaceAll(' ', '');
      return nama.contains(searchQueryNoSpace);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _driversFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat data sopir: ${snapshot.error}'));
        }
        final allDrivers = snapshot.data ?? [];
        final drivers = _filterDrivers(allDrivers);

        return CustomScrollView(
          slivers: [
            // Search Bar di bagian atas
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama driver...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Daftar Driver
            if (drivers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? "Tidak ada driver yang cocok dengan pencarian \"$_searchQuery\""
                            : "Tidak ada data sopir.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final drv = drivers[index];
                      final nama = (drv['nama_lengkap'] ?? '').toString();
                      final email = (drv['email'] ?? '').toString();
                      final noHp = (drv['no_hp'] ?? '').toString();
                      final role = (drv['role'] ?? 'Sopir').toString();

                      final inisial = nama.isNotEmpty ? nama[0] : '?';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(child: Text(inisial)), // Inisial Nama
                          title: Text(nama.isNotEmpty ? nama : '(Nama belum diisi)',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$email • $role'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Detail Sopir', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text('Nama Lengkap : ${nama.isNotEmpty ? nama : '-'}'),
                                  Text('Email        : ${email.isNotEmpty ? email : '-'}'),
                                  Text('No. HP       : ${noHp.isNotEmpty ? noHp : '-'}'),
                                  
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: drivers.length,
                  ),
                ),
              ),
          ],
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
