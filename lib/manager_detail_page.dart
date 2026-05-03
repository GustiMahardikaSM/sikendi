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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Detail Manager",
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w600, 
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 8, bottom: 32, left: 16, right: 16),
              decoration: BoxDecoration(
                color: Colors.blue[900],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: image != null 
                        ? DecorationImage(image: image, fit: BoxFit.cover)
                        : null,
                    ),
                    child: image == null 
                      ? Icon(Icons.person, size: 45, color: Colors.blue[900]) 
                      : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.manager['nama_manager'] ?? 'Tanpa Nama',
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.manager['level']?.toUpperCase() ?? '-',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 12, 
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.manager['email_manager'] ?? '-',
                    style: TextStyle(color: Colors.blue[100], fontSize: 14),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Informasi Detail",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(),
                  
                  const SizedBox(height: 32),
                  const Text(
                    "Log Aktivitas Penugasan",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityLog(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.phone, "No. HP", widget.manager['no_hp'] ?? '-'),
          const SizedBox(height: 16),
          if (widget.manager['fakultas'] != null) ...[
            _buildInfoRow(Icons.business, "Fakultas", widget.manager['fakultas']),
            const SizedBox(height: 16),
          ],
          if (widget.manager['departemen'] != null) ...[
            _buildInfoRow(Icons.apartment, "Departemen", widget.manager['departemen']),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[900], size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          textAlign: TextAlign.right,
        ),
      ],
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Column(
              children: [
                Icon(Icons.history, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text("Belum ada riwayat penugasan.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final log = activities[index];
            final type = log['type'] ?? '';
            final bool isLast = index == activities.length - 1;
            
            IconData icon;
            Color iconColor;
            
            if (type.contains('assignment')) {
              icon = Icons.assignment_ind;
              iconColor = Colors.blue;
            } else if (type.contains('vehicle')) {
              icon = Icons.directions_car;
              iconColor = Colors.orange;
            } else if (type.contains('verify')) {
              icon = Icons.verified_user;
              iconColor = Colors.green;
            } else {
              icon = Icons.history;
              iconColor = Colors.grey;
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 14),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey[200],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(log['timestamp']),
                            style: TextStyle(
                              fontSize: 12, 
                              color: Colors.blueGrey[400], 
                              fontWeight: FontWeight.w600
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['description'] ?? 'Tanpa deskripsi',
                            style: const TextStyle(
                              fontSize: 14, 
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
