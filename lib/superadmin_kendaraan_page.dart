import 'package:flutter/material.dart';
import 'package:sikendi/superadmin_api_service.dart';
import 'package:sikendi/constants/hierarchy.dart';

const _primaryColor = Color(0xFF4A148C);

class SuperAdminKendaraanPage extends StatefulWidget {
  const SuperAdminKendaraanPage({super.key});

  @override
  State<SuperAdminKendaraanPage> createState() => _SuperAdminKendaraanPageState();
}

class _SuperAdminKendaraanPageState extends State<SuperAdminKendaraanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _kendaraanList = [];
  bool _isLoading = true;
  String _filterStatus = 'semua';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
    _loadKendaraan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKendaraan() async {
    setState(() => _isLoading = true);
    final data = await SuperAdminApiService.getAllKendaraan(
      status: _filterStatus == 'semua' ? null : _filterStatus,
    );
    if (mounted) setState(() { _kendaraanList = data; _isLoading = false; });
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.isEmpty) return _kendaraanList;
    return _kendaraanList.where((k) {
      final plat = (k['plat'] ?? '').toString().toLowerCase();
      final model = (k['model'] ?? '').toString().toLowerCase();
      return plat.contains(_searchQuery) || model.contains(_searchQuery);
    }).toList();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Tersedia': return Colors.green;
      case 'Dipakai': return Colors.orange;
      default: return Colors.grey;
    }
  }

  void _showKendaraanDetail(Map<String, dynamic> k) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _KendaraanDetailSheet(
        kendaraan: k,
        onRefresh: _loadKendaraan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kendaraan'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: 'Daftar Armada'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Tambah'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Daftar Kendaraan
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                    : _filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('Tidak ada kendaraan',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadKendaraan,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredList.length,
                              itemBuilder: (_, i) => _buildKendaraanCard(_filteredList[i]),
                            ),
                          ),
              ),
            ],
          ),
          // TAB 2: Tambah Kendaraan
          _AddKendaraanForm(onSuccess: () {
            _loadKendaraan();
            _tabController.animateTo(0);
          }),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari plat atau model...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchCtrl.clear(); },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterStatus,
                  isDense: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  items: ['semua', 'Tersedia', 'Dipakai']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) { _filterStatus = v!; _loadKendaraan(); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKendaraanCard(Map<String, dynamic> k) {
    final plat = k['plat'] ?? '-';
    final model = k['model'] ?? '-';
    final status = k['status'] ?? '-';
    final peminjam = k['peminjam'];
    final kepemilikan = k['kepemilikan'] ?? 'universitas';
    final fakultas = k['fakultas'];
    final departemen = k['departemen'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(Icons.directions_car, color: _statusColor(status)),
        ),
        title: Text(
          plat,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model, style: const TextStyle(fontSize: 12)),
            if (peminjam != null)
              Text('Peminjam: $peminjam',
                  style: const TextStyle(fontSize: 11, color: Colors.orange)),
            Text(
              [kepemilikan, if (fakultas != null) fakultas, if (departemen != null) departemen]
                  .join(' › '),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _buildChip(status, _statusColor(status)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showKendaraanDetail(k),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ============================================================
// BOTTOM SHEET: Detail + Aksi Kendaraan
// ============================================================
class _KendaraanDetailSheet extends StatefulWidget {
  final Map<String, dynamic> kendaraan;
  final VoidCallback onRefresh;
  const _KendaraanDetailSheet({required this.kendaraan, required this.onRefresh});

  @override
  State<_KendaraanDetailSheet> createState() => _KendaraanDetailSheetState();
}

class _KendaraanDetailSheetState extends State<_KendaraanDetailSheet> {
  bool _isLoading = false;

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String get _deviceId =>
      widget.kendaraan['gps_1'] ?? widget.kendaraan['device_id'] ?? widget.kendaraan['deviceId'] ?? '';

  Future<void> _confirmDelete() async {
    final k = widget.kendaraan;
    if ((k['status'] ?? '') == 'Dipakai') {
      _showMsg('Kendaraan sedang dipakai, tidak bisa dihapus.', error: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kendaraan'),
        content: Text('Yakin ingin menghapus ${k['plat']} (${k['model']})? Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.deleteKendaraan(_deviceId);
    setState(() => _isLoading = false);
    _showMsg(result['message'] ?? '', error: result['success'] != true);
    if (result['success'] == true && mounted) {
      widget.onRefresh();
      Navigator.pop(context);
    }
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditKendaraanForm(
        kendaraan: widget.kendaraan,
        onSuccess: () {
          widget.onRefresh();
          Navigator.pop(context); // Tutup edit form
          Navigator.pop(context); // Tutup detail sheet
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kendaraan;
    final status = k['status'] ?? '-';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(k['plat'] ?? '-',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(k['model'] ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          const Divider(),
          _infoRow(Icons.info_outline, 'Status: $status'),
          if (k['peminjam'] != null) _infoRow(Icons.person, 'Peminjam: ${k['peminjam']}'),
          _infoRow(Icons.account_balance, 'Kepemilikan: ${k['kepemilikan'] ?? '-'}'),
          if (k['fakultas'] != null) _infoRow(Icons.school, k['fakultas']),
          if (k['departemen'] != null) _infoRow(Icons.domain, k['departemen']),
          _infoRow(Icons.devices, 'Device ID: ${_deviceId.isNotEmpty ? _deviceId : '-'}'),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _primaryColor))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(Icons.edit, 'Edit', Colors.blue, _showEditSheet),
                if (status != 'Dipakai')
                  _actionButton(Icons.delete_forever, 'Hapus', Colors.red, _confirmDelete),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
    );
  }
}

// ============================================================
// FORM: Edit Kendaraan
// ============================================================
class _EditKendaraanForm extends StatefulWidget {
  final Map<String, dynamic> kendaraan;
  final VoidCallback onSuccess;
  const _EditKendaraanForm({required this.kendaraan, required this.onSuccess});

  @override
  State<_EditKendaraanForm> createState() => _EditKendaraanFormState();
}

class _EditKendaraanFormState extends State<_EditKendaraanForm> {
  late final TextEditingController _platCtrl;
  late final TextEditingController _modelCtrl;
  late String _kepemilikan;
  String? _fakultas;
  String? _departemen;
  bool _isLoading = false;

  String get _deviceId =>
      widget.kendaraan['gps_1'] ?? widget.kendaraan['device_id'] ?? widget.kendaraan['deviceId'] ?? '';

  @override
  void initState() {
    super.initState();
    _platCtrl = TextEditingController(text: widget.kendaraan['plat'] ?? '');
    _modelCtrl = TextEditingController(text: widget.kendaraan['model'] ?? '');
    _kepemilikan = widget.kendaraan['kepemilikan'] ?? 'universitas';
    _fakultas = widget.kendaraan['fakultas'];
    _departemen = widget.kendaraan['departemen'];
  }

  @override
  void dispose() {
    _platCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_platCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plat dan model wajib diisi'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.editKendaraan(_deviceId, {
      'plat': _platCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'kepemilikan': _kepemilikan,
      'fakultas': _kepemilikan == 'universitas' ? null : _fakultas,
      'departemen': _kepemilikan == 'departemen' ? _departemen : null,
    });
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));
    // Tutup form edit setelah 1 detik (biar snackbar terlihat)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      widget.onSuccess(); // Ini refresh + tutup edit form + tutup detail sheet
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Kendaraan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _platCtrl,
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                if (value != value.toUpperCase()) {
                  _platCtrl.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: TextSelection.fromPosition(
                      TextPosition(offset: value.length),
                    ),
                  );
                }
              },
              decoration: const InputDecoration(
                labelText: 'Plat Nomor *', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Model Kendaraan *', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _kepemilikan,
              decoration: const InputDecoration(
                labelText: 'Kepemilikan', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: ['universitas', 'fakultas', 'departemen']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                _kepemilikan = v!;
                _fakultas = null;
                _departemen = null;
              }),
            ),
            if (_kepemilikan != 'universitas') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _fakultas,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Fakultas', border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                items: HierarchyData.listFakultas
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() { _fakultas = v; _departemen = null; }),
              ),
            ],
            if (_kepemilikan == 'departemen' && _fakultas != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _departemen,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Departemen', border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.domain),
                ),
                items: HierarchyData.getDepartemen(_fakultas!)
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _departemen = v),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FORM: Tambah Kendaraan Baru
// ============================================================
class _AddKendaraanForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AddKendaraanForm({required this.onSuccess});

  @override
  State<_AddKendaraanForm> createState() => _AddKendaraanFormState();
}

