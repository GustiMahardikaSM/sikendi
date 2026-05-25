import 'package:flutter/material.dart';
import 'package:sikendi/superadmin_api_service.dart';

const _primaryColor = Color(0xFF4A148C);

class SuperAdminSopirPage extends StatefulWidget {
  const SuperAdminSopirPage({super.key});

  @override
  State<SuperAdminSopirPage> createState() => _SuperAdminSopirPageState();
}

class _SuperAdminSopirPageState extends State<SuperAdminSopirPage> {
  List<Map<String, dynamic>> _sopirList = [];
  bool _isLoading = true;
  String _filterStatus = 'semua';

  @override
  void initState() {
    super.initState();
    _loadSopir();
  }

  Future<void> _loadSopir() async {
    setState(() => _isLoading = true);
    final data = await SuperAdminApiService.getAllSopir(
      status: _filterStatus == 'semua' ? null : _filterStatus,
    );
    if (mounted) setState(() { _sopirList = data; _isLoading = false; });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'aktif': return Colors.green;
      case 'pending': return Colors.orange;
      case 'ditolak': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showSopirDetail(Map<String, dynamic> sopir) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SopirDetailSheet(sopir: sopir, onRefresh: _loadSopir),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Sopir'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSopir,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _sopirList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data sopir',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSopir,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _sopirList.length,
                          itemBuilder: (_, i) => _buildSopirCard(_sopirList[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('Filter:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: _elegantDropdown(
              value: _filterStatus,
              values: const ['semua', 'aktif', 'pending', 'ditolak', 'nonaktif'],
              labels: const ['Semua', 'Aktif', 'Pending', 'Ditolak', 'Nonaktif'],
              onChanged: (v) { setState(() => _filterStatus = v!); _loadSopir(); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _elegantDropdown({
    required String value,
    required List<String> values,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
              fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          icon: const Icon(Icons.expand_more, size: 18, color: Colors.grey),
          items: List.generate(values.length, (i) => DropdownMenuItem(
            value: values[i],
            child: Text(labels[i]),
          )),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSopirCard(Map<String, dynamic> s) {
    final nama = s['nama'] ?? '-';
    final username = s['username'] ?? s['email'] ?? '-';
    final sim = s['no_sim'] ?? s['sim'] ?? '-';
    final noHp = s['no_hp'] ?? '-';
    final status = s['status_akun'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: _primaryColor),
        ),
        title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(username, style: const TextStyle(fontSize: 12)),
            if (sim != '-') Text('SIM: $sim', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (noHp != '-') Text('HP: $noHp', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            _buildChip(status, _statusColor(status)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showSopirDetail(s),
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
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ============================================================
// BOTTOM SHEET: Detail + Aksi Sopir
// ============================================================
class _SopirDetailSheet extends StatefulWidget {
  final Map<String, dynamic> sopir;
  final VoidCallback onRefresh;
  const _SopirDetailSheet({required this.sopir, required this.onRefresh});

  @override
  State<_SopirDetailSheet> createState() => _SopirDetailSheetState();
}

class _SopirDetailSheetState extends State<_SopirDetailSheet> {
  bool _isLoading = false;

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _verify(String action) async {
    String title, label, btnLabel;
    Color btnColor;
    switch (action) {
      case 'aktif':
        title = 'Aktifkan Sopir';
        label = 'mengaktifkan';
        btnLabel = 'Aktifkan';
        btnColor = Colors.green;
        break;
      case 'nonaktif':
        title = 'Nonaktifkan Sopir';
        label = 'menonaktifkan';
        btnLabel = 'Nonaktifkan';
        btnColor = Colors.orange;
        break;
      default: // 'ditolak'
        title = 'Tolak Sopir';
        label = 'menolak dan menghapus';
        btnLabel = 'Tolak';
        btnColor = Colors.red;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('Yakin ingin $label akun ${widget.sopir['nama']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(btnLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.verifySopir(
      widget.sopir['_id'].toString(),
      action,
    );
    setState(() => _isLoading = false);
    _showMsg(result['message'] ?? '', error: result['success'] != true);
    if (result['success'] == true && mounted) {
      widget.onRefresh();
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Sopir'),
        content: Text('Yakin ingin menghapus akun ${widget.sopir['nama']}? Aksi ini tidak dapat dibatalkan.'),
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
    final result = await SuperAdminApiService.deleteSopir(widget.sopir['_id'].toString());
    setState(() => _isLoading = false);
    _showMsg(result['message'] ?? '', error: result['success'] != true);
    if (result['success'] == true && mounted) {
      widget.onRefresh();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sopir;
    final status = s['status_akun'] ?? 'pending';

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
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.person, size: 32, color: _primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['nama'] ?? '-',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(s['username'] ?? s['email'] ?? '-',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          _infoRow(Icons.credit_card, 'SIM: ${s['no_sim'] ?? s['sim'] ?? '-'}'),
          _infoRow(Icons.phone, 'HP: ${s['no_hp'] ?? '-'}'),
          _infoRow(Icons.circle, 'Status: $status'),
          if (s['tgl_daftar'] != null)
            _infoRow(Icons.calendar_today, 'Daftar: ${_formatDate(s['tgl_daftar'])}'),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _primaryColor))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Aktifkan: untuk sopir yang belum/tidak aktif
                if (status == 'pending' || status == 'nonaktif' || status == 'ditolak')
                  _actionButton(
                    Icons.check_circle_outline, 'Aktifkan', Colors.green,
                    () => _verify('aktif'),
                  ),
                // Nonaktifkan: hanya untuk sopir yang sedang aktif
                if (status == 'aktif')
                  _actionButton(
                    Icons.block, 'Nonaktifkan', Colors.orange,
                    () => _verify('nonaktif'),
                  ),
                // Tolak (hapus): hanya untuk pendaftar yang masih pending
                if (status == 'pending')
                  _actionButton(
                    Icons.cancel_outlined, 'Tolak', Colors.red.shade700,
                    () => _verify('ditolak'),
                  ),
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

  String _formatDate(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return ts.toString();
    }
  }
}
