import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/driver_page.dart'; // Import halaman driver
import 'package:sikendi/login_page.dart';
import 'package:sikendi/manager_page.dart'; // Import halaman manager
import 'package:flutter/material.dart'; // Library UI standar Flutter (Tombol, Teks, Warna)

// ========================================================== 
// 1. FUNGSI UTAMA (Main Entry Point)
// ========================================================== 
Future<void> main() async {
  // Pastikan semua widget Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();
  // Hubungkan ke database MongoDB sebelum aplikasi dimulai
  await MongoService.connect();
  await MongoService.connectJadwal();
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, // Menghilangkan banner "Debug" di pojok kanan atas
    title: 'SiKenDi App',
    // Aplikasi dimulai dari Halaman Awal (RoleSelectionPage) 
    home: RoleSelectionPage(),
  ));
}

// ========================================================== 
// 2. HALAMAN PEMILIHAN PERAN
// ========================================================== 
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  // Fungsi untuk menampilkan Dialog Persetujuan Privasi untuk Manajer
  void _showManagerConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa tutup dialog dengan klik di luar kotak
      builder: (ctx) => AlertDialog(
        title: const Text("Persetujuan Privasi Data"),
        content: const SingleChildScrollView(
          child: Text(
            // Teks disesuaikan dengan dokumen proposal
            "Sesuai dengan UU No. 27 Tahun 2022 tentang Perlindungan Data Pribadi:\n\n" 
            "1. Aplikasi ini akan mengakses lokasi perangkat Anda secara real-time.\n"
            "2. Data lokasi digunakan hanya untuk keperluan operasional kendaraan dinas Undip.\n"
            "3. Dengan melanjutkan, Anda menyetujui pengumpulan dan pemrosesan data ini.",
            textAlign: TextAlign.justify,
          ),
        ),
        actions: [
          // Tombol Batal
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), // Tutup dialog
            child: const Text("Tolak"),
          ),
          // Tombol Setuju -> Masuk ke Peta Manajer
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Tutup dialog dulu
              // Langsung ke halaman manajer
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ManagerPage()),
              );
            },
            child: const Text("Setuju & Masuk"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Warna latar belakang biru muda
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Posisi elemen di tengah vertikal
            children: [
              // Logo atau Ikon Judul
              const Icon(Icons.directions_car_filled, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                "SiKenDi UNDIP",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Text("Sistem Informasi Kendaraan Dinas"),
              const SizedBox(height: 48),

              // --- TOMBOL PILIH PERAN ---
              
              const Text("Masuk Sebagai:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Tombol untuk MANAJER
              SizedBox(
                width: double.infinity, // Lebar tombol memenuhi layar
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text("MANAJER (Monitoring Armada)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                  onPressed: () => _showManagerConsentDialog(context),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol untuk SOPIR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.drive_eta),
                  label: const Text("SOPIR (Aktifkan Tracking)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  onPressed: () {
                    // Arahkan ke halaman login khusus sopir
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}