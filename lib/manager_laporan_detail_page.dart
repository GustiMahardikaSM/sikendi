import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:sikendi/trip_route_detail_page.dart';

class ManagerLaporanDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;

  const ManagerLaporanDetailPage({super.key, required this.report});

  @override
  State<ManagerLaporanDetailPage> createState() => _ManagerLaporanDetailPageState();
}

class _ManagerLaporanDetailPageState extends State<ManagerLaporanDetailPage> {
  final GlobalKey _mapBoundaryKey = GlobalKey();

  Map<String, dynamic> get report => widget.report;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _downloadPdf(context),
            tooltip: "Unduh PDF",
          ),
        ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Riwayat Perjalanan"),
                      ElevatedButton.icon(
                        onPressed: () {
                          final List<LatLng> routePoints = [];
                          if (report['route'] != null && report['route']['coordinates'] != null) {
                            for (var coord in report['route']['coordinates']) {
                              routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                            }
                          }
                          if (routePoints.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TripRouteDetailPage(
                                  routePoints: routePoints,
                                  title: "Rute Perjalanan",
                                  tripData: report,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Data rute tidak tersedia")),
                            );
                          }
                        },
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text("Lihat Fullscreen", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
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

    return RepaintBoundary(
      key: _mapBoundaryKey,
      child: Container(
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
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.sikendi.app',
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

  Future<void> _downloadPdf(BuildContext context) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final startTime = DateTime.parse(report['waktu_ambil']).toLocal();
    final endTime = DateTime.parse(report['waktu_selesai']).toLocal();
    final isRevoked = report['alasan_pencabutan'] != null;

    // Load images
    Future<pw.MemoryImage?> _getPdfImage(String? fotoData) async {
      if (fotoData == null || fotoData.isEmpty) return null;
      try {
        if (fotoData.startsWith('http')) {
          final response = await http.get(Uri.parse(fotoData));
          if (response.statusCode != 200) return null;
          return pw.MemoryImage(response.bodyBytes);
        }
        Uint8List bytes;
        if (fotoData.startsWith('BASE64:')) {
          bytes = base64Decode(fotoData.substring(7));
        } else if (fotoData.contains(',')) {
          bytes = base64Decode(fotoData.split(',').last.replaceAll(RegExp(r'\s+'), ''));
        } else {
          bytes = base64Decode(fotoData.replaceAll(RegExp(r'\s+'), ''));
        }
        return pw.MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }

    final fotoAwal = await _getPdfImage(report['foto_mobil_awal']);
    final fotoAkhir = await _getPdfImage(report['foto_mobil_akhir']);

    // Capture Map Image
    pw.MemoryImage? mapImage;
    try {
      final boundary = _mapBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        // Reduced pixelRatio to avoid "Unable to print" due to large memory size
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          mapImage = pw.MemoryImage(byteData.buffer.asUint8List());
        }
      }
    } catch (e) {
      debugPrint("Error capturing map image: $e");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("SIKENDI",
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text("Sistem Informasi Kendaraan Dinas",
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("LAPORAN PENUGASAN",
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text("ID: ${report['_id']?.toString().substring(0, 8).toUpperCase() ?? '-'}",
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              "Halaman ${context.pageNumber} dari ${context.pagesCount} | Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // --- HEADER INFO TABLE ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfInfoRow("Kendaraan", "${report['model']} (${report['plat']})", fontBold),
                      _buildPdfInfoRow("Sopir", report['namaSopir'] ?? '-', fontBold),
                      _buildPdfInfoRow("Unit Kerja", report['manager_info']?['unit'] ?? '-', fontBold),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildPdfStatusBadge(isRevoked ? "DICABUT" : "SELESAI", isRevoked ? PdfColors.red : PdfColors.green),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // --- STATS BAR ---
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue100),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatItemCompact("Jarak", "${report['jarak_km']} km", fontBold),
                  _buildPdfStatVerticalDivider(),
                  _buildPdfStatItemCompact("Kec. Maks", "${report['kecepatan_maksimal']} km/h", fontBold),
                  _buildPdfStatVerticalDivider(),
                  _buildPdfStatItemCompact("Durasi", "${report['durasi_menit']} m", fontBold),
                  _buildPdfStatVerticalDivider(),
                  _buildPdfStatItemCompact("Aktif", report['waktu_aktif'] ?? '-', fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // --- FUZZY ANALYSIS CARD ---
            if (report['predominant_driving_style'] != null) ...[
              pw.Text("Analisis Gaya Berkendara",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Gaya Dominan", style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                              pw.Text(report['predominant_driving_style'],
                                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                              pw.Text("Rata-rata Skor: ${report['avg_fuzzy_score'] ?? '-'}",
                                  style: const pw.TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (report['fuzzy_style_counts'] != null) ...[
                      pw.SizedBox(height: 15),
                      pw.Divider(color: PdfColors.grey200),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildPdfFuzzyCountItem("Defensive", report['fuzzy_style_counts']['Defensive Driving'] ?? 0, PdfColors.green, fontBold),
                          _buildPdfFuzzyCountItem("Normal", report['fuzzy_style_counts']['Normal Driving'] ?? 0, PdfColors.blue, fontBold),
                          _buildPdfFuzzyCountItem("Aggressive", report['fuzzy_style_counts']['Aggressive Driving'] ?? 0, PdfColors.red, fontBold),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // --- ASSIGNMENT DETAILS ---
            pw.Text("Detail Penugasan",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  _buildPdfDetailRowNew("Tugas", report['tugas'] ?? '-', fontBold),
                  _buildPdfDetailRowNew("Manager", report['manager_info']?['name'] ?? '-', fontBold),
                  _buildPdfDetailRowNew("Waktu Ambil", DateFormat('dd MMM yyyy, HH:mm').format(startTime), fontBold),
                  _buildPdfDetailRowNew("Waktu Selesai", DateFormat('dd MMM yyyy, HH:mm').format(endTime), fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // --- PHOTOS ---
            pw.NewPage(),
            pw.Text("Dokumentasi Kendaraan",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _buildPdfPhotoBoxNew("Foto Awal", fotoAwal)),
                pw.SizedBox(width: 15),
                pw.Expanded(child: _buildPdfPhotoBoxNew("Foto Akhir", fotoAkhir)),
              ],
            ),

            // --- DRIVER NOTES ---
            if (report['catatan_driver'] != null && report['catatan_driver'].toString().isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text("Catatan Sopir",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(report['catatan_driver'], style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 11)),
              ),
            ],

            pw.SizedBox(height: 24),
            pw.NewPage(),
            pw.Text("Riwayat Rute Perjalanan",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            if (mapImage != null)
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(mapImage, fit: pw.BoxFit.contain),
                ),
              )
            else
              pw.Container(
                height: 120,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.grey50,
                ),
                child: pw.Center(
                  child: pw.Text("Gagal memuat visualisasi rute.",
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ),
              ),
          ];
        },
      ),
    );

    try {
      final bytes = await pdf.save();
      final fileName = "${report['namaSopir'] ?? 'Laporan'}_${DateFormat('ddMMyyyy').format(endTime)}.pdf";
      
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Laporan siap diunduh: $fileName")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengunduh PDF: ${e.toString()}")),
        );
      }
    }
  }

  pw.Widget _buildPdfInfoRow(String label, String value, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 80, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
          pw.Text(": ", style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fontBold))),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatusBadge(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfStatItemCompact(String label, String value, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold, color: PdfColors.blue900)),
      ],
    );
  }

  pw.Widget _buildPdfStatVerticalDivider() {
    return pw.Container(width: 1, height: 20, color: PdfColors.blue200);
  }

  pw.Widget _buildPdfFuzzyCountItem(String label, dynamic count, PdfColor color, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(count.toString(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: fontBold, color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ],
    );
  }

  pw.Widget _buildPdfDetailRowNew(String label, String value, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fontBold))),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPhotoBoxNew(String label, pw.MemoryImage? image) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Container(
          height: 140,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
            color: PdfColors.grey100,
          ),
          child: image != null
              ? pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(image, fit: pw.BoxFit.cover))
              : pw.Center(child: pw.Text("N/A", style: const pw.TextStyle(fontSize: 10))),
        ),
      ],
    );
  }
}
