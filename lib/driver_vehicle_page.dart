import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sikendi/mongodb_service.dart';

class DriverVehiclePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const DriverVehiclePage({super.key, required this.user});

  @override
  State<DriverVehiclePage> createState() => _DriverVehiclePageState();
}

class _DriverVehiclePageState extends State<DriverVehiclePage> {
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;
  Map<String, dynamic>? _selectedCar;
  bool _isLoading = false; // State untuk buffering/loading

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = MongoDBService.getKendaraanTersedia();
      _loadMyJob(); 
    });
  }

  void _loadMyJob() async {
    // Menggunakan 'nama' atau 'nama_lengkap' untuk kompatibilitas
    final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'];
    if (namaSopir != null) {
      final myJobs = await MongoDBService.getPekerjaanSaya(namaSopir);
      if(myJobs.isNotEmpty && mounted) {
        setState(() {
          _selectedCar = myJobs.first;
        });
      }
    }
  }

  // --- MODIFIKASI: Tambahkan state buffering & delay ---
  void _handleCheckIn(Map<String, dynamic> car) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? 'Nama Tidak Ditemukan';
      final carId = car['_id'] as mongo.ObjectId;

      await MongoDBService.ambilKendaraan(carId, namaSopir);
      
      // Jeda untuk memastikan database selesai commit sebelum UI me-refresh
      await Future.delayed(const Duration(milliseconds: 300)); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text("Berhasil Check-in: ${car['model']}"),
          ),
        );
      }
      _loadVehicles();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- MODIFIKASI: Tambahkan state buffering & delay ---
  void _handleCheckOut() async {
    if (_selectedCar == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final carId = _selectedCar!['_id'] as mongo.ObjectId;

      await MongoDBService.selesaikanPekerjaan(carId);
      
      // Jeda untuk memastikan database selesai commit sebelum UI me-refresh
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil Check-out kendaraan.")),
        );
        setState(() {
          _selectedCar = null; 
        });
      }
      _loadVehicles();
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Kendaraan'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      // --- MODIFIKASI: Gunakan Stack untuk overlay loading ---
      body: Stack(
        children: [
          Padding(
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
                    child: const Column(
                      children: [
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
                            // --- MODIFIKASI: Disable tombol saat loading ---
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.exit_to_app),
                              label: const Text("LEPAS TANGGUNG JAWAB (Check-out)"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: _isLoading ? null : _handleCheckOut,
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
                    // --- MODIFIKASI: Disable tombol saat loading ---
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _loadVehicles,
                      tooltip: "Muat Ulang",
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _vehiclesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
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
                              // --- MODIFIKASI: Disable tombol saat loading atau sudah ada mobil dipilih ---
                              trailing: ElevatedButton(
                                onPressed: (_selectedCar == null && !_isLoading) ? () => _handleCheckIn(car) : null,
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
          ),
          // --- MODIFIKASI: Tampilkan overlay loading ---
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Menyimpan...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
