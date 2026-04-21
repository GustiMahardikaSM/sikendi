import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';
import 'package:sikendi/manager_pilih_kendaraan_page.dart';

class ManagerPenugasanPage extends StatefulWidget {
  const ManagerPenugasanPage({super.key});

  @override
  State<ManagerPenugasanPage> createState() => _ManagerPenugasanPageState();
}

class _ManagerPenugasanPageState extends State<ManagerPenugasanPage> {

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _sopirList = [];
  bool _isLoading = true;

  final TextEditingController _searchSopirController = TextEditingController();
  String _searchSopirQuery = '';


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchSopirController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MongoDBService.getSemuaPenugasan(),
        MongoDBService.getSemuaSopir(),
      ]);
      if (mounted) {
        setState(() {
          _allData = results[0];
          // Hanya ambil sopir yang statusnya aktif
          _sopirList = results[1]
              .where((s) => s['status_akun'] == 'aktif')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Gagal memuat data: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }


  List<Map<String, dynamic>> get _kendaraanTersedia =>
      _allData.where((k) => k['status'] == 'Tersedia').toList();

  List<Map<String, dynamic>> get _sopirTersedia {
    // Cari semua peminjam aktif, lalu filter sopirList yang tidak ada di dalam daftar peminjam
    final allAktif = _allData.where((k) => k['status'] == 'Dipakai' && k['peminjam'] != null);
    final activeDriversNames = allAktif.map((k) => k['peminjam']).toSet();
    final filteredByActive = _sopirList.where((s) {
      final nama = s['nama'];
      return nama != null && !activeDriversNames.contains(nama);
    }).toList();

    if (_searchSopirQuery.isEmpty) return filteredByActive;

    final query = _searchSopirQuery.toLowerCase();
    return filteredByActive.where((s) {
      final nama = (s['nama'] ?? '').toLowerCase();
      final email = (s['email'] ?? '').toLowerCase();
      return nama.contains(query) || email.contains(query);
    }).toList();
  }

  // ============================
  // NAVIGASI PILIH KENDARAAN
  // ============================
  void _navigateToPilihKendaraan(Map<String, dynamic> sopir) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerPilihKendaraanPage(sopir: sopir),
      ),
    );

    // Jika penugasan berhasil, refresh data
    if (result == true) {
      _loadData();
    }
  }


  // ============================
  // BUILD UI
  // ============================

  Widget _buildSopirTersediaTab() {
    final data = _sopirTersedia;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchSopirController,
            decoration: InputDecoration(
              hintText: 'Cari sopir (Nama / Email)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchSopirQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchSopirController.clear();
                        setState(() => _searchSopirQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) => setState(() => _searchSopirQuery = val),
          ),
        ),
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 70, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _searchSopirQuery.isNotEmpty
                            ? "Sopir tidak ditemukan."
                            : "Semua sopir sedang ditugaskan atau tidak ada sopir aktif.",
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person, color: Colors.blue[700], size: 28),
                        ),
                        title: Text(
                          item['nama'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item['email'] ?? '-',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Tersedia",
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment, size: 16),
                          label: const Text("Tugaskan"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _navigateToPilihKendaraan(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Penugasan Sopir"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Muat Ulang",
            onPressed: _loadData,
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildSopirTersediaTab(),
            ),
    );
  }
}
