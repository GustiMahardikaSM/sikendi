import 'dart:convert'; // Untuk Base64
import 'dart:io'; // Untuk File
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Plugin ambil gambar
import 'package:sikendi/manager_map_page.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/constants/hierarchy.dart';


// ==========================================================
// HALAMAN DETAIL KENDARAAN
// ==========================================================
class VehicleDetailPage extends StatefulWidget {
  final String deviceId; // gps_1 atau device_id

  const VehicleDetailPage({super.key, required this.deviceId});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late Future<Map<String, dynamic>?> _vehicleFuture;
  late Future<List<Map<String, dynamic>>> _tripHistoryFuture; // ✨ TAMBAHAN BARU
  Map<String, dynamic>? vehicleData;
  bool _isRefreshing = false;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;
  Map<String, dynamic>? _currentUser;


  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadVehicleDetail();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _currentUser = user);
  }


  void _loadVehicleDetail() {
    setState(() {
      _vehicleFuture = MongoDBService.getDetailKendaraan(widget.deviceId);
      _tripHistoryFuture = MongoDBService.getTripHistory(widget.deviceId); // ✨ TAMBAHAN BARU
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    _loadVehicleDetail();
    setState(() {
      _isRefreshing = false;
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return '-';
    }
    try {
      String cleanTimeStr = dateTimeStr.replaceAll('Z', '');
      final dateTime = DateTime.parse(cleanTimeStr);
      final formatter = DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Logika Upload Gambar (Kompresi & Base64)
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40, // Kompres kualitas agar ringan di DB
        maxWidth: 800, // Resize lebar maksimal
      );

      if (image != null) {
        setState(() => _isUploadingPhoto = true);

        File imageFile = File(image.path);
        List<int> imageBytes = await imageFile.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        // Tambahkan prefix agar kita tahu ini Base64
        String dataToSave = "BASE64:$base64Image";

        final deviceId = widget.deviceId;
        bool success = await MongoDBService.updateFotoKendaraan(
          deviceId,
          dataToSave,
        );

        if (mounted) {
          setState(() => _isUploadingPhoto = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Foto berhasil disimpan!"),
                backgroundColor: Colors.green,
              ),
            );
            _loadVehicleDetail(); // Refresh halaman
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gagal menyimpan foto."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error pick image: $e");
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper: Menampilkan Gambar (URL vs Base64)
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

  // FUNGSI NAVIGASI KE PETA
  void _bukaDiPeta(BuildContext context) {
    if (vehicleData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data kendaraan belum dimuat")),
      );
      return;
    }

    final gpsLoc = vehicleData!['gps_location'];

    if (gpsLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lokasi kendaraan tidak tersedia")),
      );
      return;
    }

    try {
      double lat = 0.0;
      double lng = 0.0;

      // Parsing Koordinat yang Aman (Support GeoJSON & Simple LatLng)
      if (gpsLoc is Map &&
          gpsLoc.containsKey('lat') &&
          gpsLoc.containsKey('lng')) {
        lat = (gpsLoc['lat'] as num).toDouble();
        lng = (gpsLoc['lng'] as num).toDouble();
      } else if (gpsLoc is Map && gpsLoc.containsKey('coordinates')) {
        final List coords = gpsLoc['coordinates'];
        if (coords.length >= 2) {
          lng = (coords[0] as num).toDouble(); // MongoDB GeoJSON: [lng, lat]
          lat = (coords[1] as num).toDouble();
        }
      }

      // Ambil ID Device untuk keperluan data
      final String devId =
          vehicleData!['device_id'] ?? vehicleData!['gps_1'] ?? '';

      // Navigasi ke ManagerMapPage dengan parameter yang benar
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerMapPage(
            initialCenter: LatLng(lat, lng), // Kirim koordinat pusat
            focusDeviceId: devId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error parsing coordinates: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal membuka peta: Format koordinat salah"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Kendaraan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _bukaDiPeta(context);
        },
        icon: const Icon(Icons.travel_explore),
        label: const Text("Lihat Posisi"),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _vehicleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat data kendaraan',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          vehicleData = snapshot.data;
          if (vehicleData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Data kendaraan tidak ditemukan',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Device ID: ${widget.deviceId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // Ambil data dari vehicle
          final plat = vehicleData!['plat'] ?? '-';
          final model = vehicleData!['model'] ?? '-';
          final deviceId =
              vehicleData!['device_id'] ??
              vehicleData!['gps_1'] ??
              widget.deviceId;
          final status = vehicleData!['status'] ?? '-';
          final peminjam = vehicleData!['peminjam'];
          final waktuAmbil = vehicleData!['waktu_ambil']?.toString();
          final gps1 = vehicleData!['gps_1'] ?? '-';
          final waktuLepas = vehicleData!['waktu_lepas']?.toString();

          
          // Data kepemilikan
          final kepemilikan = vehicleData!['kepemilikan'] ?? 'universitas';
          final fakultas = vehicleData!['fakultas'];
          final departemen = vehicleData!['departemen'];
          




          // Tentukan warna status
          Color statusColor;
          switch (status.toString().toLowerCase()) {
            case 'tersedia':
              statusColor = Colors.green;
              break;
            case 'dipakai':
              statusColor = Colors.orange;
              break;
            case 'maintenance':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.grey;
          }

          // Ambil data foto
          final fotoUrl = vehicleData!['foto_url'];

          // Ambil lokasi & speed jika ada
          final speed = (vehicleData!['speed'] as num? ?? 0).toDouble();
          final gpsTime = vehicleData!['server_received_at'] ?? '-';

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====================================================
                  // HEADER FOTO LANDSCAPE
                  // ====================================================
                  Stack(
                    children: [
                      // 1. Container Gambar
                      Container(
                        height: 240, // Tinggi Landscape
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          image:
                              (fotoUrl != null &&
                                  fotoUrl.toString().isNotEmpty &&
                                  _getImageProvider(fotoUrl.toString()) != null)
                              ? DecorationImage(
                                  image: _getImageProvider(fotoUrl.toString())!,
                                  fit: BoxFit.cover, // Gambar memenuhi kotak
                                  onError: (exception, stackTrace) {
                                    // Jika error loading gambar, akan menampilkan placeholder
                                  },
                                )
                              : null,
                        ),
                        child:
                            (fotoUrl == null ||
                                fotoUrl.toString().isEmpty ||
                                _getImageProvider(fotoUrl.toString()) == null)
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Belum ada foto",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                      ),

                      // 2. Gradient Overlay (Agar teks putih terbaca)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3. Informasi Utama (Model & Plat) di atas gambar
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 80, // Ada sisa kanan utk tombol edit
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white70),
                              ),
                              child: Text(
                                plat.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Tombol Edit Foto (Pojok Kanan Bawah Header)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: _isUploadingPhoto
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : FloatingActionButton.small(
                                onPressed: _pickAndUploadImage,
                                backgroundColor: Colors.white,
                                child: const Icon(
                                  Icons.add_a_photo,
                                  color: Colors.blue,
                                ),
                              ),
                      ),

                      // 5. Badge Status (Pojok Kiri Atas)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ====================================================
                  // INFORMASI DETAIL (DESAIN MODERN)
                  // ====================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identitas Kendaraan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // KELOMPOK 1: IDENTITAS (Grouped List Style)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildModernEditableRow(
                                context: context,
                                icon: Icons.confirmation_number_outlined,
                                label: 'Plat Nomor',
                                value: plat.toString(),
                                vehicle: vehicleData!,
                                fieldType: 'plat',
                                onUpdate: () => _loadVehicleDetail(),
                              ),
                              Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                              _buildModernEditableRow(
                                context: context,
                                icon: Icons.directions_car_outlined,
                                label: 'Model',
                                value: model.toString(),
                                vehicle: vehicleData!,
                                fieldType: 'model',
                                onUpdate: () => _loadVehicleDetail(),
                              ),
                              Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                              _buildModernInfoRow(
                                icon: Icons.memory_outlined,
                                label: 'Device ID',
                                value: deviceId.toString(),
                              ),
                              Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                              _buildModernInfoRow(
                                icon: Icons.gps_fixed_outlined,
                                label: 'GPS ID',
                                value: gps1.toString(),
                              ),
                            ],
                          ),
                        ),



                        const SizedBox(height: 24),
                        const Text(
                          'Kepemilikan & Otoritas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildModernTransferableRow(
                                context: context,
                                icon: Icons.account_balance_outlined,
                                label: 'Unit Kerja',
                                value: kepemilikan.toString().toUpperCase(),
                                vehicle: vehicleData!,
                                onUpdate: () => _loadVehicleDetail(),
                              ),
                              if (kepemilikan != 'universitas' && fakultas != null) ...[
                                Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                                _buildModernInfoRow(
                                  icon: Icons.business_outlined,
                                  label: 'Fakultas',
                                  value: fakultas,
                                ),
                              ],
                              if (kepemilikan == 'departemen' && departemen != null) ...[
                                Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                                _buildModernInfoRow(
                                  icon: Icons.layers_outlined,
                                  label: 'Departemen',
                                  value: departemen,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Status & Telemetri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // KELOMPOK 2: TELEMETRI (Bento Grid Style)
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildGridStatBox(
                              icon: Icons.info_outline,
                              label: 'Status',
                              value: status.toString(),
                              iconColor: statusColor,
                              valueColor: statusColor,
                            ),
                            _buildGridStatBox(
                              icon: Icons.speed_outlined,
                              label: 'Kecepatan',
                              value: "${speed.toStringAsFixed(1)} km/h",
                              iconColor: Colors.orange,
                            ),
                            _buildGridStatBox(
                              icon: Icons.update_outlined,
                              label: 'Update Terakhir',
                              value: _formatDateTime(gpsTime.toString()),
                              iconColor: Colors.blue,
                              isSmallText: true,
                            ),
                            Builder(
                              builder: (context) {
                                String lat = "0";
                                String lng = "0";
                                var gpsLoc = vehicleData!['gps_location'];
                                if (gpsLoc != null) {
                                  if (gpsLoc is Map && gpsLoc.containsKey('lat')) {
                                    lat = gpsLoc['lat'].toString();
                                    lng = gpsLoc['lng'].toString();
                                  } else if (gpsLoc is Map && gpsLoc.containsKey('coordinates')) {
                                    List coords = gpsLoc['coordinates'];
                                    if (coords.length >= 2) {
                                      lng = coords[0].toString();
                                      lat = coords[1].toString();
                                    }
                                  }
                                }
                                return _buildGridStatBox(
                                  icon: Icons.location_on_outlined,
                                  label: 'Koordinat',
                                  value: "$lat,\n$lng",
                                  iconColor: Colors.redAccent,
                                  isSmallText: true,
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Informasi Peminjaman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // KELOMPOK 3: PEMINJAMAN (Accent Highlight Box)
                        _buildModernPeminjamCard(
                          context: context,
                          peminjam: peminjam?.toString() ?? '-',
                          deviceId: deviceId.toString(),
                          waktuAmbil: _formatDateTime(waktuAmbil),
                          waktuLepas: _formatDateTime(waktuLepas),
                        ),

                        // ✨ === MULAI TAMBAHAN UI TRIP HISTORY === ✨
                        const SizedBox(height: 32),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 16),
                        const Text(
                          'Riwayat Perjalanan (Trip History)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTripHistorySection(),
                        const SizedBox(height: 32),
                        // ✨ === AKHIR TAMBAHAN UI TRIP HISTORY === ✨
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDER MODERN ---

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );


  }

  Widget _buildModernEditableRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Map<String, dynamic> vehicle,
    required String fieldType,
    required VoidCallback onUpdate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_square, color: Colors.blue.shade300, size: 20),
            splashRadius: 20,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () => _showEditDialog(context, label, value, vehicle, fieldType, onUpdate),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTransferableRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Map<String, dynamic> vehicle,
    required VoidCallback onUpdate,
  }) {


    // Cek apakah user boleh transfer
    bool canTransfer = false;
    if (_currentUser != null) {
      final userLevel = _currentUser!['level'];
      final vehicleLevel = vehicle['kepemilikan'] ?? 'universitas';
      
      if (userLevel == 'universitas') {
        canTransfer = true; // Univ bisa transfer apapun
      } else if (userLevel == 'fakultas') {
        // Manajer Fak bisa transfer kendaraan miliknya atau departemen di bawahnya
        if (vehicleLevel != 'universitas' && vehicle['fakultas'] == _currentUser!['fakultas']) {
          canTransfer = true;
        }
      }
      // Manajer departemen otomatis canTransfer = false
    }


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),




          if (canTransfer) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.swap_horiz, color: Colors.orange.shade700, size: 22),
              splashRadius: 20,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () => _showTransferDialog(context, vehicle, onUpdate),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildGridStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? valueColor,
    bool isSmallText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallText ? 12 : 16,
              color: valueColor ?? Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernPeminjamCard({
    required BuildContext context,
    required String peminjam,
    required String deviceId,
    required String waktuAmbil,
    required String waktuLepas,
  }) {
    bool isDipinjam = peminjam != '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDipinjam
            ? LinearGradient(colors: [Colors.blue.shade50, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isDipinjam ? null : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDipinjam ? Colors.blue.shade100 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDipinjam ? Colors.blue.shade100 : Colors.grey.shade300,
                child: Icon(Icons.person, color: isDipinjam ? Colors.blue.shade800 : Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sedang Digunakan Oleh',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      peminjam,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDipinjam ? Colors.blue.shade900 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDipinjam)
                OutlinedButton.icon(
                  onPressed: () => _showLepasPaksaDialog(context, deviceId, peminjam),
                  icon: const Icon(Icons.power_settings_new, size: 16),
                  label: const Text('Lepas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimelineItem('Diambil', waktuAmbil, Icons.login),
              _buildTimelineItem('Dilepas', waktuLepas, Icons.logout),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String time, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  // Dialog Konfirmasi Lepas Paksa
  void _showLepasPaksaDialog(BuildContext context, String deviceId, String peminjam) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) { // <<-- setState diganti nama menjadi setDialogState
            return AlertDialog(
              title: const Text('Lepas Paksa Kendaraan?'),
              content: Text(
                'Apakah Anda yakin ingin melepas paksa penanggung jawab ($peminjam) dari kendaraan ini?\n\nStatus kendaraan akan kembali menjadi "Tersedia".'
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          // Gunakan setDialogState untuk me-refresh dialog saja
                          setDialogState(() => isProcessing = true);
                          
                          final updatedVehicle = await MongoDBService.lepasPaksaKendaraan(deviceId);
                          
                          // Gunakan 'mounted' dari State utama
                          if (!mounted) return;
                          
                          Navigator.of(dialogContext).pop(); // Tutup dialog
                          
                          if (updatedVehicle != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Berhasil melepas kendaraan'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Panggil setState milik halaman untuk refresh seluruh UI
                            setState(() {
                              _vehicleFuture = Future.value(updatedVehicle);
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal melepas kendaraan'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Ya, Lepas Paksa', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildEditableInfoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Map<String, dynamic> vehicle,
    required String fieldType,
    required VoidCallback onUpdate,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue[900], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(
                context,
                label,
                value,
                vehicle,
                fieldType,
                onUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String label,
    String currentValue,
    Map<String, dynamic> vehicle,
    String fieldType,
    VoidCallback onUpdate,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentValue == '-' ? '' : currentValue,
    );
    final deviceId =
        vehicle['device_id'] ?? vehicle['gps_1'] ?? widget.deviceId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit $label'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Masukkan $label',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: fieldType == 'plat'
                    ? TextCapitalization.characters
                    : TextCapitalization.words,
                enabled: !isLoading,
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newValue = controller.text.trim();
                          if (newValue.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$label tidak boleh kosong'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            // Ambil nilai current untuk kedua field
                            final currentPlat = (vehicle['plat'] ?? '')
                                .toString();
                            final currentModel = (vehicle['model'] ?? '')
                                .toString();

                            // Update sesuai field yang diubah
                            final updatedPlat = fieldType == 'plat'
                                ? newValue.toUpperCase()
                                : (currentPlat.isEmpty || currentPlat == '-')
                                ? ''
                                : currentPlat;
                            final updatedModel = fieldType == 'model'
                                ? newValue
                                : (currentModel.isEmpty || currentModel == '-')
                                ? ''
                                : currentModel;

                            final success =
                                await MongoDBService.updateKendaraanDetail(
                                  deviceId.toString(),
                                  updatedPlat,
                                  updatedModel,
                                );

                            if (context.mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Data berhasil diperbarui'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop();
                                onUpdate();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Gagal memperbarui data'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
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
    String peminjam = trip['peminjam'] ?? '-';
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
                  child: Text(
                    peminjam,
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

  void _showTransferDialog(BuildContext context, Map<String, dynamic> vehicle, VoidCallback onUpdate) {
    String selectedLevel = vehicle['kepemilikan'] ?? 'universitas';
    String? selectedFakultas = vehicle['fakultas'];
    String? selectedDepartemen = vehicle['departemen'];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Transfer Kepemilikan"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(

                      isExpanded: true,
                      value: selectedLevel,
                      decoration: const InputDecoration(labelText: 'Tingkat'),
                      items: [
                        if (_currentUser?['level'] == 'universitas')
                          const DropdownMenuItem(value: 'universitas', child: Text('Universitas')),
                        const DropdownMenuItem(value: 'fakultas', child: Text('Fakultas')),
                        const DropdownMenuItem(value: 'departemen', child: Text('Departemen')),
                      ],
                      onChanged: isLoading ? null : (v) => setDialogState(() {
                        selectedLevel = v!;
                        // Jika bukan univ, otomatis pilih fakultas user sendiri
                        if (_currentUser?['level'] == 'fakultas') {
                          selectedFakultas = _currentUser!['fakultas'];
                        } else {
                          selectedFakultas = null;
                        }
                        selectedDepartemen = null;
                      }),
                    ),
                    if (selectedLevel != 'universitas') ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedFakultas,
                        decoration: const InputDecoration(labelText: 'Fakultas'),
                        // Jika manajer fakultas, dropdown fakultas dikunci/disabled
                        items: _currentUser?['level'] == 'fakultas' 
                          ? [DropdownMenuItem(value: _currentUser!['fakultas'], child: Text(_currentUser!['fakultas'].toString()))]
                          : HierarchyData.listFakultas.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (isLoading || _currentUser?['level'] == 'fakultas') ? null : (v) => setDialogState(() {
                          selectedFakultas = v;
                          selectedDepartemen = null;
                        }),
                      ),
                    ],
                    if (selectedLevel == 'departemen' && selectedFakultas != null) ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedDepartemen,
                        decoration: const InputDecoration(labelText: 'Departemen'),
                        items: HierarchyData.getDepartemen(selectedFakultas!).map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: isLoading ? null : (v) => setDialogState(() => selectedDepartemen = v),
                      ),
                    ],
                  ],
                ),

              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (selectedLevel != 'universitas' && selectedFakultas == null) return;
                    if (selectedLevel == 'departemen' && selectedDepartemen == null) return;

                    setDialogState(() => isLoading = true);
                    try {
                      final gps1 = vehicle['gps_1'] ?? vehicle['device_id'] ?? widget.deviceId;
                      final success = await MongoDBService.transferKendaraan(
                        gps1,
                        kepemilikan: selectedLevel,
                        fakultas: selectedFakultas,
                        departemen: selectedDepartemen,
                      );


                      if (mounted) {
                        Navigator.pop(dialogContext);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Berhasil mentransfer kendaraan"), backgroundColor: Colors.green),
                          );
                          onUpdate();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Gagal mentransfer kendaraan"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setDialogState(() => isLoading = false);
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

