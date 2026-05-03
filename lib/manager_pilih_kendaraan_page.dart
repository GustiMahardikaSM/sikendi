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

  final TextEditingController _searchKendaraanController = TextEditingController();
  String _searchKendaraanQuery = '';

  @override
  void initState() {
    super.initState();
    _loadKendaraan();
  }

  @override
  void dispose() {
    _searchKendaraanController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _filteredKendaraan {
    if (_searchKendaraanQuery.isEmpty) return _kendaraanTersedia;

    final q = _searchKendaraanQuery.toLowerCase();
    return _kendaraanTersedia.where((k) {
      final model = (k['model'] ?? '').toLowerCase();
      final plat = (k['plat'] ?? '').toLowerCase();
      return model.contains(q) || plat.contains(q);
    }).toList();
  }

  void _showFormTugas(Map<String, dynamic> kendaraan) {
    final tugasController = TextEditingController();
    final speedController = TextEditingController();
    final radiusController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text("Detail Penugasan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue[800], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("SOPIR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text(widget.sopir['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Colors.blue),
                      ),
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.blue[800], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("KENDARAAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text("${kendaraan['model']} (${kendaraan['plat']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: tugasController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi Tugas',
                    hintText: 'Contoh: Antar tamu dari bandara ke kampus',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Tugas wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Batas Kecepatan Maksimal", 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: speedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan angka (km/h)',
                    suffixText: 'km/h',
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.speed, size: 20),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Batas kecepatan wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Radius Jarak Terjauh dari Kampus", 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan angka (km)',
                    suffixText: 'km',
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.map, size: 20),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Radius wajib diisi' : null,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(ctx);
                        _submitPenugasan(
                          kendaraan['deviceId'] ?? '', 
                          tugasController.text,
                          double.tryParse(speedController.text) ?? 80.0,
                          (double.tryParse(radiusController.text) ?? 5.0) * 1000,
                        );
                      }
                    },
                    child: const Text("Simpan Penugasan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPenugasan(String deviceId, String tugas, double maxSpeed, double maxRadius) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await MongoDBService.buatPenugasan(
      deviceId: deviceId,
      namaSopir: widget.sopir['nama'] ?? 'Tanpa Nama',
      tugas: tugas,
      maxSpeed: maxSpeed,
      maxRadius: maxRadius,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Pilih Kendaraan",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        titleSpacing: 0,
        centerTitle: false,
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 8),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sopir yang ditugaskan:", style: TextStyle(color: Colors.blue[200], fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  widget.sopir['nama'] ?? 'Tanpa Nama',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: TextField(
              controller: _searchKendaraanController,
              onChanged: (val) => setState(() => _searchKendaraanQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari model / plat...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchKendaraanQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchKendaraanController.clear();
                          setState(() => _searchKendaraanQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kendaraan Tersedia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("${_filteredKendaraan.length} ditemukan", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredKendaraan.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchKendaraanQuery.isNotEmpty 
                                ? "Kendaraan tidak ditemukan." 
                                : "Tidak ada kendaraan tersedia.", 
                              style: const TextStyle(color: Colors.grey)
                            ),
                          ],
                        )
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredKendaraan.length,
                        itemBuilder: (context, index) {
                          final item = _filteredKendaraan[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.directions_car, color: Colors.green[700], size: 24),
                              ),
                              title: Text(
                                item['model'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                item['plat'] ?? '-', 
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[900],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () => _showFormTugas(item),
                                child: const Text("Pilih", style: TextStyle(fontWeight: FontWeight.bold)),
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
