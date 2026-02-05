import 'dart:convert'; // Untuk Base64
import 'dart:io'; // Untuk File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Plugin ambil gambar
import 'package:sikendi/manager_map_page.dart';
import 'package:sikendi/manager_page.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

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
  Map<String, dynamic>? vehicleData;
  bool _isRefreshing = false;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetail();
  }

  void _loadVehicleDetail() {
    setState(() {
      _vehicleFuture = MongoService.getDetailKendaraan(widget.deviceId);
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
      final dateTime = DateTime.parse(dateTimeStr);
      final formatter = DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID');
      return formatter.format(dateTime.toLocal());
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
        bool success = await MongoService.updateFotoKendaraan(
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
      print("Error pick image: $e");
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
      print("Error loading image: $e");
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
      print("Error parsing coordinates: $e");
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
          final peminjam = vehicleData!['peminjam'] ?? null;
          final waktuAmbil = vehicleData!['waktu_ambil']?.toString();
          final gps1 = vehicleData!['gps_1'] ?? '-';
          final waktuLepas = vehicleData!['waktu_lepas']?.toString();

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
          double lat = 0, lng = 0, speed = 0;
          if (vehicleData!['gps_location'] != null &&
              vehicleData!['gps_location']['coordinates'] != null &&
              vehicleData!['gps_location']['coordinates'].length == 2) {
            lng = (vehicleData!['gps_location']['coordinates'][0] as num? ?? 0)
                .toDouble();
            lat = (vehicleData!['gps_location']['coordinates'][1] as num? ?? 0)
                .toDouble();
          }
          speed = (vehicleData!['speed'] as num? ?? 0).toDouble();
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
                  // INFORMASI DETAIL (FITUR LAIN TETAP ADA)
                  // ====================================================
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Detail',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildEditableInfoCard(
                          context: context,
                          icon: Icons.confirmation_number,
                          label: 'Plat Nomor',
                          value: plat.toString(),
                          vehicle: vehicleData!,
                          fieldType: 'plat',
                          onUpdate: () => _loadVehicleDetail(),
                        ),
                        const SizedBox(height: 12),
                        _buildEditableInfoCard(
                          context: context,
                          icon: Icons.directions_car,
                          label: 'Model',
                          value: model.toString(),
                          vehicle: vehicleData!,
                          fieldType: 'model',
                          onUpdate: () => _loadVehicleDetail(),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.devices,
                          label: 'Device ID',
                          value: deviceId.toString(),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.gps_fixed,
                          label: 'GPS ID',
                          value: gps1.toString(),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: status.toString(),
                          valueColor: statusColor,
                        ),
                        const SizedBox(height: 12),

                        // --- TAMBAHAN BARU: TAMPILKAN KOORDINAT ---
                        Builder(
                          builder: (context) {
                            // Logika ekstraksi koordinat agar aman
                            String lat = "0";
                            String lng = "0";

                            var gpsLoc = vehicleData!['gps_location'];
                            if (gpsLoc != null) {
                              if (gpsLoc is Map && gpsLoc.containsKey('lat')) {
                                lat = gpsLoc['lat'].toString();
                                lng = gpsLoc['lng'].toString();
                              } else if (gpsLoc is Map &&
                                  gpsLoc.containsKey('coordinates')) {
                                // Handle GeoJSON [lng, lat]
                                List coords = gpsLoc['coordinates'];
                                if (coords.length >= 2) {
                                  lng = coords[0].toString();
                                  lat = coords[1].toString();
                                }
                              }
                            }

                            return _buildInfoCard(
                              icon: Icons.map, // Ikon Peta
                              label: 'Lokasi Terkini (Lat, Lng)',
                              value: "$lat, $lng",
                            );
                          },
                        ),

                        // --- AKHIR TAMBAHAN ---
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.person,
                          label: 'Peminjam',
                          value: peminjam?.toString() ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.access_time,
                          label: 'Waktu Ambil',
                          value: _formatDateTime(waktuAmbil),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.event_available,
                          label: 'Waktu Lepas',
                          value: _formatDateTime(waktuLepas),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.speed,
                          label: 'Kecepatan',
                          value: "${speed.toStringAsFixed(1)} km/h",
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.access_time,
                          label: 'Terakhir Update',
                          value: _formatDateTime(gpsTime.toString()),
                        ),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                                await MongoService.updateKendaraanDetail(
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
}
