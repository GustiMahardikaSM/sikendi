import 'package:sikendi/driver_page.dart'; // Import halaman driver
import 'package:sikendi/manager_page.dart'; // Import halaman manager
import 'package:flutter/material.dart'; // Library UI standar Flutter (Tombol, Teks, Warna)

// ========================================================== 
// 1. FUNGSI UTAMA (Main Entry Point)
// ========================================================== 
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, // Menghilangkan banner "Debug" di pojok kanan atas
    title: 'SiKenDi App',
    // Aplikasi dimulai dari Halaman Login
    home: LoginPage(),
  ));
}

// ========================================================== 
// 2. HALAMAN LOGIN (DEMO AUTH & CONSENT)
// ========================================================== 
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Fungsi untuk menampilkan Dialog Persetujuan Privasi (UU PDP)
  // Dipanggil saat tombol peran ditekan.
  void _showConsentDialog(BuildContext context, String role) {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa tutup dialog dengan klik di luar kotak
      builder: (ctx) => AlertDialog(
        title: const Text("Persetujuan Privasi Data"),
        content: const SingleChildScrollView(
          child: Text(
            // Teks disesuaikan dengan dokumen proposal [cite: 195, 506]
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
          // Tombol Setuju -> Masuk ke Peta
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Tutup dialog dulu
              
              // --- LOGIKA NAVIGASI BERDASARKAN PERAN ---
              if (role == "Sopir") {
                // Jika peran adalah Sopir, pergi ke DriverPage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverPage()),
                );
              } else {
                // Jika peran lain (Manajer), pergi ke halaman Peta umum
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagerPage()),
                );
              }
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

              // --- TOMBOL PILIH PERAN (DEMO) --- 
              
              const Text("Masuk Sebagai:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Tombol untuk MANAJER [cite: 502]
              SizedBox(
                width: double.infinity, // Lebar tombol memenuhi layar
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text("MANAJER (Monitoring Armada)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                  onPressed: () => _showConsentDialog(context, "Manajer"),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol untuk SOPIR [cite: 503]
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.drive_eta),
                  label: const Text("SOPIR (Aktifkan Tracking)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  onPressed: () => _showConsentDialog(context, "Sopir"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}