import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerSopirPage extends StatefulWidget {
  const ManagerSopirPage({super.key});

  @override
  State<ManagerSopirPage> createState() => _ManagerSopirPageState();
}

class _ManagerSopirPageState extends State<ManagerSopirPage> {
  late Future<List<Map<String, dynamic>>> _sopirFuture;

  @override
  void initState() {
    super.initState();
    _loadSopirData();
  }

  void _loadSopirData() {
    setState(() {
      _sopirFuture = MongoService.getSemuaSopir();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sopir'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadSopirData(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _sopirFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Belum ada data sopir.'));
            }

            final sopirList = snapshot.data!;

            return ListView.builder(
              itemCount: sopirList.length,
              itemBuilder: (context, index) {
                final sopir = sopirList[index];
                final nama = sopir['nama_lengkap'] ?? 'Tanpa Nama';
                final email = sopir['email'] ?? '-';
                final hp = sopir['no_hp'] ?? '-';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal[100],
                      child: Text(
                        nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Email: $email'),
                        Text('No. HP: $hp'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
