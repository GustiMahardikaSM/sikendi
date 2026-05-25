import 'package:flutter/material.dart';
import 'package:sikendi/superadmin_api_service.dart';
import 'package:sikendi/constants/hierarchy.dart';

const _primaryColor = Color(0xFF4A148C);

class SuperAdminManagerPage extends StatefulWidget {
  const SuperAdminManagerPage({super.key});

  @override
  State<SuperAdminManagerPage> createState() => _SuperAdminManagerPageState();
}

class _SuperAdminManagerPageState extends State<SuperAdminManagerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _managers = [];
  bool _isLoading = true;
  String _filterLevel = 'semua';
  String _filterStatus = 'semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadManagers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    setState(() => _isLoading = true);
    final data = await SuperAdminApiService.getAllManagers(
      status: _filterStatus == 'semua' ? null : _filterStatus,
      level: _filterLevel == 'semua' ? null : _filterLevel,
    );
    if (mounted) setState(() { _managers = data; _isLoading = false; });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'aktif': return Colors.green;
      case 'pending': return Colors.orange;
      case 'ditolak': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _levelColor(String? level) {
    switch (level) {
      case 'universitas': return Colors.indigo;
      case 'fakultas': return Colors.teal;
      case 'departemen': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  void _showManagerDetail(Map<String, dynamic> manager) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManagerDetailSheet(
        manager: manager,
        onRefresh: _loadManagers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Manager'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Daftar Manager'),
            Tab(icon: Icon(Icons.person_add), text: 'Tambah Manager'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Daftar Manager
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                    : _managers.isEmpty
                        ? const Center(child: Text('Tidak ada data manager'))
                        : RefreshIndicator(
                            onRefresh: _loadManagers,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _managers.length,
                              itemBuilder: (_, i) => _buildManagerCard(_managers[i]),
                            ),
                          ),
              ),
            ],
          ),
          // TAB 2: Tambah Manager
          _AddManagerForm(onSuccess: () {
            _loadManagers();
            _tabController.animateTo(0);
          }),
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
          Expanded(
            child: _elegantDropdown(
              label: 'Level',
              value: _filterLevel,
              values: const ['semua', 'universitas', 'fakultas', 'departemen'],
              labels: const ['Semua', 'Universitas', 'Fakultas', 'Departemen'],
              onChanged: (v) { setState(() => _filterLevel = v!); _loadManagers(); },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _elegantDropdown(
              label: 'Status',
              value: _filterStatus,
              values: const ['semua', 'aktif', 'pending', 'ditolak'],
              labels: const ['Semua', 'Aktif', 'Pending', 'Ditolak'],
              onChanged: (v) { setState(() => _filterStatus = v!); _loadManagers(); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _elegantDropdown({
    required String label,
    required String value,
    required List<String> values,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.grey, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Container(
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
        ),
      ],
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> m) {
    final nama = m['nama_manager'] ?? '-';
    final email = m['email_manager'] ?? '-';
    final level = m['level'] ?? '-';
    final status = m['status_akun'] ?? '-';
    final fakultas = m['fakultas'];
    final departemen = m['departemen'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _levelColor(level).withValues(alpha: 0.15),
          child: Icon(Icons.person, color: _levelColor(level)),
        ),
        title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 12)),
            if (fakultas != null) Text(fakultas, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (departemen != null) Text(departemen, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildChip(level, _levelColor(level)),
                const SizedBox(width: 6),
                _buildChip(status, _statusColor(status)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showManagerDetail(m),
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

// =============================================
// BOTTOM SHEET: Detail + Aksi Manager
// =============================================
class _ManagerDetailSheet extends StatefulWidget {
  final Map<String, dynamic> manager;
  final VoidCallback onRefresh;
  const _ManagerDetailSheet({required this.manager, required this.onRefresh});

  @override
  State<_ManagerDetailSheet> createState() => _ManagerDetailSheetState();
}

class _ManagerDetailSheetState extends State<_ManagerDetailSheet> {
  bool _isLoading = false;

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _toggleStatus() async {
    final current = widget.manager['status_akun'] ?? 'aktif';
    final newStatus = current == 'aktif' ? 'nonaktif' : 'aktif';
    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.editManager(
      widget.manager['_id'].toString(),
      {'status_akun': newStatus},
    );
    setState(() => _isLoading = false);
    _showMsg(result['message'] ?? '', error: result['success'] != true);
    if (result['success'] == true && mounted) { widget.onRefresh(); Navigator.pop(context); }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Manager'),
        content: Text('Yakin ingin menghapus ${widget.manager['nama_manager']}? Aksi ini tidak dapat dibatalkan.'),
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
    final result = await SuperAdminApiService.deleteManager(widget.manager['_id'].toString());
    setState(() => _isLoading = false);
    _showMsg(result['message'] ?? '', error: result['success'] != true);
    if (result['success'] == true && mounted) { widget.onRefresh(); Navigator.pop(context); }
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditManagerForm(
        manager: widget.manager,
        onSuccess: () { widget.onRefresh(); Navigator.pop(context); },
      ),
    );
  }

  void _showResetPasswordDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password Baru (min 6 karakter)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              if (ctrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password minimal 6 karakter'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final result = await SuperAdminApiService.resetManagerPassword(
                widget.manager['_id'].toString(), ctrl.text);
              setState(() => _isLoading = false);
              _showMsg(result['message'] ?? '', error: result['success'] != true);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manager;
    final status = m['status_akun'] ?? 'aktif';
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
            child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(m['nama_manager'] ?? '-',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(m['email_manager'] ?? '-', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          if (m['no_hp'] != null) _infoRow(Icons.phone, m['no_hp']),
          _infoRow(Icons.badge, 'Level: ${m['level'] ?? '-'}'),
          if (m['fakultas'] != null) _infoRow(Icons.school, m['fakultas']),
          if (m['departemen'] != null) _infoRow(Icons.domain, m['departemen']),
          _infoRow(Icons.circle, 'Status: $status'),
          const SizedBox(height: 20),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: _primaryColor))
          else Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(Icons.edit, 'Edit', Colors.blue, _showEditSheet),
              _actionButton(Icons.lock_reset, 'Reset Password', Colors.orange, _showResetPasswordDialog),
              _actionButton(
                status == 'aktif' ? Icons.block : Icons.check_circle,
                status == 'aktif' ? 'Nonaktifkan' : 'Aktifkan',
                status == 'aktif' ? Colors.grey : Colors.green,
                _toggleStatus,
              ),
              _actionButton(Icons.delete_forever, 'Hapus', Colors.red, _confirmDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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

// =============================================
// FORM: Edit Manager
// =============================================
class _EditManagerForm extends StatefulWidget {
  final Map<String, dynamic> manager;
  final VoidCallback onSuccess;
  const _EditManagerForm({required this.manager, required this.onSuccess});

  @override
  State<_EditManagerForm> createState() => _EditManagerFormState();
}

class _EditManagerFormState extends State<_EditManagerForm> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _hpCtrl;
  late String _level;
  String? _fakultas;
  String? _departemen;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.manager['nama_manager'] ?? '');
    _hpCtrl = TextEditingController(text: widget.manager['no_hp'] ?? '');
    _level = widget.manager['level'] ?? 'departemen';
    _fakultas = widget.manager['fakultas'];
    _departemen = widget.manager['departemen'];
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.editManager(
      widget.manager['_id'].toString(),
      {
        'nama': _namaCtrl.text.trim(),
        'no_hp': _hpCtrl.text.trim(),
        'level': _level,
        'fakultas': _level == 'universitas' ? null : _fakultas,
        'departemen': _level == 'departemen' ? _departemen : null,
      },
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));
    if (result['success'] == true) widget.onSuccess();
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
            const Text('Edit Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _hpCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _level,
              decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'universitas', child: Text('Universitas')),
                DropdownMenuItem(value: 'fakultas', child: Text('Fakultas')),
                DropdownMenuItem(value: 'departemen', child: Text('Departemen')),
              ],
              onChanged: (v) => setState(() { _level = v!; _fakultas = null; _departemen = null; }),
            ),
            if (_level != 'universitas') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _fakultas,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fakultas', border: OutlineInputBorder()),
                items: HierarchyData.listFakultas
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() { _fakultas = v; _departemen = null; }),
              ),
            ],
            if (_level == 'departemen' && _fakultas != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _departemen,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Departemen', border: OutlineInputBorder()),
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
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// FORM: Tambah Manager Baru
// =============================================
class _AddManagerForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AddManagerForm({required this.onSuccess});

  @override
  State<_AddManagerForm> createState() => _AddManagerFormState();
}

