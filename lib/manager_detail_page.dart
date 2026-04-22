import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerDetailPage extends StatefulWidget {
  final Map<String, dynamic> manager;

  const ManagerDetailPage({super.key, required this.manager});

  @override
  State<ManagerDetailPage> createState() => _ManagerDetailPageState();
}

class _ManagerDetailPageState extends State<ManagerDetailPage> {
  late Future<List<Map<String, dynamic>>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _activityFuture = MongoDBService.getManagerActivityLog(widget.manager['email_manager'] ?? '');
  }

  ImageProvider? _getProfileImage() {
    String? base64String = widget.manager['foto_selfie'];
    if (base64String != null && base64String.isNotEmpty) {
      try {
        if (base64String.contains(',')) {
          base64String = base64String.split(',').last;
        }
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint("Error decoding profile image: $e");
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _getProfileImage();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Manager"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: image,
                child: image == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoSection(),
            const SizedBox(height: 24),
            const Text(
              "Log Aktivitas Penugasan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActivityLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.person, "Nama", widget.manager['nama_manager'] ?? '-'),
            const Divider(),
            _buildInfoRow(Icons.email, "Email", widget.manager['email_manager'] ?? '-'),
            const Divider(),
            _buildInfoRow(Icons.phone, "No. HP", widget.manager['no_hp'] ?? '-'),
            const Divider(),
            _buildInfoRow(Icons.layers, "Level", widget.manager['level']?.toUpperCase() ?? '-'),
            if (widget.manager['fakultas'] != null) ...[
              const Divider(),
              _buildInfoRow(Icons.business, "Fakultas", widget.manager['fakultas']),
            ],
            if (widget.manager['departemen'] != null) ...[
              const Divider(),
              _buildInfoRow(Icons.apartment, "Departemen", widget.manager['departemen']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[900], size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text("Belum ada riwayat penugasan.", style: TextStyle(color: Colors.grey))),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final log = activities[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.assignment_turned_in, color: Colors.green),
                title: Text("Tugas: ${log['tugas'] ?? 'Umum'}"),
                subtitle: Text("Driver: ${log['namaSopir']}\nMobil: ${log['model']} (${log['plat']})"),
                isThreeLine: true,
                trailing: Text(
                  _formatDate(log['waktu_selesai']),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoDate;
    }
  }
}