class _AddKendaraanFormState extends State<_AddKendaraanForm> {
  final _platCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _deviceCtrl = TextEditingController();
  String _kepemilikan = 'universitas';
  String? _fakultas;
  String? _departemen;
  bool _isLoading = false;

  @override
  void dispose() {
    _platCtrl.dispose();
    _modelCtrl.dispose();
    _deviceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_platCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty ||
        _deviceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plat, model, dan Device ID wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.addKendaraan(
      plat: _platCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      deviceId: _deviceCtrl.text.trim(),
      kepemilikan: _kepemilikan,
      fakultas: _kepemilikan != 'universitas' ? _fakultas : null,
      departemen: _kepemilikan == 'departemen' ? _departemen : null,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));
    if (result['success'] == true) {
      _platCtrl.clear();
      _modelCtrl.clear();
      _deviceCtrl.clear();
      setState(() { _kepemilikan = 'universitas'; _fakultas = null; _departemen = null; });
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Tambah Kendaraan Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Kendaraan langsung berstatus Tersedia',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          TextField(
            controller: _platCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Plat Nomor *', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pin),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Model Kendaraan *', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_car),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deviceCtrl,
            decoration: const InputDecoration(
              labelText: 'Device ID (GPS) *', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.gps_fixed),
              hintText: 'ID perangkat GPS tracker',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _kepemilikan,
            decoration: const InputDecoration(
              labelText: 'Kepemilikan *', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance),
            ),
            items: ['universitas', 'fakultas', 'departemen']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() {
              _kepemilikan = v!;
              _fakultas = null;
              _departemen = null;
            }),
          ),
          if (_kepemilikan != 'universitas') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fakultas,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fakultas *', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              items: HierarchyData.listFakultas
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() { _fakultas = v; _departemen = null; }),
            ),
          ],
          if (_kepemilikan == 'departemen' && _fakultas != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _departemen,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Departemen *', border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.domain),
              ),
              items: HierarchyData.getDepartemen(_fakultas!)
                  .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _departemen = v),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isLoading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add),
            label: Text(_isLoading ? 'Menyimpan...' : 'Tambah Kendaraan'),
          ),
        ],
      ),
    );
  }
}
