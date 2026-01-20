import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sikendi/jadwal_sopir_page.dart';
import 'package:sikendi/mongodb_service.dart';

// ==========================================================
// KELAS UTAMA HALAMAN SOPIR (STATEFUL)
// ==========================================================
class DriverPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DriverPage({super.key, required this.user});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  final MapController _mapController = MapController();

  // =============================================
  // STATE DIANGKAT KE ATAS (LIFTED STATE)
  // =============================================
  LatLng? _currentPosition;
  bool _hasVehicle = false;
  final LatLng _widyapurayaUndip = LatLng(-7.0488231, 110.4380076);
  Timer? _mapUpdateTimer;
  double _currentSpeed = 0.0;
  bool _isOverspeeding = false;
  final double _speedLimit = 60.0;
  // =============================================

  @override
  void initState() {
    super.initState();
    // Initialize pages with default state. They will be rebuilt on state change.
    _buildPages();
    _initializeMapState();
  }

  @override
  void dispose() {
    _mapUpdateTimer?.cancel();
    super.dispose();
  }

  // Membangun ulang daftar halaman dengan state terbaru
  void _buildPages() {
    _pages = <Widget>[
      DriverTrackingTab(
        mapController: _mapController,
        hasVehicle: _hasVehicle,
        currentPosition: _currentPosition,
        widyapurayaUndip: _widyapurayaUndip,
        currentSpeed: _currentSpeed,
        isOverspeeding: _isOverspeeding,
      ),
      DriverVehicleTab(
        user: widget.user,
        onCheckIn: _handleCheckIn, // Mengoper callback
        onCheckOut: _handleCheckOut, // Mengoper callback
      ),
      JadwalSopirPage(email: widget.user['email']),
    ];
  }

  // Cek status kendaraan saat halaman pertama kali dibuka
  void _initializeMapState() async {
    final myJobs = await MongoService.getPekerjaanSaya(widget.user['nama_lengkap'] as String? ?? '');
    if (mounted) {
      if (myJobs.isNotEmpty) {
        _handleCheckIn(); // Sudah punya kendaraan, mulai tracking
      } else {
        _handleCheckOut(); // Belum punya, set state default
      }
    }
  }

  // Mengambil data GPS terbaru
  void _fetchData() async {
    if (!_hasVehicle) return;

    final data = await MongoService.getLatestGpsData();
    if (data != null && mounted) {
      final doc = data;
      if (doc['gps_location'] != null) {
        final lat = (doc['gps_location']['lat'] as num).toDouble();
        final lng = (doc['gps_location']['lng'] as num).toDouble();
        final speed = (doc['speed'] as num? ?? 0).toDouble();

        setState(() {
          _currentPosition = LatLng(lat, lng);
          _currentSpeed = speed;
          _isOverspeeding = speed > _speedLimit;
          _buildPages(); // Rebuild halaman dengan posisi & kecepatan baru

          if (_isOverspeeding) {
             // Throttling snackbar can be added here if it becomes noisy
          }
        });
      }
    }
  }

  // Callback yang dipicu saat sopir Check-in
  void _handleCheckIn() {
    if (!mounted) return;
    
    setState(() {
      _hasVehicle = true;
      _currentPosition = null; // Tampilkan loading indicator sejenak
      _buildPages();
    });

    _fetchData(); // Ambil data segera
    _mapUpdateTimer?.cancel();
    _mapUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchData();
    });
  }

  // Callback yang dipicu saat sopir Check-out
  void _handleCheckOut() {
    if (!mounted) return;

    _mapUpdateTimer?.cancel();
    setState(() {
      _hasVehicle = false;
      _currentPosition = _widyapurayaUndip;
      _currentSpeed = 0.0;
      _isOverspeeding = false;
      _buildPages(); // Rebuild halaman dengan state default
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Setiap kali tab Tracking dibuka, pusatkan ulang peta
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LatLng targetCenter;

        if (_hasVehicle && _currentPosition != null) {
          targetCenter = _currentPosition!;
        } else {
          targetCenter = _widyapurayaUndip;
        }

        // Gunakan zoom default 16.0 (sama seperti initialZoom)
        _mapController.move(targetCenter, 16.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Sopir SiKenDi"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Kendaraan'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Jadwal'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// ==========================================================
// TAB 1: TRACKING (STATELESS)
// ==========================================================
class DriverTrackingTab extends StatelessWidget {
  final MapController mapController;
  final bool hasVehicle;
  final LatLng? currentPosition;
  final LatLng widyapurayaUndip;
  final double currentSpeed;
  final bool isOverspeeding;

  @override
  State<DriverTrackingTab> createState() => _DriverTrackingTabState();
}

class _DriverTrackingTabState extends State<DriverTrackingTab> with AutomaticKeepAliveClientMixin {
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
          // Format A: { "lat": ..., "lng": ... }
          lat = (loc['lat'] as num).toDouble();
          lng = (loc['lng'] as num).toDouble();
        } else if (loc is Map && loc.containsKey('coordinates')) {
          // Format B: GeoJSON { "coordinates": [lng, lat] }
          final List coords = loc['coordinates'];
          if (coords.length >= 2) {
            lng = (coords[0] as num).toDouble();
            lat = (coords[1] as num).toDouble();
          }
        }
      }

      // Fallback: Check for lat/lng at the root level
      if (lat == null && lng == null) {
        if (doc.containsKey('lat') && doc.containsKey('lng')) {
          lat = (doc['lat'] as num).toDouble();
          lng = (doc['lng'] as num).toDouble();
        }
      }
    } catch (e) {
      print("Error parsing location in DriverTrackingTab: $e");
      // Prevent further processing if parsing fails
      return;
    }

    // Only update state if we successfully parsed a location
    if (lat != null && lng != null) {
      final speed = (doc['speed'] as num? ?? 0).toDouble();

      setState(() {
        _currentPosition = LatLng(lat!, lng!);
        _currentSpeed = speed;

        if (_currentSpeed > _speedLimit) {
          if (!_isOverspeeding) {
            _isOverspeeding = true;
            // Avoid showing snackbar if widget is not in the tree
            if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 1),
                  content: Row(
                    children: const [
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
    final displayPosition = currentPosition ?? widyapurayaUndip;
    
    // Tampilkan pesan jika belum ada kendaraan
    if (!hasVehicle && currentPosition == widyapurayaUndip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.blue,
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Anda belum meminjam kendaraan. Peta dipusatkan di lokasi default.")),
              ],
            ),
          ),
        );
      });
    }


    return Stack(
      children: [
        // Tampilkan loading jika punya kendaraan tapi posisi belum didapat
        (hasVehicle && currentPosition == null)
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: displayPosition,
                  initialZoom: 16.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sikendi.driver',
                  ),
                  if (hasVehicle && currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentPosition!,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.directions_car, color: Colors.green, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
        if (hasVehicle)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverspeeding ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
              ),
              child: Column(
                children: [
                  const Text("Kecepatan", style: TextStyle(fontSize: 12)),
                  Text(
                    "${currentSpeed.toStringAsFixed(1)} km/h",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isOverspeeding ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================================
// TAB 2: MANAJEMEN TANGGUNG JAWAB (MODIFIED)
// ==========================================================
class DriverVehicleTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const DriverVehicleTab({
    super.key,
    required this.user,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  State<DriverVehicleTab> createState() => _DriverVehicleTabState();
}

class _DriverVehicleTabState extends State<DriverVehicleTab> with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;
  Map<String, dynamic>? _selectedCar;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    if (!mounted) return;
    setState(() {
      _vehiclesFuture = MongoService.getKendaraanTersedia();
      _loadMyJob();
    });
  }

  void _loadMyJob() async {
    final myJobs = await MongoService.getPekerjaanSaya(widget.user['nama_lengkap']);
    if (myJobs.isNotEmpty && mounted) {
      setState(() {
        _selectedCar = myJobs.first;
      });
    }
  }

  void _handleVehicleCheckIn(Map<String, dynamic> car) async {
    final namaSopir = widget.user['nama_lengkap'] as String? ?? 'Nama Tidak Ditemukan';
    final carId = car['_id'] as mongo.ObjectId;

    await MongoService.ambilKendaraan(carId, namaSopir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text("Berhasil Check-in: ${car['model']}")),
      );
    }
    
    widget.onCheckIn(); // Panggil callback
    _loadVehicles();
  }

  void _handleVehicleCheckOut() async {
    if (_selectedCar == null) return;
    final carId = _selectedCar!['_id'] as mongo.ObjectId;

    await MongoService.selesaikanPekerjaan(carId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berhasil Check-out kendaraan.")),
      );
    }
    
    setState(() {
      _selectedCar = null;
    });

    widget.onCheckOut(); // Panggil callback
    _loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Status Tanggung Jawab", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildMyJobCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daftar Kendaraan Tersedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVehicles, tooltip: "Muat Ulang"),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildAvailableVehiclesList()),
        ],
      ),
    );
  }

  Widget _buildMyJobCard() {
    if (_selectedCar == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: const [
            Icon(Icons.no_crash, size: 50, color: Colors.grey),
            Text("Anda belum memilih kendaraan."),
            Text("Silakan pilih kendaraan di bawah untuk Check-in."),
          ],
        ),
      );
    } else {
      return Card(
        elevation: 4,
        color: Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("KENDARAAN AKTIF", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.directions_car, size: 40, color: Colors.blue),
                title: Text(_selectedCar!['model']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(_selectedCar!['plat']!),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text("LEPAS TANGGUNG JAWAB (Check-out)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _handleVehicleCheckOut,
                ),
              )
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAvailableVehiclesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Tidak ada kendaraan tersedia saat ini."));
        }
        final vehicles = snapshot.data!;
        return ListView.builder(
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            var car = vehicles[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.car_rental, color: Colors.green),
                title: Text(car['model']!),
                subtitle: Text("${car['plat']} • ${car['status']}"),
                trailing: ElevatedButton(
                  onPressed: (_selectedCar == null) ? () => _handleVehicleCheckIn(car) : null,
                  child: const Text("Pilih"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}