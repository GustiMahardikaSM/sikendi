import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/vehicle_api_service.dart';

class ManagerSopirDetailPage extends StatefulWidget {
  final Map<String, dynamic> dataSopir;

  const ManagerSopirDetailPage({Key? key, required this.dataSopir}) : super(key: key);

  @override
  _ManagerSopirDetailPageState createState() => _ManagerSopirDetailPageState();
}

class _ManagerSopirDetailPageState extends State<ManagerSopirDetailPage> {
  bool isLoading = true;
  Map<String, dynamic>? statusPekerjaan;
  late Future<List<Map<String, dynamic>>> _tripHistoryFuture;

  @override
  void initState() {
    super.initState();
    _fetchStatusSopir();
    // Ambil nama sopir dengan aman
    final namaSopir = widget.dataSopir['nama'] ?? widget.dataSopir['username'];
    if (namaSopir != null) {
      _tripHistoryFuture = MongoDBService.getTripHistoryBySopir(namaSopir);
    } else {
      // Jika nama sopir null, inisialisasi dengan future kosong
      _tripHistoryFuture = Future.value([]);
    }
  }

  Future<void> _fetchStatusSopir() async {
    // Mengaktifkan kembali pengambilan data dinamis
    final namaSopir = widget.dataSopir['nama'] ?? widget.dataSopir['username'];
    if (namaSopir == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final pekerjaanList = await VehicleApiService.getPekerjaanSaya(namaSopir);
      final pekerjaan = pekerjaanList.isNotEmpty ? pekerjaanList.first : null;
      if (mounted) {
        setState(() {
          statusPekerjaan = pekerjaan;
        });
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Fungsi khusus untuk menangani error Base64 Foto
  ImageProvider _getProfileImage() {
    // Mencari dengan beberapa kemungkinan key
    String? base64String = widget.dataSopir['foto_profil'] ?? widget.dataSopir['profile_image'] ?? widget.dataSopir['foto'];

    if (base64String != null && base64String.isNotEmpty) {
      try {
        // Jika ada prefix "data:image/png;base64,", kita harus memotongnya
        if (base64String.contains(',')) {
          base64String = base64String.split(',').last;
        }
        // Hapus spasi atau newline yang mungkin terbawa
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');
        
        Uint8List imageBytes = base64Decode(base64String);
        return MemoryImage(imageBytes);
      } catch (e) {
      }
    }
    // Mengembalikan gambar transparan/kosong jika gagal
    return const AssetImage(''); 
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan key ini ('nama', 'email', 'phone') SAMA PERSIS dengan di MongoDB
    final nama = widget.dataSopir['nama'] ?? widget.dataSopir['username'] ?? 'Nama tidak tersedia';
    final email = widget.dataSopir['email'] ?? 'Email tidak tersedia';
    final telepon = widget.dataSopir['phone'] ?? widget.dataSopir['telepon'] ?? widget.dataSopir['no_hp'] ?? '-';
    
    // Cek apakah gambar berhasil diload
    bool hasValidImage = false;
    ImageProvider imageProvider = _getProfileImage();
    if (imageProvider is MemoryImage) {
      hasValidImage = true;
    }

    // Menyiapkan data untuk kartu status
    final bool isBekerja = statusPekerjaan != null && statusPekerjaan!.isNotEmpty;
    final String namaKendaraan = statusPekerjaan?['model'] ?? 'Kendaraan tidak dikenal';
    final String platNomor = statusPekerjaan?['plat'] ?? '-';
    final String statusText = isBekerja 
      ? 'Sedang bertugas: $namaKendaraan ($platNomor)' 
      : 'Saat ini sedang standby';
    final Color statusColor = isBekerja ? Colors.orange : Colors.green;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sopir'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- BAGIAN FOTO PROFIL ---
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: hasValidImage ? imageProvider : null,
                child: !hasValidImage 
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // --- BAGIAN DATA DIRI ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blueAccent),
                      title: const Text('Nama Lengkap'),
                      subtitle: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blueAccent),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.blueAccent),
                      title: const Text('Nomor Telepon'),
                      subtitle: Text(telepon),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- BAGIAN STATUS PEKERJAAN ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListTile(
                        leading: Icon(Icons.directions_car, color: statusColor),
                        title: const Text('Status Operasional'),
                        subtitle: Text(statusText), 
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // --- BAGIAN TRIP HISTORY ---
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
              child: Text("Belum ada riwayat perjalanan untuk sopir ini.",
                style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final trips = snapshot.data!;
        // return ListView.builder(
        //   shrinkWrap: true,
        //   physics: const NeverScrollableScrollPhysics(), // Scroll mengikuti SingleChildScrollView parent
        //   itemCount: trips.length,
        //   itemBuilder: (context, index) {
        //     final trip = trips[index];
        //     return _buildTripCard(trip);
        //   },
        // );
        // Ganti ListView.builder menjadi Column agar tidak error constraint
        return Column(
          children: trips.map((trip) => _buildTripCard(trip)).toList(),
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
    String date = trip['date'] ?? '-';
    String duration = trip['trip_duration_minutes']?.toString() ?? '0';
    // ✨ BARU: Ambil nama mobil dan plat
    String namaMobil = trip['model'] ?? 'N/A';
    String platNomor = trip['plat'] ?? '-';

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
                // ✨ BARU: Tampilkan nama mobil dan plat
                Expanded(
                  child: Text(
                    '$namaMobil ($platNomor)',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
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