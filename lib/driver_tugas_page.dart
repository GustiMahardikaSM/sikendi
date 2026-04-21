import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/driver_incoming_task_page.dart';
import 'package:sikendi/driver_tracking_page.dart';

class DriverTugasPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DriverTugasPage({super.key, required this.user});

  @override
  State<DriverTugasPage> createState() => _DriverTugasPageState();
}

class _DriverTugasPageState extends State<DriverTugasPage> {
  Map<String, dynamic>? _tugas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  Future<void> _loadTugas() async {
    setState(() => _isLoading = true);
    final nama = widget.user['nama'] ?? widget.user['nama_lengkap'];
    if (nama != null) {
      _tugas = await MongoDBService.getTugasSekarang(nama);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Informasi Tugas"), backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _tugas == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_late, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Tidak ada tugas saat ini.", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tugas!['konfirmasi_sopir'] == 'pending' ? "Tugas Pending" : "Tugas Saat Ini",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Kendaraan", style: TextStyle(color: Colors.grey)),
                          Text("${_tugas!['model']} (${_tugas!['plat']})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(height: 30),
                          const Text("Deskripsi Tugas", style: TextStyle(color: Colors.grey)),
                          Text(_tugas!['tugas'] ?? '-', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_tugas!['konfirmasi_sopir'] == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.orange),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DriverIncomingTaskPage(tugas: _tugas!, onDecision: _loadTugas, user: widget.user)
                          ));
                        },
                        child: const Text("Tanggapi Penugasan", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.blue[800]),
                        onPressed: () {
                          final deviceId = _tugas!['deviceId']?.toString() ?? _tugas!['device_id']?.toString() ?? _tugas!['gps_1']?.toString() ?? '';
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTrackingPage(deviceId: deviceId)));
                        },
                        child: const Text("Buka Tracking GPS", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    )
                ],
              ),
            )
    );
  }
}
