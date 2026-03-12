import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/manager_sopir_detail_page.dart'; // Import halaman detail

class ManagerSopirPage extends StatefulWidget {
  const ManagerSopirPage({super.key});

  @override
  State<ManagerSopirPage> createState() => _ManagerSopirPageState();
}

class _ManagerSopirPageState extends State<ManagerSopirPage> {
  late Future<List<Map<String, dynamic>>> _sopirFuture;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allSopir = [];
  List<Map<String, dynamic>> _filteredSopir = [];

  @override
  void initState() {
    super.initState();
    _loadSopirData();
  }

  void _loadSopirData() {
    setState(() {
      _sopirFuture = MongoDBService.getSemuaSopir();
      _sopirFuture.then((sopir) {
        setState(() {
          _allSopir = sopir;
          _filteredSopir = sopir;
        });
      });
    });
  }

  void _filterSopir(String query) {
    final searchQueryNoSpace = query.toLowerCase().replaceAll(' ', '');
    setState(() {
      _searchQuery = query;
      _filteredSopir = _allSopir.where((sopir) {
        final nama = (sopir['nama'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(' ', '');
        final email = (sopir['email'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(' ', '');
        final noHp = (sopir['no_hp'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(' ', '');

        return nama.contains(searchQueryNoSpace) ||
            email.contains(searchQueryNoSpace) ||
            noHp.contains(searchQueryNoSpace);
      }).toList();
    });
  }

  // Widget baru untuk membangun kartu sopir yang lebih bergaya
  Widget _buildSopirCard(Map<String, dynamic> sopir) {
    final nama = sopir['nama'] ?? 'Tanpa Nama';
    final email = sopir['email'] ?? '-';
    final hp = sopir['no_hp'] ?? '-';
    final status = sopir['status_akun'] ?? 'pending'; // Ambil status

    // Tentukan warna dan ikon berdasarkan status
    final Color statusColor;
    final IconData statusIcon;
    if (status == 'aktif') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'nonaktif') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManagerSopirDetailPage(dataSopir: sopir),
            ),
          ).then((_) => _loadSopirData()); // Muat ulang data setelah kembali
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue[50],
                child: Text(
                  nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.blue[800],
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(hp, style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          status[0].toUpperCase() + status.substring(1), // Capitalize
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
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
        title: const Text('Data Sopir'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterSopir,
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan nama, email, atau no. hp',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadSopirData(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _sopirFuture,
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
                  if (_filteredSopir.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Sopir tidak ditemukan.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _filteredSopir.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 0),
                    itemBuilder: (context, index) {
                      return _buildSopirCard(_filteredSopir[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