class _AddManagerFormState extends State<_AddManagerForm> {
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();
  String _level = 'departemen';
  String? _fakultas;
  String? _departemen;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _hpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_namaCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, email, dan password wajib diisi'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final result = await SuperAdminApiService.createManager(
      nama: _namaCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      level: _level,
      noHp: _hpCtrl.text.trim().isNotEmpty ? _hpCtrl.text.trim() : null,
      fakultas: _level != 'universitas' ? _fakultas : null,
      departemen: _level == 'departemen' ? _departemen : null,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));
    if (result['success'] == true) {
      _namaCtrl.clear(); _emailCtrl.clear(); _passwordCtrl.clear(); _hpCtrl.clear();
      setState(() { _level = 'departemen'; _fakultas = null; _departemen = null; });
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
          const Text('Tambah Manager Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Manager akan langsung berstatus aktif', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          TextField(controller: _namaCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 12),
          TextField(controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _hpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _level,
            decoration: const InputDecoration(labelText: 'Level *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
            items: const [
              DropdownMenuItem(value: 'universitas', child: Text('Universitas')),
              DropdownMenuItem(value: 'fakultas', child: Text('Fakultas')),
              DropdownMenuItem(value: 'departemen', child: Text('Departemen')),
            ],
            onChanged: (v) => setState(() { _level = v!; _fakultas = null; _departemen = null; }),
          ),
          if (_level != 'universitas') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fakultas,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fakultas *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.school)),
              items: HierarchyData.listFakultas
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() { _fakultas = v; _departemen = null; }),
            ),
          ],
          if (_level == 'departemen' && _fakultas != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _departemen,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Departemen *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.domain)),
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
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.person_add),
            label: Text(_isLoading ? 'Menyimpan...' : 'Buat Manager'),
          ),
        ],
      ),
    );
  }
}
