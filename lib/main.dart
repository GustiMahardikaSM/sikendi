import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/driver_page.dart'; // Import halaman driver
import 'package:sikendi/login_page.dart';
import 'package:sikendi/manager_page.dart'; // Import halaman manager
import 'package:flutter/material.dart';
import 'package:sikendi/manager_login_page.dart'; // Library UI standar Flutter (Tombol, Teks, Warna)

// ==========================================================
// 1. FUNGSI UTAMA (Main Entry Point)
// ==========================================================
Future<void> main() async {
  // Pastikan semua widget Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner:
          false, // Menghilangkan banner "Debug" di pojok kanan atas
      title: 'SiKenDi App',
      // Aplikasi dimulai dari Halaman Awal (RoleSelectionPage)
      home: RoleSelectionPage(),
    ),
  );
}

// ==========================================================
// 2. HALAMAN PEMILIHAN PERAN (UI MODERN)
// ==========================================================
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Definisikan warna utama agar konsisten
    const primaryColor = Color(0xFF003366); // Navy Blue
    const managerButtonColor = Color(0xFF005A9C); // Slightly Lighter Blue
    const driverButtonColor = Color(0xFF2E7D32); // Darker Green

    return Scaffold(
      body: Stack(
        children: [
          // --- Latar Belakang Gradien ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  Color(0xFF001F3F), // Darker Navy
                ],
              ),
            ),
          ),
          // Elemen dekoratif
          Positioned(
            top: -50,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // --- Konten Utama ---
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Header ---
                    const Icon(
                      Icons.directions_car_filled,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "SiKenDi",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const Text(
                      "SISTEM INFORMASI KENDARAAN DINAS\nUNIVERSITAS DIPONEGORO",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                        height: 1.5, // Menambah jarak antar baris
                      ),
                    ),
                    const SizedBox(height: 64),

                    // --- Pemisah ---
                    const Text(
                      "Masuk Sebagai",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Tombol Manager ---
                    _buildRoleButton(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      label: "MANAJER",
                      subtitle: "Monitoring Armada",
                      color: managerButtonColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManagerLoginPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- Tombol Sopir ---
                    _buildRoleButton(
                      context,
                      icon: Icons.drive_eta_rounded,
                      label: "SOPIR",
                      subtitle: "Aktifkan Tracking",
                      color: driverButtonColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk membuat tombol yang dapat digunakan kembali
  Widget _buildRoleButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
