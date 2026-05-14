import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class ManagerLaporanDetailPage extends StatelessWidget {
  final Map<String, dynamic> report;

  const ManagerLaporanDetailPage({super.key, required this.report});

  ImageProvider? _getImageProvider(String? fotoData) {
    if (fotoData == null || fotoData.isEmpty) return null;
    try {
      if (fotoData.startsWith('BASE64:')) {
        return MemoryImage(base64Decode(fotoData.substring(7)));
      } else if (fotoData.contains(',')) {
        return MemoryImage(base64Decode(fotoData.split(',').last.replaceAll(RegExp(r'\s+'), '')));
      } else if (fotoData.startsWith('http')) {
        return NetworkImage(fotoData);
      }
      return MemoryImage(base64Decode(fotoData.replaceAll(RegExp(r'\s+'), '')));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(report['waktu_ambil']).toLocal();
    final endTime = DateTime.parse(report['waktu_selesai']).toLocal();
    final isRevoked = report['alasan_pencabutan'] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Laporan Penugasan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER INFO ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.blue[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${report['model']} (${report['plat']})",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text("Sopir: ${report['namaSopir']}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATUS & REASON ---
                  if (isRevoked)
                    _buildAlertCard(
                      Icons.warning_amber_rounded,
                      "Penugasan Dicabut Manager",
                      "Alasan: ${report['alasan_pencabutan']}",
                      Colors.red,
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // --- STATS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatItem(Icons.route, "Jarak Tempuh", "${report['jarak_km']} km"),
                      _buildStatItem(Icons.speed, "Kecepatan Maks", "${report['kecepatan_maksimal']} km/h"),
                      _buildStatItem(Icons.timer, "Durasi Tugas", "${report['durasi_menit']} menit"),
                      _buildStatItem(Icons.flash_on, "Mobil Aktif", report['waktu_aktif']),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- FUZZY ANALYSIS SECTION ---
                  if (report['predominant_driving_style'] != null) ...[
                    _buildFuzzyAnalysisSection(),
                    const SizedBox(height: 24),
                  ],

                  // --- DETAIL SECTION ---
                  _buildSectionTitle("Informasi Penugasan"),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.assignment, "Tugas", report['tugas'] ?? '-'),
                  _buildDetailRow(Icons.person_pin, "Ditugaskan Oleh", report['manager_info']?['name'] ?? '-'),
                  _buildDetailRow(Icons.business, "Unit Kerja", report['manager_info']?['unit'] ?? '-'),
                  _buildDetailRow(Icons.access_time, "Waktu Ambil", DateFormat('dd MMM yyyy, HH:mm').format(startTime)),
                  _buildDetailRow(Icons.event_available, "Waktu Selesai", DateFormat('dd MMM yyyy, HH:mm').format(endTime)),

                  const SizedBox(height: 24),

                  // --- PHOTO SECTION ---
                  _buildSectionTitle("Foto Kendaraan"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildPhotoBox("Foto Awal", report['foto_mobil_awal'])),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPhotoBox("Foto Akhir", report['foto_mobil_akhir'])),
                    ],
                  ),

                  if (report['catatan_driver'] != null && report['catatan_driver'].toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle("Catatan Sopir"),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                      child: Text(report['catatan_driver'], style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- MAP SECTION ---
                  _buildSectionTitle("Riwayat Perjalanan"),
                  const SizedBox(height: 12),
                  _buildMapSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[900], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                Text(value, style: TextStyle(color: Colors.blue[900], fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              SizedBox(
                width: 300,
                child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBox(String label, String? photoData) {
    final image = _getImageProvider(photoData);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null,
          ),
          child: image == null ? const Icon(Icons.no_photography_outlined, color: Colors.grey) : null,
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    final List<LatLng> routePoints = [];
    if (report['route'] != null && report['route']['coordinates'] != null) {
      for (var coord in report['route']['coordinates']) {
        routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
      }
    }

    if (routePoints.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Tidak ada rute perjalanan tercatat")),
      );
    }

    final bounds = LatLngBounds.fromPoints(routePoints);

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(20)),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: routePoints, color: Colors.blueAccent, strokeWidth: 5),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(point: routePoints.first, child: const Icon(Icons.location_on, color: Colors.green, size: 30)),
                Marker(point: routePoints.last, child: const Icon(Icons.location_on, color: Colors.red, size: 30)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuzzyAnalysisSection() {
    final predominantStyle = report['predominant_driving_style'] ?? 'N/A';
    final avgScore = report['avg_fuzzy_score'] != null ? report['avg_fuzzy_score'].toString() : '-';
    final counts = report['fuzzy_style_counts'];

    Color styleColor = Colors.grey;
    IconData styleIcon = Icons.help_outline;

    if (predominantStyle == 'Defensive Driving') {
      styleColor = Colors.green;
      styleIcon = Icons.shield;
    } else if (predominantStyle == 'Normal Driving') {
      styleColor = Colors.blue;
      styleIcon = Icons.drive_eta;
    } else if (predominantStyle == 'Aggressive Driving') {
      styleColor = Colors.red;
      styleIcon = Icons.warning;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Analisis Gaya Berkendara (Fuzzy)"),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: styleColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(styleIcon, color: styleColor, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Gaya Dominan", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(predominantStyle, style: TextStyle(color: styleColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("Rata-rata Skor: $avgScore", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              if (counts != null && counts is Map) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFuzzyCountItem("Defensive", counts['Defensive Driving'] ?? 0, Colors.green),
                    _buildFuzzyCountItem("Normal", counts['Normal Driving'] ?? 0, Colors.blue),
                    _buildFuzzyCountItem("Aggressive", counts['Aggressive Driving'] ?? 0, Colors.red),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFuzzyCountItem(String label, dynamic count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
