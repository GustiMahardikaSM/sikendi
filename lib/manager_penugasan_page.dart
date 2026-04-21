import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';
import 'package:sikendi/manager_pilih_kendaraan_page.dart';

class ManagerPenugasanPage extends StatefulWidget {
  const ManagerPenugasanPage({super.key});

  @override
  State<ManagerPenugasanPage> createState() => _ManagerPenugasanPageState();
}

class _ManagerPenugasanPageState extends State<ManagerPenugasanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _sopirList = [];
  bool _isLoading = true;

  final TextEditingController _searchSopirController = TextEditingController();
  String _searchSopirQuery = '';

  final TextEditingController _searchAktifController = TextEditingController();
  String _searchAktifQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadData();
  }

  @override
  void dispose() {
    _searchSopirController.dispose();
    _searchAktifController.dispose();
    _tabController.dispose();
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

  List<Map<String, dynamic>> get _penugasanAktif {
    final list = _allData.where((k) => k['status'] == 'Dipakai' && k['peminjam'] != null).toList();
    if (_searchAktifQuery.isEmpty) return list;

    final q = _searchAktifQuery.toLowerCase();
    return list.where((k) {
      final peminjam = (k['peminjam'] ?? '').toLowerCase();
      final model = (k['model'] ?? '').toLowerCase();
      final plat = (k['plat'] ?? '').toLowerCase();
      final tugas = (k['tugas'] ?? '').toLowerCase();
      return peminjam.contains(q) || model.contains(q) || plat.contains(q) || tugas.contains(q);
    }).toList();
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
  // CABUT PENUGASAN
  // ============================
  void _confirmCabutPenugasan(Map<String, dynamic> penugasan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Cabut Penugasan?"),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: "Anda akan mencabut penugasan "),
              TextSpan(
                text: penugasan['peminjam'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: " dari kendaraan "),
              TextSpan(
                text: "${penugasan['model']} (${penugasan['plat']})",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ". Lanjutkan?"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _executeCabutPenugasan(penugasan['deviceId']);
            },
            child: const Text("Ya, Cabut"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCabutPenugasan(String deviceId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await MongoDBService.cabutPenugasan(deviceId);

    if (mounted) Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
      if (result['success']) _loadData();
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

  Widget _buildPenugasanAktifTab() {
    final data = _penugasanAktif;

    return Column(
      children: [
        // Search Bar Aktif
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchAktifController,
            decoration: InputDecoration(
              hintText: 'Cari nama / kendaraan / tugas...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchAktifQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchAktifController.clear();
                        setState(() => _searchAktifQuery = '');
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
            onChanged: (val) => setState(() => _searchAktifQuery = val),
          ),
        ),
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 70, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _searchAktifQuery.isNotEmpty
                            ? "Penugasan tidak ditemukan."
                            : "Belum ada penugasan aktif.",
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      if (_searchAktifQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Buat penugasan dari tab 'Sopir Tersedia'.",
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return _buildPenugasanCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPenugasanCard(Map<String, dynamic> item) {
    final waktuAmbil = item['waktu_ambil'];
    String formattedTime = '-';
    if (waktuAmbil != null) {
      try {
        formattedTime =
            DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(waktuAmbil));
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: Colors.blue[700]!, width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Sopir
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person, color: Colors.blue[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['peminjam'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item['konfirmasi_sopir'] == 'pending'
                                ? Colors.amber.withOpacity(0.15)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['konfirmasi_sopir'] == 'pending'
                                    ? Icons.access_time
                                    : Icons.circle,
                                color: item['konfirmasi_sopir'] == 'pending'
                                    ? Colors.amber[800]
                                    : Colors.green[700],
                                size: item['konfirmasi_sopir'] == 'pending' ? 14 : 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['konfirmasi_sopir'] == 'pending'
                                    ? "Menunggu Konfirmasi"
                                    : "Sedang Bertugas",
                                style: TextStyle(
                                    color: item['konfirmasi_sopir'] == 'pending'
                                        ? Colors.amber[800]
                                        : Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Kendaraan
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    "Kendaraan: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      "${item['model'] ?? '-'} (${item['plat'] ?? '-'})",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Tugas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    "Tugas: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      item['tugas'] ?? 'Tidak ada deskripsi',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: item['tugas'] == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Waktu
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    "Ditugaskan: $formattedTime",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol Cabut
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.assignment_return, size: 16),
                  label: const Text("Selesaikan / Cabut Penugasan"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _confirmCabutPenugasan(item),
                ),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              icon: const Icon(Icons.person, size: 20),
              text: "Sopir Tersedia (${_sopirTersedia.length})",
            ),
            Tab(
              icon: const Icon(Icons.assignment, size: 20),
              text: "Aktif (${_penugasanAktif.length})",
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSopirTersediaTab(),
                  _buildPenugasanAktifTab(),
                ],
              ),
            ),
    );
  }
}
