import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';

class ManagerInformasiTugasPage extends StatefulWidget {
  const ManagerInformasiTugasPage({super.key});

  @override
  State<ManagerInformasiTugasPage> createState() => _ManagerInformasiTugasPageState();
}

class _ManagerInformasiTugasPageState extends State<ManagerInformasiTugasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _hasilData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MongoDBService.getSemuaPenugasan(),
        MongoDBService.getHasilPenugasan(),
      ]);
      if (mounted) {
        setState(() {
          _allData = results[0];
          _hasilData = results[1];
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

  // ============================
  // CABUT PENUGASAN
  // ============================
  void _confirmCabutPenugasan(Map<String, dynamic> penugasan) {
    final isPending = penugasan['konfirmasi_sopir'] == 'pending';
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isPending ? Icons.cancel_outlined : Icons.warning_amber_rounded,
              color: isPending ? Colors.red : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(isPending ? "Batalkan Penugasan?" : "Cabut Penugasan?"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: isPending ? "Anda akan membatalkan penugasan " : "Anda akan mencabut penugasan "),
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
            if (!isPending) ...[
              const SizedBox(height: 20),
              const Text("Alasan Pencabutan / Catatan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: "Masukkan alasan...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!isPending && reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Alasan wajib diisi")),
                );
                return;
              }
              Navigator.pop(ctx);
              _executeCabutPenugasan(penugasan['deviceId'], reasonController.text);
            },
            child: Text(isPending ? "Ya, Batalkan" : "Ya, Cabut"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCabutPenugasan(String deviceId, String alasan) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await MongoDBService.cabutPenugasan(deviceId, alasan: alasan);

    if (mounted) Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Penugasan berhasil dicabut" : "Gagal mencabut penugasan"),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadData();
    }
  }

  List<Map<String, dynamic>> get _menungguKonfirmasi =>
      _allData.where((k) => k['status'] == 'Dipakai' && k['konfirmasi_sopir'] == 'pending').toList();

  List<Map<String, dynamic>> get _dijalankan =>
      _allData.where((k) => k['status'] == 'Dipakai' && k['konfirmasi_sopir'] == 'accepted').toList();

  List<Map<String, dynamic>> get _ditolak =>
      _hasilData.where((k) => k['status_penugasan'] == 'rejected').toList();

  Widget _buildList(List<Map<String, dynamic>> data, String emptyMessage, IconData emptyIcon, {bool isRejected = false}) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        return _buildPenugasanCard(data[index], isRejected: isRejected);
      },
    );
  }

  Widget _buildPenugasanCard(Map<String, dynamic> item, {bool isRejected = false}) {
    final waktuAmbil = isRejected ? item['waktu_selesai'] : item['waktu_ambil'];
    String formattedTime = '-';
    if (waktuAmbil != null) {
      try {
        formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(waktuAmbil));
      } catch (_) {}
    }

    final namaSopir = isRejected ? (item['namaSopir'] ?? '-') : (item['peminjam'] ?? '-');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: isRejected ? Colors.red[700]! : (item['konfirmasi_sopir'] == 'pending' ? Colors.amber[700]! : Colors.green[700]!),
              width: 5
            ),
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
                          namaSopir,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRejected 
                                ? Colors.red.withOpacity(0.1) 
                                : (item['konfirmasi_sopir'] == 'pending' ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRejected ? Icons.cancel : (item['konfirmasi_sopir'] == 'pending' ? Icons.access_time : Icons.circle),
                                color: isRejected ? Colors.red[700] : (item['konfirmasi_sopir'] == 'pending' ? Colors.amber[800] : Colors.green[700]),
                                size: (item['konfirmasi_sopir'] == 'pending' || isRejected) ? 14 : 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRejected ? "Ditolak" : (item['konfirmasi_sopir'] == 'pending' ? "Menunggu Konfirmasi" : "Sedang Bertugas"),
                                style: TextStyle(
                                    color: isRejected ? Colors.red[700] : (item['konfirmasi_sopir'] == 'pending' ? Colors.amber[800] : Colors.green[700]),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (isRejected && item['alasan_tolak'] != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Text(
                      "Alasan: ",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        item['alasan_tolak'],
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                )
              else
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
                          fontStyle: item['tugas'] == null ? FontStyle.italic : FontStyle.normal,
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
                    isRejected ? "Waktu Tolak: $formattedTime" : "Ditugaskan: $formattedTime",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol Cabut (hanya jika belum ditolak)
              if (!isRejected)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_return, size: 16),
                    label: const Text("Selesaikan / Cabut Penugasan"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        title: const Text("Status Penugasan"),
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.access_time, size: 20),
              text: "Pending (${_menungguKonfirmasi.length})",
            ),
            Tab(
              icon: const Icon(Icons.play_circle_outline, size: 20),
              text: "Jalan (${_dijalankan.length})",
            ),
            Tab(
              icon: const Icon(Icons.cancel_outlined, size: 20),
              text: "Ditolak (${_ditolak.length})",
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
                  _buildList(_menungguKonfirmasi, "Belum ada penugasan pending.", Icons.hourglass_empty),
                  _buildList(_dijalankan, "Belum ada penugasan yang dijalankan.", Icons.directions_car),
                  _buildList(_ditolak, "Tidak ada penugasan yang ditolak.", Icons.check_circle_outline, isRejected: true),
                ],
              ),
            ),
    );
  }
}
