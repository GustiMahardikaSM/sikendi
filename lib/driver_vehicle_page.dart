import 'package:flutter/material.dart';
import 'package:sikendi/vehicle_api_service.dart';
import 'package:dotted_border/dotted_border.dart';

class DriverVehiclePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const DriverVehiclePage({super.key, required this.user});

  @override
  State<DriverVehiclePage> createState() => _DriverVehiclePageState();
}

class _DriverVehiclePageState extends State<DriverVehiclePage> {
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;
  Map<String, dynamic>? _selectedCar;
  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = VehicleApiService.getKendaraanTersedia();
      _loadMyJob(); 
    });
  }

  void _loadMyJob() async {
    final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'];
    if (namaSopir != null) {
      final myJobs = await VehicleApiService.getPekerjaanSaya(namaSopir);
      if(mounted) {
        setState(() {
          if (myJobs.isNotEmpty) {
            _selectedCar = myJobs.first;
          } else {
            _selectedCar = null;
          }
        });
      }
    }
  }

  void _handleCheckIn(Map<String, dynamic> car) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? 'Nama Tidak Ditemukan';
      final carId = car['gps_1']?.toString() ?? car['device_id']?.toString() ?? ''; 
      
      if (carId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: ID Kendaraan tidak valid"), backgroundColor: Colors.red));
        return;
      }

      bool success = await VehicleApiService.ambilKendaraan(carId, namaSopir);
      
      if (success && mounted) {
        setState(() {
          _selectedCar = Map<String, dynamic>.from(car);
          _selectedCar!['status'] = 'Dipakai';
          _selectedCar!['peminjam'] = namaSopir;
        });
        
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

  void _handleCheckOut() async {
    if (_selectedCar == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final carId = _selectedCar!['gps_1']?.toString() ?? _selectedCar!['device_id']?.toString() ?? '';
      if (carId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: ID Kendaraan tidak valid"), backgroundColor: Colors.red));
        return;
      }

      await VehicleApiService.selesaikanPekerjaan(carId);
      
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pilih Kendaraan',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Status Tanggung Jawab", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (_selectedCar == null)
                  DottedBorder(
                    color: Colors.blue.withOpacity(0.3),
                    strokeWidth: 2,
                    dashPattern: const [8, 4],
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.no_crash_outlined, size: 48, color: Colors.blue.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            "Anda belum memilih kendaraan.",
                            style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w500),
                          ),
                          const Text(
                            "Silakan pilih kendaraan di bawah untuk Check-in.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.blue[100]!),
                    ),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.directions_car, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "KENDARAAN AKTIF", 
                                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                    Text(
                                      _selectedCar!['model']!, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    Text(
                                      _selectedCar!['plat']!, 
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _isLoading 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.exit_to_app),
                              label: Text(_isLoading ? "MEMPROSES..." : "LEPAS TANGGUNG JAWAB (Check-out)"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _isLoading ? null : _handleCheckOut,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                const Text(
                  "Daftar Kendaraan Tersedia", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons. car_repair, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("Tidak ada kendaraan tersedia saat ini.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final vehicles = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    _loadVehicles();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      var car = vehicles[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.car_rental, color: Colors.green),
                          ),
                          title: Text(car['model']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Text(car['plat']!, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                _buildStatusBadge(car['status'] ?? 'Tersedia'),
                              ],
                            ),
                          ),
                          trailing: SizedBox(
                            width: 80,
                            child: ElevatedButton(
                              onPressed: (_selectedCar == null && !_isLoading) ? () => _handleCheckIn(car) : null,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text("Pilih", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    if (status.toLowerCase().contains('perbaikan')) color = Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(), 
        style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)
      ),
    );
  }
}
