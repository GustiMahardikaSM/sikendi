import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sikendi/jadwal_sopir_page.dart';
import 'package:sikendi/mongodb_service.dart';

// ==========================================================
// KELAS UTAMA HALAMAN SOPIR
// ==========================================================
class DriverPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DriverPage({super.key, required this.user});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  int _selectedIndex = 0;
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
            DriverTrackingTab(user: widget.user),
      DriverVehicleTab(user: widget.user), // Pass user data
      JadwalSopirPage(email: widget.user['email']), // Use the new schedule page
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
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Kendaraan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Jadwal',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// ==========================================================
// TAB 1: TRACKING & NOTIFIKASI SAFETY (REFACTORED)
// ==========================================================
class DriverTrackingTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const DriverTrackingTab({super.key, required this.user});

  @override
  State<DriverTrackingTab> createState() => _DriverTrackingTabState();
}

class _DriverTrackingTabState extends State<DriverTrackingTab> with AutomaticKeepAliveClientMixin {
  LatLng? _currentPosition;
  double _currentSpeed = 0.0;
  Timer? _timer;

  final double _speedLimit = 60.0;
  bool _isOverspeeding = false;

  // New properties
  final LatLng _widyapurayaUndip = LatLng(-7.0488231, 110.4380076);
  bool _hasVehicle = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = null; // Show loading indicator initially
    _checkIfVehicleAssigned();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_hasVehicle) {
        _fetchData();
      }
    });
  }

  void _checkIfVehicleAssigned() async {
    final myJobs = await MongoService.getPekerjaanSaya(widget.user['nama_lengkap'] as String? ?? '');
    if (mounted) {
      if (myJobs.isNotEmpty) {
        setState(() {
          _hasVehicle = true;
        });
        _fetchData(); // Fetch the current location of the vehicle
      } else {
        setState(() {
          _hasVehicle = false;
          _currentPosition = _widyapurayaUndip; // Set to default
        });
        // Show the info message after the frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
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
          }
        });
      }
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // We only fetch if the driver has a vehicle, so _hasVehicle should be true here.
    if (!_hasVehicle) return;

    final data = await MongoService.getLatestGpsData();

    if (data != null && mounted) {
      var doc = data;
      if (doc['gps_location'] != null) {
        double lat = (doc['gps_location']['lat'] as num).toDouble();
        double lng = (doc['gps_location']['lng'] as num).toDouble();
        double speed = (doc['speed'] as num? ?? 0).toDouble();

        setState(() {
          _currentPosition = LatLng(lat, lng);
          _currentSpeed = speed;

          if (_currentSpeed > _speedLimit) {
            if (!_isOverspeeding) {
              _isOverspeeding = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 1),
                  content: Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 10),
                      Text("BAHAYA! Anda melewati batas kecepatan!", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }
          } else {
            _isOverspeeding = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
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
                  if (_hasVehicle && _currentPosition != null) // Only show marker if there is a vehicle
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
        if (_hasVehicle) // Only show speed if there is a vehicle
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
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ==========================================================
// TAB 2: MANAJEMEN TANGGUNG JAWAB (REFACTORED with MongoService)
// ==========================================================
class DriverVehicleTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const DriverVehicleTab({super.key, required this.user});

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
    setState(() {
      _vehiclesFuture = MongoService.getKendaraanTersedia();
      // Also check if the driver already has an active job
      _loadMyJob(); 
    });
  }

  // Load the current driver's active job
  void _loadMyJob() async {
    final myJobs = await MongoService.getPekerjaanSaya(widget.user['nama_lengkap']);
    if(myJobs.isNotEmpty && mounted) {
      setState(() {
        _selectedCar = myJobs.first;
      });
    }
  }

  void _handleCheckIn(Map<String, dynamic> car) async {
    final namaSopir = widget.user['nama_lengkap'] as String? ?? 'Nama Tidak Ditemukan';
    final carId = car['_id'] as mongo.ObjectId;

    await MongoService.ambilKendaraan(carId, namaSopir);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text("Berhasil Check-in: ${car['model']}"),
        ),
      );
    }
    _loadVehicles(); // Refresh both available list and my job
  }

  void _handleCheckOut() async {
    if (_selectedCar == null) return;
    final carId = _selectedCar!['_id'] as mongo.ObjectId;

    await MongoService.selesaikanPekerjaan(carId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berhasil Check-out kendaraan.")),
      );
    }

    setState(() {
      _selectedCar = null; // Clear the selected car
    });
    _loadVehicles(); // Refresh the list
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

          if (_selectedCar == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: const [
                  Icon(Icons.no_crash, size: 50, color: Colors.grey),
                  Text("Anda belum memilih kendaraan."),
                  Text("Silakan pilih kendaraan di bawah untuk Check-in."),
                ],
              ),
            )
          else
            Card(
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
                        onPressed: _handleCheckOut,
                      ),
                    )
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daftar Kendaraan Tersedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadVehicles,
                tooltip: "Muat Ulang",
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          onPressed: (_selectedCar == null) ? () => _handleCheckIn(car) : null,
                          child: const Text("Pilih"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}