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

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = MongoService.getKendaraanTersedia();
      _loadMyJob(); 
    });
  }

  void _loadMyJob() async {
    // Menggunakan 'nama' atau 'nama_lengkap' untuk kompatibilitas
    final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'];
    if (namaSopir != null) {
      final myJobs = await MongoService.getPekerjaanSaya(namaSopir);
      if(myJobs.isNotEmpty && mounted) {
        setState(() {
          _selectedCar = myJobs.first;
        });
      }
    }
  }

  void _handleCheckIn(Map<String, dynamic> car) async {
    final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? 'Nama Tidak Ditemukan';
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
    _loadVehicles(); 
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
      _selectedCar = null; 
    });
    _loadVehicles(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kendaraan & Pekerjaan'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
      ),
    );
  }
}
