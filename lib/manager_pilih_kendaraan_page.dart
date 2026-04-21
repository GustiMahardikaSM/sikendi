import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerPilihKendaraanPage extends StatefulWidget {
  final Map<String, dynamic> sopir;

  const ManagerPilihKendaraanPage({super.key, required this.sopir});

  @override
  State<ManagerPilihKendaraanPage> createState() => _ManagerPilihKendaraanPageState();
}

class _ManagerPilihKendaraanPageState extends State<ManagerPilihKendaraanPage> {
  List<Map<String, dynamic>> _kendaraanTersedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKendaraan();
  }

  Future<void> _loadKendaraan() async {
    setState(() => _isLoading = true);
    try {
      final allPenugasan = await MongoDBService.getSemuaPenugasan();
      if (mounted) {
        setState(() {
          _kendaraanTersedia = allPenugasan.where((k) => k['status'] == 'Tersedia').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat kendaraan: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFormTugas(Map<String, dynamic> kendaraan) {
    final tugasController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment, color: Colors.blue[800]),
            ),
            const SizedBox(width: 12),
            const Text("Detail Penugasan", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Sopir: ${widget.sopir['nama'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Icon(Icons.directions_car, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Mobil: ${kendaraan['model']} (${kendaraan['plat']})", style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: tugasController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Tugas',
                  hintText: 'Contoh: Antar tamu dari bandara ke kampus',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Tugas wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text("Simpan Penugasan"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                _submitPenugasan(kendaraan['deviceId'] ?? '', tugasController.text);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitPenugasan(String deviceId, String tugas) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await MongoDBService.buatPenugasan(
      deviceId: deviceId,
      namaSopir: widget.sopir['nama'] ?? 'Tanpa Nama',
      tugas: tugas,
    );

    if (mounted) Navigator.pop(context); // close loading

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
      if (result['success']) {
        Navigator.pop(context, true); // return true to refresh parent
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Kendaraan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Menugaskan Sopir:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  widget.sopir['nama'] ?? 'Tanpa Nama',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text("Kendaraan Tersedia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _kendaraanTersedia.isEmpty
                    ? const Center(child: Text("Tidak ada kendaraan tersedia.", style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _kendaraanTersedia.length,
                        itemBuilder: (context, index) {
                          final item = _kendaraanTersedia[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.directions_car, color: Colors.green[700], size: 28),
                              ),
                              title: Text(
                                item['model'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(item['plat'] ?? '-', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showFormTugas(item),
                                child: const Text("Pilih"),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
