import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:sikendi/manager_verifikasi_detail_page.dart';
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
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    
                    // --- PERBAIKAN LOGIKA REFRESH DISINI ---
                    onTap: () async {
                      // 1. Pindah ke halaman detail dan TUNGGU (await) hasilnya
                      // Halaman detail akan mengembalikan 'true' jika ada perubahan status
                      final bool? result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => 
                              ManagerVerifikasiDetailPage(driver: driver),
                        ),
                      );

                      // 2. Jika result bernilai true, Refresh data list
                      if (result == true) {
                        _loadData(); 
                      }
                    },
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