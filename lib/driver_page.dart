import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
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
      const DriverTrackingTab(),
      DriverVehicleTab(user: widget.user), // Pass user data
      const DriverScheduleTab(),
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
  const DriverTrackingTab({super.key});

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
    // Logic now uses the centralized MongoService
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


// ==========================================================
// TAB 3: INFORMASI JADWAL PENUGASAN (UNCHANGED)
// ==========================================================
class DriverScheduleTab extends StatefulWidget {
  const DriverScheduleTab({super.key});

  @override
  State<DriverScheduleTab> createState() => _DriverScheduleTabState();
}

class _DriverScheduleTabState extends State<DriverScheduleTab> with AutomaticKeepAliveClientMixin {
  // Data dummy ini tidak diubah sesuai instruksi
  final List<Map<String, String>> _schedules = [
    {"tanggal": "29 Des 2025", "waktu": "08:00 WIB", "tugas": "Antar Wakil Rektor II ke Rektorat", "status": "Selesai"},
    {"tanggal": "30 Des 2025", "waktu": "09:30 WIB", "tugas": "Jemput Tamu Fakultas Teknik di Bandara", "status": "Akan Datang"},
    {"tanggal": "31 Des 2025", "waktu": "13:00 WIB", "tugas": "Operasional Logistik KBAUK", "status": "Menunggu Persetujuan"},
  ];

  void _addSchedule() {
    final TextEditingController tugasController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text("Tambah Jadwal Baru"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tugasController,
                    decoration: const InputDecoration(labelText: "Tugas"),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null && picked != selectedDate) {
                              setState(() { selectedDate = picked; });
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(selectedDate == null ? "Pilih Tanggal" : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (picked != null && picked != selectedTime) {
                              setState(() { selectedTime = picked; });
                            }
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime == null ? "Pilih Waktu" : selectedTime!.format(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () {
                    if (tugasController.text.isNotEmpty && selectedDate != null && selectedTime != null) {
                      final String formattedDate = "${selectedDate!.day} ${_getBulan(selectedDate!.month)} ${selectedDate!.year}";
                      final String formattedTime = selectedTime!.format(context);
                      
                      this.setState(() {
                        _schedules.add({
                          "tugas": tugasController.text, "tanggal": formattedDate, "waktu": formattedTime, "status": "Akan Datang",
                        });
                      });
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getBulan(int month) {
    const bulan = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"];
    return bulan[month - 1];
  }

  void _deleteSchedule(int index) {
    setState(() {
      _schedules.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jadwal berhasil dihapus.")));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          var item = _schedules[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item['status'] == "Selesai" ? Colors.green : Colors.orange,
                child: const Icon(Icons.schedule, color: Colors.white),
              ),
              title: Text(item['tugas']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text("${item['tanggal']} • ${item['waktu']}"),
                  Text("Status: ${item['status']}", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteSchedule(index),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        tooltip: 'Tambah Jadwal',
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}