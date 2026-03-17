import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
    try {
      final cleanBase64 = base64String.split(',').last;
      return base64Decode(cleanBase64);
    } catch (e) {
      // Return an empty list or a placeholder image byte array if decode fails
      return Uint8List(0);
    }
  }

  Future<void> _handleStatusUpdate(String status) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final String driverId = widget.driver['_id'].toString();

    try {
      await MongoDBService.updateDriverStatus(driverId, status);
      if (mounted) {
        final message = "Status sopir berhasil diubah menjadi '$status'";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final message = "Gagal memperbarui status: ${e.toString()}";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showConfirmationDialog(String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Konfirmasi Tindakan"),
        content: Text(
          "Apakah Anda yakin ingin ${status == 'aktif' ? 'menyetujui' : 'menolak'} pendaftaran sopir ini?",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
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
              backgroundColor: status == 'aktif' ? Colors.green[700] : Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Yakin"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Verifikasi"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildPhotoCard("Foto Selfie", widget.driver['foto_selfie_temp']),
            const SizedBox(height: 16),
            _buildPhotoCard("Foto KTP / ID Card", widget.driver['foto_ktp_temp']),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Data Personal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 8),
            const Divider(),
            _buildDetailItem(Icons.person_outline, "Nama", widget.driver['nama'] ?? 'N/A'),
            _buildDetailItem(Icons.email_outlined, "Email", widget.driver['email'] ?? 'N/A'),
            _buildDetailItem(Icons.phone_outlined, "No. HP", widget.driver['no_hp'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[800], size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String title, String? base64Image) {
    final imageBytes = base64Image != null && base64Image.isNotEmpty ? _decodeBase64(base64Image) : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
            ),
          ),
          const Divider(height: 1),
          if (imageBytes != null && imageBytes.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Center(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              color: Colors.white,
              child: const Center(
                child: Text(
                  "Gambar tidak tersedia.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmationDialog('ditolak'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("Tolak"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmationDialog('aktif'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Setujui"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
