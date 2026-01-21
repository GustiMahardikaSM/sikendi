import 'dart:async'; // Timer untuk refresh data otomatis
import 'package:flutter/material.dart'; // UI Standar
import 'package:flutter_map/flutter_map.dart'; // Peta
import 'package:latlong2/latlong.dart'; // Koordinat
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
  int _selectedIndex = 0;
  
  // 1. Buat variabel state lokal untuk menampung ID
  String? _currentFocusId;

  @override
  void initState() {
    super.initState();
    // 2. Salin dari widget (param) ke state lokal saat pertama kali
    _currentFocusId = widget.focusDeviceId;
    
    // Jika ada request tracking, paksa buka tab 0
    if (_currentFocusId != null || widget.initialCenter != null) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Daftar halaman
    final List<Widget> pages = [
      // TAB 0: MONITORING
      ManagerDashboardTab(
        // Kirim ID dari state lokal (yang nanti bisa kita null-kan)
        focusDeviceId: _currentFocusId, 
        initialCenter: widget.initialCenter, // Koordinat masih boleh tetap
        
        // 3. Callback: Saat dashboard selesai memakai ID ini, hapus dari state induk
        onConsumeId: () {
          // Cek dulu apakah _currentFocusId masih ada isinya agar tidak setState berulang kali
          if (_currentFocusId != null) {
            // Gunakan addPostFrameCallback agar tidak error saat build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentFocusId = null; // HAPUS ID DARI MEMORI
                });
              }
            });
          }
        },
      ),
      const ManagerVehicleManagementTab(),
      const ManagerDriversTab(),
      const ManagerAlertsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Dashboard SiKenDi"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
  final VoidCallback? onConsumeId; // &lt;--- Parameter Baru

  const ManagerDashboardTab({
    super.key, 
    this.initialCenter, 
    this.focusDeviceId,
    this.onConsumeId, // &lt;--- Terima di sini
  });

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _activeVehicles = [];
  Timer? _timer;
  
  bool _isTrackingMode = false;
  String? _localFocusId; // Variabel lokal untuk tab ini saja

  @override
  void initState() {
    super.initState();
    
    // LOGIKA CONSUME ONCE
    if (widget.focusDeviceId != null) {
      _localFocusId = widget.focusDeviceId;
      _isTrackingMode = true;

      // Panggil callback ke parent: "Tolong lupakan ID ini untuk render berikutnya"
      if (widget.onConsumeId != null) {
        widget.onConsumeId!();
      }
    }

    _fetchFleetData(); 
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchFleetData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // Fungsi Fetch Data (Disatukan logika trackingnya di sini)
  Future<void> _fetchFleetData() async {
    final data = await MongoService.getFleetDataForManager();
    
    if (mounted) {
      setState(() {
        _activeVehicles = data;
      });

      // LOGIKA AUTO-FOLLOW (Jalan setiap 5 detik jika mode tracking aktif)
      if (_isTrackingMode && _localFocusId != null) {
        try {
          // Cari mobil yang sedang ditrack di dalam list data terbaru
          final targetCar = _activeVehicles.firstWhere(
            (v) => v['device_id'] == _localFocusId || v['gps_1'] == _localFocusId,
            orElse: () => <String, dynamic>{},
          );

          if (targetCar.isNotEmpty) {
            final LatLng? pos = _parseLocation(targetCar);
            if (pos != null) {
              // Paksakan kamera peta pindah ke lokasi mobil baru
              // Zoom 18.0 (Close up)
              _mapController.move(pos, 18.0);
            }
          }
        } catch (e) {
          // Cegah error jika map controller belum siap
          print("Map not ready for move: $e");
        }
      }
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

  // Helper function
  Color _getStatusColor(double speed, String? timestamp) {
    if (_isGpsOffline(timestamp)) return Colors.red; 
    if (speed > 5) return Colors.green; 
    return Colors.orange; 
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
  
  void _showVehicleDetail(BuildContext context, Map<String, dynamic> vehicle) {
    // 1. Ambil Nama & Identitas
    String displayName = vehicle['plat'] ?? vehicle['model'] ?? vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown Device";
    String? plat = vehicle['plat'];
    String? model = vehicle['model'];
    String deviceId = vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown";
    
    // 2. Ambil Data Statistik
    double speed = (vehicle['speed'] as num? ?? 0).toDouble();
    String? timestamp = vehicle['server_received_at']?.toString();
    
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

  @override
  Widget build(BuildContext context) {
    return _activeVehicles.isEmpty
        ? const Center(child: Text("Memuat data armada..."))
        : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Gunakan widget.initialCenter hanya jika Tracking Mode aktif
              // Jika tidak (tracking sudah mati), biarkan map menggunakan posisi default/terakhir
              initialCenter: (_isTrackingMode && widget.initialCenter != null) 
                  ? widget.initialCenter! 
                  : const LatLng(-7.052219, 110.441481), 
              
              initialZoom: (_isTrackingMode && widget.initialCenter != null) ? 18.0 : 14.0,

              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isTrackingMode) {
                  setState(() {
                    _isTrackingMode = false;     
                    _localFocusId = null;      
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sikendi.manager',
              ),
              MarkerLayer(
                markers: _activeVehicles.map((vehicle) {
                  final LatLng? position = _parseLocation(vehicle);
                  if (position == null) return const Marker(point: LatLng(0,0), child: SizedBox());

                  double speed = (vehicle['speed'] as num? ?? 0).toDouble();
                  String? timestamp = vehicle['server_received_at']?.toString();
                  String label = vehicle['plat'] ?? vehicle['model'] ?? vehicle['gps_1'] ?? "?";
                  
                  bool isFocused = _isTrackingMode && 
                                   _localFocusId != null && 
                                   (vehicle['gps_1'] == _localFocusId || vehicle['device_id'] == _localFocusId);

                  return Marker(
                    point: position,
                    width: isFocused ? 80 : 60, // Mark Besar jika tracking
                    height: isFocused ? 80 : 60,
                    child: GestureDetector(
                      onTap: () => _showVehicleDetail(context, vehicle),
                      child: Column(
                        children: [
                          // Label Plat Nomor (Kuning jika tracking, Putih jika biasa)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                               color: isFocused ? Colors.yellow : Colors.white, 
                               borderRadius: BorderRadius.circular(4),
                               border: Border.all(color: Colors.black12)
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 8, 
                                fontWeight: FontWeight.bold,
                                color: Colors.black // Teks selalu hitam agar terbaca
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Icon Mobil
                          Icon(
                            Icons.directions_car_filled,
                            color: _getStatusColor(speed, timestamp),
                            size: isFocused ? 50 : 40, // Icon membesar jika tracking
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
