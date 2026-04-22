import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/driver_incoming_task_page.dart';
import 'package:sikendi/driver_tracking_page.dart';
import 'package:sikendi/main.dart';
import 'package:sikendi/driver_page.dart';
import 'package:intl/intl.dart';

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

  // Helper: Menampilkan Gambar (URL vs Base64) - Logika sama dengan VehicleDetailPage
  ImageProvider? _getImageProvider(String? fotoData) {
    if (fotoData == null || fotoData.isEmpty) {
      return null;
    }

    try {
      if (fotoData.startsWith('BASE64:')) {
        String rawBase64 = fotoData.substring(7); // Buang prefix 'BASE64:'
        return MemoryImage(base64Decode(rawBase64));
      } else if (fotoData.startsWith('http')) {
        return NetworkImage(fotoData);
      }
    } catch (e) {
      debugPrint("Error loading image: $e");
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Informasi Tugas"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Jika kita punya data user lengkap, langsung ke DriverPage
            if (widget.user.containsKey('nama') || widget.user.containsKey('nama_lengkap')) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => DriverPage(user: widget.user)),
                (route) => false,
              );
            } else {
              // Jika data user kosong (dari notifikasi), ambil dulu dari storage
              final currentUser = await AuthService.getCurrentUser();
              if (context.mounted) {
                if (currentUser != null) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => DriverPage(user: currentUser)),
                    (route) => false,
                  );
                } else {
                  // Fallback terakhir jika benar-benar tidak ada session
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                    (route) => false,
                  );
                }
              }
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tugas == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_late,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tidak ada tugas saat ini.",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tugas!['konfirmasi_sopir'] == 'pending'
                        ? "Tugas Pending"
                        : "Tugas Saat Ini",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FOTO MOBIL (Logika sama dengan VehicleDetailPage)
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              image: (_tugas!['foto_url'] != null &&
                                      _tugas!['foto_url'].toString().isNotEmpty &&
                                      _getImageProvider(_tugas!['foto_url'].toString()) != null)
                                  ? DecorationImage(
                                      image: _getImageProvider(_tugas!['foto_url'].toString())!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (_tugas!['foto_url'] == null ||
                                    _tugas!['foto_url'].toString().isEmpty ||
                                    _getImageProvider(_tugas!['foto_url'].toString()) == null)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.directions_car, size: 60, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Foto Mobil Belum Tersedia",
                                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.directions_car, color: Colors.blue[700], size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Kendaraan", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    Text("${_tugas!['model']} (${_tugas!['plat']})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              const Text("Status", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _tugas!['konfirmasi_sopir'] == 'pending' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tugas!['konfirmasi_sopir'] == 'pending' ? Icons.access_time : Icons.check_circle,
                                  color: _tugas!['konfirmasi_sopir'] == 'pending' ? Colors.orange[800] : Colors.green[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _tugas!['konfirmasi_sopir'] == 'pending' ? "Menunggu Konfirmasi" : "Sedang Dijalankan",
                                  style: TextStyle(
                                    color: _tugas!['konfirmasi_sopir'] == 'pending' ? Colors.orange[800] : Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.access_time_filled, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              const Text("Waktu Penugasan", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tugas!['waktu_ambil'] != null
                                ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(_tugas!['waktu_ambil']).toLocal())
                                : '-',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Row(
                            children: [
                              Icon(Icons.assignment, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              const Text("Deskripsi Tugas", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _tugas!['tugas'] ?? 'Tidak ada detail tugas',
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_tugas!['konfirmasi_sopir'] == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverIncomingTaskPage(
                                tugas: _tugas!,
                                onDecision: _loadTugas,
                                user: widget.user,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "Tanggapi Penugasan",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.blue[800],
                        ),
                        onPressed: () {
                          final deviceId =
                              _tugas!['deviceId']?.toString() ??
                              _tugas!['device_id']?.toString() ??
                              _tugas!['gps_1']?.toString() ??
                              '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DriverTrackingPage(deviceId: deviceId),
                            ),
                          );
                        },
                        child: const Text(
                          "Buka Tracking GPS",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
