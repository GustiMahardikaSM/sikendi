import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sikendi/mongodb_service.dart';

class ManagerVerifikasiDetailPage extends StatefulWidget {
  final Map<String, dynamic> driver;

  const ManagerVerifikasiDetailPage({super.key, required this.driver});

  @override
  State<ManagerVerifikasiDetailPage> createState() =>
      _ManagerVerifikasiDetailPageState();
}

class _ManagerVerifikasiDetailPageState
    extends State<ManagerVerifikasiDetailPage> {
  bool _isLoading = false;

  Uint8List _decodeBase64(String base64String) {
    final cleanBase64 = base64String.split(',').last;
    return base64Decode(cleanBase64);
  }

  Future<void> _handleStatusUpdate(String status) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final driverId = widget.driver['_id'] as mongo.ObjectId;
    final success = await MongoService.updateDriverStatus(driverId, status);

    if (mounted) {
      setState(() => _isLoading = false);
      final message = success
          ? "Status sopir berhasil diubah menjadi '$status'"
          : "Gagal memperbarui status sopir.";
      final color = success ? Colors.green : Colors.red;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));

      if (success) {
        Navigator.pop(context, true); // Return true to refresh the list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detail Verifikasi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem("Nama", widget.driver['nama'] ?? 'N/A'),
            _buildDetailItem("Email", widget.driver['email'] ?? 'N/A'),
            _buildDetailItem("No. HP", widget.driver['no_hp'] ?? 'N/A'),
            const SizedBox(height: 24),

            _buildPhotoCard("Foto Selfie", widget.driver['foto_selfie_temp']),
            const SizedBox(height: 16),
            _buildPhotoCard("Foto KTP/ID Card", widget.driver['foto_ktp_temp']),
            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showConfirmationDialog('ditolak'),
                    icon: const Icon(Icons.close),
                    label: const Text("Tolak"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(120, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showConfirmationDialog('aktif'),
                    icon: const Icon(Icons.check),
                    label: const Text("Setujui"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(120, 48),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Konfirmasi Tindakan"),
        content: Text(
          "Apakah Anda yakin ingin ${status == 'aktif' ? 'menyetujui' : 'menolak'} pendaftaran sopir ini?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStatusUpdate(status);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'aktif' ? Colors.green : Colors.red,
            ),
            child: const Text("Yakin"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String title, String? base64Image) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (base64Image != null && base64Image.isNotEmpty)
              Center(
                child: Image.memory(
                  _decodeBase64(base64Image),
                  fit: BoxFit.contain,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.red, size: 50),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    "Gambar tidak tersedia atau telah dihapus.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
