import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ProfileSopirPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileSopirPage({super.key, required this.user});

  @override
  State<ProfileSopirPage> createState() => _ProfileSopirPageState();
}

class _ProfileSopirPageState extends State<ProfileSopirPage> {
  // Variabel untuk menyimpan foto yang dipilih nanti di Langkah 4
  File? _imageFile;
  
  // Variabel untuk status kendaraan (nanti diisi dari database di Langkah 3)
  Map<String, dynamic>? _kendaraanSaatIni;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  late Future<List<Map<String, dynamic>>> _tripHistoryFuture;

  // 1. Fungsi untuk menampilkan menu bawah (Bottom Sheet) pilihan Kamera/Galeri
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.blue),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Fungsi untuk mengambil foto, mengompres, dan menyimpan ke Database
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Ambil gambar
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Batas ukuran awal
        maxHeight: 800,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sedang memproses dan menyimpan foto...")),
        );

        // Kompresi gambar agar database MongoDB tidak berat
        var compressedFile = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 400,
          minHeight: 400,
          quality: 60, // Kualitas gambar diturunkan sedikit (60%)
        );

        if (compressedFile != null) {
          // Ubah gambar yang sudah dikompres menjadi String Base64
          String base64Image = base64Encode(compressedFile);
          String email = widget.user['email'];

          // Simpan ke MongoDB menggunakan fungsi dari Langkah 3
          bool success = await MongoDBService.updateFotoProfilSopir(email, base64Image);

          if (success) {
            setState(() {
              _imageFile = file; // Perbarui tampilan UI
              widget.user['foto_profil'] = base64Image; // Perbarui data lokal user
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Foto profil berhasil diperbarui!"), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gagal menyimpan foto ke database."), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      print("Error saat memproses foto: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan saat memproses foto."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData(); // Memanggil fungsi ambil data saat halaman pertama kali dibuka
    String namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? '';
    _tripHistoryFuture = MongoDBService.getTripHistoryBySopir(namaSopir);
  }

  // Fungsi untuk mengambil status kendaraan dari database
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mengambil nama sopir dari data user yang login
      String namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? '';
      
      // Memanggil fungsi yang sudah ada sebelumnya di MongoDBService
      // untuk mengecek pekerjaan/kendaraan yang sedang dipegang sopir
      var pekerjaan = await MongoDBService.getPekerjaanSaya(namaSopir);
      
      setState(() {
        if (pekerjaan.isNotEmpty) {
          // Asumsi struktur data kembalian memiliki field 'plat_nomor'
          _kendaraanSaatIni = pekerjaan.first; 
        } else {
          _kendaraanSaatIni = null; // Tidak sedang membawa mobil
        }
      });
    } catch (e) {
      print("Gagal mengambil data kendaraan: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil data user yang dikirim dari dashboard
    final userData = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ==========================================
                // BAGIAN 1: FOTO PROFIL & TOMBOL EDIT
                // ==========================================
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      // Logika Tampilan Foto: 
                      // 1. Cek file lokal (_imageFile) jika baru ganti foto
                      // 2. Jika tidak ada, cek apakah ada base64 di database
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) as ImageProvider
                          : (userData['foto_profil'] != null && userData['foto_profil'].toString().isNotEmpty)
                              ? MemoryImage(base64Decode(userData['foto_profil']))
                              : null,
                      // Jika tidak ada foto sama sekali, tampilkan ikon default
                      child: (_imageFile == null && (userData['foto_profil'] == null || userData['foto_profil'].toString().isEmpty))
                          ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          // Panggil fungsi dialog yang baru kita buat
                          onPressed: _showImageSourceDialog, 
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ==========================================
                // BAGIAN 2: DATA DIRI
                // ==========================================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Informasi Pribadi",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.badge, color: Colors.blue),
                          title: const Text("Nama Lengkap"),
                          subtitle: Text(userData['nama'] ?? userData['nama_lengkap'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.orange),
                          title: const Text("Email"),
                          subtitle: Text(userData['email'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Colors.green),
                          title: const Text("No. Handphone"),
                          subtitle: Text(userData['no_hp'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ==========================================
                // BAGIAN 3: STATUS KENDARAAN SAAT INI
                // ==========================================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Status Operasional",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(
                            _kendaraanSaatIni != null ? Icons.directions_car : Icons.car_crash, 
                            color: _kendaraanSaatIni != null ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          title: Text(
                            _kendaraanSaatIni != null ? "Sedang Bertugas" : "Standby (Tidak bawa mobil)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _kendaraanSaatIni != null ? Colors.green : Colors.red,
                            ),
                          ),
                          subtitle: Text(
                            _kendaraanSaatIni != null 
                                ? "Plat: ${_kendaraanSaatIni!['plat']}" 
                                : "Silakan check-in kendaraan di Dasbor",
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ==========================================================
                // BAGIAN 4: RIWAYAT PERJALANAN (TRIP HISTORY)
                // ==========================================================
                const Text(
                  "Riwayat Perjalanan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildTripHistorySection(),
              ],
            ),
          ),
    );
  }

  // ==========================================================
  // WIDGET KHUSUS TRIP HISTORY
  // ==========================================================
  Widget _buildTripHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tripHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat riwayat perjalanan"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text("Belum ada riwayat perjalanan untuk kendaraan ini.",
                style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final trips = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Scroll mengikuti SingleChildScrollView parent
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return _buildTripCard(trip);
          },
        );
      },
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    // 1. Ekstraksi dan Parsing Koordinat GeoJSON (LineString)
    List<LatLng> routePoints = [];
    if (trip['route'] != null && trip['route']['coordinates'] != null) {
      for (var coord in trip['route']['coordinates']) {
        if (coord is List && coord.length >= 2) {
          double lng = (coord[0] as num).toDouble(); // GeoJSON format: [Lng, Lat]
          double lat = (coord[1] as num).toDouble();
          routePoints.add(LatLng(lat, lng));
        }
      }
    }

    // Hitung bounds (batasan peta) agar seluruh rute terlihat proporsional
    LatLngBounds? mapBounds;
    if (routePoints.isNotEmpty) {
      mapBounds = LatLngBounds.fromPoints(routePoints);
    }

    // 2. Ekstraksi Data Lainnya
    String plat = trip['plat'] ?? '-';
    String model = trip['model'] ?? '';
    String vehicleInfo = model.isNotEmpty ? '$model ($plat)' : plat;
    String date = trip['date'] ?? '-';
    String distance = trip['trip_distance_km']?.toString() ?? '0';
    String duration = trip['trip_duration_minutes']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: Colors.blue[900]),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.directions_car, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          vehicleInfo,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map Overview
          SizedBox(
            height: 180, // Tinggi mini-map overview
            child: routePoints.isEmpty
                ? Container(
                    color: Colors.grey[300],
                    child: const Center(child: Text("Rute tidak tersedia")),
                  )
                : FlutterMap(
                    options: MapOptions(
                      // Menggunakan initialCameraFit (support flutter_map v6+)
                      initialCameraFit: mapBounds != null
                          ? CameraFit.bounds(bounds: mapBounds, padding: const EdgeInsets.all(24.0))
                          : null,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none, // Peta statis, tidak bisa di-scroll/zoom oleh user
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.sikendi',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: Colors.blueAccent,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                      // Marker penanda titik awal (Hijau) dan titik akhir (Merah)
                      MarkerLayer(
                        markers: [
                          if (routePoints.isNotEmpty)
                          Marker(
                            point: routePoints.first,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                          ),
                          if (routePoints.isNotEmpty)
                          Marker(
                            point: routePoints.last,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Footer Statistics Card
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTripStat(Icons.timer_outlined, "$duration Menit", "Durasi"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[800], size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
