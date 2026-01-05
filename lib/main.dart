import 'dart:async'; // Library untuk fitur Timer (agar data update otomatis)
import 'package:flutter/material.dart'; // Library UI standar Flutter (Tombol, Teks, Warna)
import 'package:flutter_map/flutter_map.dart'; // Library Peta OpenStreetMap
import 'package:latlong2/latlong.dart'; // Library untuk menangani Latitude & Longitude
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Library Driver Database MongoDB

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
              // Pindah ke Halaman Peta dengan membawa status peran (Sopir/Manajer)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SiKenDiMapPage(role: role)),
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

// ========================================================== 
// 3. HALAMAN UTAMA (PETA & TRACKING)
// ========================================================== 
class SiKenDiMapPage extends StatefulWidget {
  final String role; // Menyimpan peran user: "Manajer" atau "Sopir" 

  const SiKenDiMapPage({super.key, required this.role});

  @override
  State<SiKenDiMapPage> createState() => _SiKenDiMapPageState();
}

class _SiKenDiMapPageState extends State<SiKenDiMapPage> {
  // --- KONFIGURASI DATABASE ---
  // String koneksi ke MongoDB Atlas (Cloud)
  final String _mongoUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/gps_1?retryWrites=true&w=majority";
  final String _collectionName = "gps_location";

  // --- VARIABEL STATE (Data yang berubah-ubah) ---
  mongo.Db? _db; // Objek database
  List<LatLng> _routePoints = []; // Menyimpan daftar koordinat untuk menggambar garis rute
  LatLng? _currentPosition; // Menyimpan posisi terakhir kendaraan
  double _currentSpeed = 0.0; // Menyimpan kecepatan saat ini
  bool _isLoading = true; // Status loading saat pertama kali buka
  Timer? _timer; // Pengatur waktu untuk auto-refresh

  // Fungsi yang dijalankan pertama kali saat halaman dibuka
  @override
  void initState() {
    super.initState();
    _connectToMongo(); // 1. Konek Database

    // 2. Pasang Timer: Jalankan fungsi _fetchLatestData setiap 2 detik.
    // Ini memenuhi target latensi < 3 detik  & update real-time[cite: 311].
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchLatestData();
    });
  }

  // Fungsi yang dijalankan saat halaman ditutup/keluar
  @override
  void dispose() {
    _timer?.cancel(); // Matikan timer agar tidak memakan memori
    _db?.close(); // Tutup koneksi database
    super.dispose();
  }

  // LOGIKA 1: Membuka Koneksi ke MongoDB
  Future<void> _connectToMongo() async {
    try {
      _db = await mongo.Db.create(_mongoUrl);
      await _db!.open(); // Membuka koneksi
      debugPrint("✅ Koneksi MongoDB Berhasil");
      _fetchLatestData(); // Ambil data pertama kali langsung
    } catch (e) {
      debugPrint("❌ Gagal Konek DB: $e");
    }
  }

  // LOGIKA 2: Mengambil Data GPS Terbaru
  Future<void> _fetchLatestData() async {
    // Jika database belum siap, jangan lakukan apa-apa
    if (_db == null || !_db!.isConnected) return;

    try {
      var collection = _db!.collection(_collectionName);

      // Query: Ambil 50 data terakhir, diurutkan waktu (descending/terbaru dulu)
      // Limit 50 diambil agar kita bisa menggambar ekor/jejak rute perjalanan
      final data = await collection
          .find(mongo.where.sortBy('server_received_at', descending: true).limit(50))
          .toList();

      if (data.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Konversi data JSON dari MongoDB menjadi objek LatLng (Koordinat Flutter)
      List<LatLng> tempPoints = [];
      double latestSpeed = 0;

      for (var doc in data) {
        // Cek apakah field 'gps_location' ada (Sesuai struktur data di gambar pengguna)
        if (doc['gps_location'] != null) {
          var loc = doc['gps_location'];
          // Konversi angka ke tipe Double (Pecahan) agar aman
          double lat = (loc['lat'] as num).toDouble();
          double lng = (loc['lng'] as num).toDouble();
          tempPoints.add(LatLng(lat, lng));
        }
      }

      // Ambil kecepatan dari data paling baru (index ke-0 karena tadi disort descending)
      if (data.isNotEmpty && data.first['speed'] != null) {
        latestSpeed = (data.first['speed'] as num).toDouble();
      }

      // Karena kita ambil 'Terbaru' -> 'Terlama', urutan listnya terbalik.
      // Kita perlu balik (reversed) agar garis rute digambar dari titik lama ke titik baru.
      tempPoints = tempPoints.reversed.toList();

      // Update Tampilan (UI)
      if (mounted) {
        setState(() {
          _routePoints = tempPoints; // Update garis rute
          if (tempPoints.isNotEmpty) {
            _currentPosition = tempPoints.last; // Posisi kendaraan adalah titik paling ujung
          }
          _currentSpeed = latestSpeed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch Data: $e");
    }
  }

  // --- TAMPILAN ANTARMUKA (UI) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar: Judul Aplikasi & Info User
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SiKenDi Live Map", style: TextStyle(fontSize: 18)),
            // Menampilkan peran yang sedang login (Kecil di bawah judul)
            Text("Login sebagai: ${widget.role}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: widget.role == "Manajer" ? Colors.blue[900] : Colors.green[700], // Warna beda tiap role
        foregroundColor: Colors.white,
        actions: [
          // Indikator Kecepatan di pojok kanan atas
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentSpeed.toStringAsFixed(1)} km/h", // Tampilkan kecepatan 1 desimal
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),

      // Body: Menampilkan Peta atau Loading
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Lingkaran loading jika data belum siap
          : _currentPosition == null
              ? const Center(child: Text("Menunggu data GPS..."))
              : FlutterMap(
                  options: MapOptions(
                    // Pusatkan kamera ke posisi kendaraan terakhir
                    initialCenter: _currentPosition!,
                    initialZoom: 16.0, // Zoom level (Cukup dekat untuk lihat jalan)
                  ),
                  children: [
                    // LAYER 1: Gambar Peta Dasar (Tiles) dari OpenStreetMap
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.undip.sikendi',
                    ),

                    // LAYER 2: Garis Rute (Jejak Perjalanan)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0, // Ketebalan garis
                          color: Colors.blueAccent, // Warna garis
                        ),
                      ],
                    ),

                    // LAYER 3: Marker (Ikon Mobil)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              // Kotak Nama di atas mobil
                              Container(
                                padding: const EdgeInsets.all(2),
                                color: Colors.white,
                                child: const Text(
                                  "SiKenDi-01", 
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Ikon Mobil
                              Icon(
                                Icons.directions_car,
                                color: widget.role == "Manajer" ? Colors.blue : Colors.red, // Warna beda buat seru-seruan
                                size: 40,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
      
      // Tombol Mengambang (Floating Action Button) - Opsional
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Fitur Reset Kamera ke posisi mobil (bisa ditambahkan nanti)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memusatkan Peta...")));
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}