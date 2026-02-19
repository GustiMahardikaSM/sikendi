import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sikendi/driver_tracking_page.dart';
import 'package:sikendi/driver_vehicle_page.dart';
import 'package:sikendi/jadwal_sopir_page.dart';
import 'package:sikendi/main.dart';

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
        'title': 'Tracking GPS',
        'icon': Icons.map_outlined,
        'color': Colors.blueAccent,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DriverTrackingPage()),
          );
        },
      },
      {
        'title': 'Pilih Kendaraan',
        'icon': Icons.directions_car_filled,
        'color': Colors.green,
        'onTap': () {
          // Mengirim data user agar sopir bisa check-in
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverVehiclePage(user: widget.user),
            ),
          );
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- MULAI HEADER (Langkah 4) ---
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
                  ],
                ),
              ),
              // --- AKHIR HEADER ---

              const SizedBox(height: 20), // Jarak antara header dan grid

              // --- MULAI GRIDVIEW (Langkah 5) ---
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
                        child: Column(
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
    );
  }
}
