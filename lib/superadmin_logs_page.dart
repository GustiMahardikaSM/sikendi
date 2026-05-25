import 'package:flutter/material.dart';
import 'package:sikendi/superadmin_api_service.dart';

const _primaryColor = Color(0xFF4A148C);

class SuperAdminLogsPage extends StatefulWidget {
  const SuperAdminLogsPage({super.key});

  @override
  State<SuperAdminLogsPage> createState() => _SuperAdminLogsPageState();
}

class _SuperAdminLogsPageState extends State<SuperAdminLogsPage> {
  final List<Map<String, dynamic>> _logs = [];
  final TextEditingController _emailFilterCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadLogs(reset: true);
  }

  @override
  void dispose() {
    _emailFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (reset) {
      setState(() { _isLoading = true; _currentPage = 1; _logs.clear(); });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final result = await SuperAdminApiService.getAllLogs(
      page: reset ? 1 : _currentPage,
      emailFilter: _emailFilterCtrl.text.trim().isNotEmpty ? _emailFilterCtrl.text.trim() : null,
    );

    if (!mounted) return;
    final data = List<Map<String, dynamic>>.from(result['data'] ?? []);
    final meta = result['metadata'] ?? {};

    setState(() {
      if (reset) _logs.clear();
      _logs.addAll(data);
      _currentPage = (meta['currentPage'] ?? 1) + 1;
      _totalPages = meta['totalPages'] ?? 1;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'assignment_start': return Icons.assignment_ind;
      case 'assignment_cancelled': return Icons.assignment_return;
      case 'manager_verify': return Icons.verified_user;
      case 'vehicle_add': return Icons.directions_car;
      default: return Icons.info_outline;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'assignment_start': return Colors.green;
      case 'assignment_cancelled': return Colors.red;
      case 'manager_verify': return Colors.blue;
      case 'vehicle_add': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Aktivitas Global'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLogs(reset: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search / filter bar
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailFilterCtrl,
                    decoration: InputDecoration(
                      hintText: 'Filter by email manager...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _emailFilterCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _emailFilterCtrl.clear();
                                _loadLogs(reset: true);
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _loadLogs(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadLogs(reset: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: const Text('Cari'),
                ),
              ],
            ),
          ),

          // Log list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _logs.isEmpty
                    ? const Center(child: Text('Tidak ada log aktivitas'))
                    : RefreshIndicator(
                        onRefresh: () => _loadLogs(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _logs.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _logs.length) {
                              return _buildLoadMoreButton();
                            }
                            return _buildLogTile(_logs[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final type = log['type']?.toString();
    final icon = _iconForType(type);
    final color = _colorForType(type);
    final desc = log['description']?.toString() ?? '-';
    final email = log['manager_email']?.toString() ?? '-';
    final ts = _formatTimestamp(log['timestamp']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(desc, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.person, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
            ]),
            Row(children: [
              const Icon(Icons.access_time, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(ts, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_currentPage > _totalPages) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Semua log telah dimuat', style: TextStyle(color: Colors.grey))),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _isLoadingMore
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : ElevatedButton.icon(
              onPressed: () => _loadLogs(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.expand_more),
              label: const Text('Muat Lebih Banyak'),
            ),
    );
  }
}
