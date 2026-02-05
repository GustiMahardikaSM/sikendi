import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongodb_service.dart';

class ManagerVerifikasiPage extends StatefulWidget {
  const ManagerVerifikasiPage({super.key});

  @override
  State<ManagerVerifikasiPage> createState() => _ManagerVerifikasiPageState();
}

class _ManagerVerifikasiPageState extends State<ManagerVerifikasiPage> {
  late Future<List<Map<String, dynamic>>> _pendingDriversFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _pendingDriversFuture = MongoService.getPendingDrivers();
    });
  }

  void _showVerificationDialog(Map<String, dynamic> driver) {
    // Safely get base64 strings
    final String? selfieBase64 = driver['foto_selfie_temp'];
    final String? ktpBase64 = driver['foto_ktp_temp'];
    final mongo.ObjectId driverId = driver['_id'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Detail Verifikasi Sopir"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Nama: ${driver['nama'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Email: ${driver['email'] ?? 'N/A'}"),
                const SizedBox(height: 8),
                Text("No. HP: ${driver['no_hp'] ?? 'N/A'}"),
                const SizedBox(height: 16),
                const Text("Foto Selfie:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (selfieBase64 != null && selfieBase64.isNotEmpty)
                  Image.memory(base64Decode(selfieBase64))
                else
                  const Text("Foto selfie tidak tersedia."),
                const SizedBox(height: 16),
                const Text("Foto KTP:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (ktpBase64 != null && ktpBase64.isNotEmpty)
                  Image.memory(base64Decode(ktpBase64))
                else
                  const Text("Foto KTP tidak tersedia."),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                bool success = await MongoService.rejectDriver(driverId);
                if (success) {
                   ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Pendaftaran sopir ditolak dan dihapus."), backgroundColor: Colors.red),
                  );
                  _loadData(); // Refresh list
                } else {
                   ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Gagal menolak pendaftaran."), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text("Tolak", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                bool success = await MongoService.approveDriver(driverId);
                if (success) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Sopir berhasil diverifikasi dan diaktifkan!"), backgroundColor: Colors.green),
                  );
                  _loadData(); // Refresh list
                } else {
                   ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Gagal memverifikasi sopir."), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Verifikasi / Terima"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verifikasi Pendaftaran Sopir"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingDriversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Terjadi error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Tidak ada pendaftaran baru yang menunggu verifikasi.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final drivers = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView.builder(
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                final tglDaftar = driver['tgl_daftar'] != null 
                    ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(driver['tgl_daftar']))
                    : 'Tanggal tidak diketahui';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.person_outline, color: Colors.orange),
                    title: Text(driver['nama'] ?? 'Tanpa Nama'),
                    subtitle: Text("No HP: ${driver['no_hp'] ?? '-'}\nDaftar: $tglDaftar"),
                    trailing: const Icon(Icons.watch_later_outlined, color: Colors.grey),
                    onTap: () => _showVerificationDialog(driver),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}