import 'package:flutter/material.dart';
import 'package:sikendi/driver_tracking_page.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/jadwal_sopir_page.dart';
import 'package:sikendi/main.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/profile_sopir_page.dart'; 
import 'package:sikendi/driver_tugas_page.dart';
import 'package:sikendi/driver_incoming_task_page.dart';

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
  String _currentStatus = "Sedang memuat...";
  bool _hasPendingTask = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentTask();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Fungsi untuk mengecek status tugas saat halaman dibuka atau di-refresh
  Future<void> _checkCurrentTask() async {
    final nama = widget.user['nama'] ?? widget.user['nama_lengkap'];
    if (nama != null) {
      final tugas = await MongoDBService.getTugasSekarang(nama);
      if (mounted) {
        if (tugas == null) {
          setState(() {
            _currentStatus = "Tidak ada tugas";
            _hasPendingTask = false;
          });
        } else if (tugas['konfirmasi_sopir'] == 'pending') {
          setState(() {
            _currentStatus = "Ada tugas perlu konfirmasi!";
            _hasPendingTask = true;
          });
        } else if (tugas['konfirmasi_sopir'] == 'accepted') {
          setState(() {
            _currentStatus = "Sedang bertugas";
            _hasPendingTask = false;
          });
        }
      }
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text(
          "Apakah Anda yakin ingin keluar? Tracking akan berhenti.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Hapus token JWT & nama sopir dari storage
              AuthService.logout();
              Navigator.of(ctx).pop();

              // Kembali ke halaman awal & hapus riwayat navigasi
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionPage(),
                ),
                (route) => false,
              );
            },
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definisi Menu Items di dalam build agar bisa akses context & widget.user
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Informasi Tugas',
        'icon': Icons.assignment,
        'color': Colors.green,
        'hasBadge': _hasPendingTask,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverTugasPage(user: widget.user),
            ),
          );
        },
      },
      {
        'title': 'Tracking GPS',
        'icon': Icons.map_outlined,
        'color': Colors.blueAccent,
        'onTap': () async {
          // Tampilkan loading sebentar saat mengecek database
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          final namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'];
          String? idMobilDipinjam;

          if (namaSopir != null) {
            final tugas = await MongoDBService.getTugasSekarang(namaSopir);
            if (tugas != null && tugas['konfirmasi_sopir'] == 'accepted') {
              idMobilDipinjam = tugas['deviceId']?.toString() ?? tugas['device_id']?.toString() ?? tugas['gps_1']?.toString();
            }
          }

          if (context.mounted) Navigator.pop(context); // Tutup loading

          if (idMobilDipinjam != null && idMobilDipinjam.isNotEmpty) {
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => DriverTrackingPage(deviceId: idMobilDipinjam!)));
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Anda belum menerima tugas apapun. Cek 'Informasi Tugas'."), backgroundColor: Colors.orange),
              );
            }
          }
        },
      },
      {
        'title': 'Jadwal Perjalanan',
        'icon': Icons.calendar_today,
        'color': Colors.orange,
        'onTap': () {
          // Mengirim email sopir untuk filter jadwal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JadwalSopirPage(email: widget.user['email']),
            ),
          );
        },
      },
      {
        'title': 'Profil Saya',
        'icon': Icons.person, // Ikon profil
        'color': Colors.purple, // Warna yang berbeda agar menarik
        'onTap': () {
          // Navigasi ke halaman profil sambil membawa data user
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSopirPage(user: widget.user),
            ),
          );
        },
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Sopir SiKenDi"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkCurrentTask,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- MULAI HEADER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Selamat bertugas,",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.user['nama'] ?? widget.user['nama_lengkap'] ?? 'Sopir',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.badge, color: Colors.white70, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "Sopir Kendaraan Dinas - Undip",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentStatus == "Ada tugas perlu konfirmasi!"
                              ? Colors.red
                              : _currentStatus == "Sedang bertugas"
                                  ? Colors.green
                                  : Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Status: $_currentStatus",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // --- AKHIR HEADER ---

                const SizedBox(height: 20), // Jarak antara header dan grid

                // --- MULAI GRIDVIEW ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menuItems.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0, // Kotak 1:1
                    ),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: item['onTap'], // Fungsi navigasi dari Langkah 2
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Lingkaran latar belakang ikon
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: (item['color'] as Color).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      color: item['color'],
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  // Teks Judul Menu
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              if (item['hasBadge'] == true)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      "!",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // --- AKHIR GRIDVIEW ---

                const SizedBox(height: 30), // Ruang kosong di paling bawah
              ],
            ),
          ),
        ),
      ),
    );
  }
}
