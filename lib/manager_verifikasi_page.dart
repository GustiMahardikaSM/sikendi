import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

      _pendingDriversFuture = MongoDBService.getPendingDrivers();

    });

  }



  // Widget baru untuk kartu verifikasi

  Widget _buildVerifikasiCard(Map<String, dynamic> driver) {

    final nama = driver['nama'] ?? 'Tanpa Nama';

    final hp = driver['no_hp'] ?? '-';

    final tglDaftar = driver['tgl_daftar'] != null

        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(driver['tgl_daftar']))

        : 'Tanggal tidak diketahui';



    return Card(

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

      elevation: 2,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: InkWell(

        borderRadius: BorderRadius.circular(12),

        onTap: () async {

          final bool? result = await Navigator.push(

            context,

            MaterialPageRoute(

              builder: (context) => ManagerVerifikasiDetailPage(driver: driver),

            ),

          );

          if (result == true && mounted) {

            _loadData();

          }

        },

        child: Padding(

          padding: const EdgeInsets.all(16.0),

          child: Row(

            children: [

              CircleAvatar(

                radius: 28,

                backgroundColor: Colors.orange[50],

                child: Text(

                  nama.isNotEmpty ? nama[0].toUpperCase() : '?',

                  style: TextStyle(

                    color: Colors.orange[800],

                    fontWeight: FontWeight.bold,

                    fontSize: 24,

                  ),

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      nama,

                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),

                    ),

                    const SizedBox(height: 8),

                    Row(

                      children: [

                        Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),

                        const SizedBox(width: 6),

                        Text(hp, style: TextStyle(color: Colors.grey[700])),

                      ],

                    ),

                    const SizedBox(height: 4),

                    Row(

                      children: [

                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),

                        const SizedBox(width: 6),

                        Text(tglDaftar, style: TextStyle(color: Colors.grey[700])),

                      ],

                    ),

                  ],

                ),

              ),

              const SizedBox(width: 12),

              Icon(Icons.chevron_right, color: Colors.grey[400]),

            ],

          ),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text("Verifikasi Pendaftaran Sopir"),

        backgroundColor: Colors.blue[900],

        foregroundColor: Colors.white,

        elevation: 0,

      ),

      backgroundColor: Colors.grey[100],

      body: RefreshIndicator(

        onRefresh: () async => _loadData(),

        child: FutureBuilder<List<Map<String, dynamic>>>(

          future: _pendingDriversFuture,

          builder: (context, snapshot) {

            if (snapshot.connectionState == ConnectionState.waiting) {

              return const Center(child: CircularProgressIndicator());

            }

            if (snapshot.hasError) {

              return Center(

                child: Text(

                  'Gagal memuat data: ${snapshot.error}',

                  style: TextStyle(color: Colors.red[700]),

                ),

              );

            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {

              return const Center(

                child: Column(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    Icon(Icons.person_search, size: 60, color: Colors.grey),

                    SizedBox(height: 16),

                    Text(

                      'Tidak ada pendaftaran baru.',

                      style: TextStyle(fontSize: 16, color: Colors.grey),

                    ),

                  ],

                ),

              );

            }



            final drivers = snapshot.data!;

            return ListView.builder(

              padding: const EdgeInsets.only(top: 8, bottom: 8),

              itemCount: drivers.length,

              itemBuilder: (context, index) {

                return _buildVerifikasiCard(drivers[index]);

              },

            );

          },

        ),

      ),

    );

  }

}
