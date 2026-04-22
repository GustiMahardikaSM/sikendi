import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/constants/hierarchy.dart';
import 'package:sikendi/manager_detail_page.dart';

class ManagerListPage extends StatefulWidget {
  const ManagerListPage({super.key});

  @override
  State<ManagerListPage> createState() => _ManagerListPageState();
}

class _ManagerListPageState extends State<ManagerListPage> {
  late Future<List<Map<String, dynamic>>> _managersFuture;
  List<Map<String, dynamic>> _allManagers = [];
  List<Map<String, dynamic>> _filteredManagers = [];
  
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _currentUser;
  
  String? _selectedFakultas;
  String? _selectedDepartemen;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _currentUser = await AuthService.getCurrentUser();
    await _refreshList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshList() async {
    final data = await MongoDBService.getManagerHierarchy();
    if (mounted) {
      setState(() {
        _allManagers = data;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredManagers = _allManagers.where((m) {
        // Search
        final matchesSearch = (m['nama_manager'] ?? '').toLowerCase().contains(query) ||
            (m['email_manager'] ?? '').toLowerCase().contains(query) ||
            (m['no_hp'] ?? '').contains(query);
            
        // Faculty Filter
        final matchesFakultas = _selectedFakultas == null || m['fakultas'] == _selectedFakultas;
        
        // Department Filter
        final matchesDepartemen = _selectedDepartemen == null || m['departemen'] == _selectedDepartemen;

        return matchesSearch && matchesFakultas && matchesDepartemen;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Manager"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildSearchAndFilterSection(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshList,
                  child: _filteredManagers.isEmpty
                      ? const Center(child: Text("Tidak ada data manager yang cocok."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredManagers.length,
                          itemBuilder: (context, index) {
                            final manager = _filteredManagers[index];
                            return _buildManagerCard(manager);
                          },
                        ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    final bool isUniv = _currentUser?['level'] == 'universitas';
    final bool isFak = _currentUser?['level'] == 'fakultas';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => _applyFilters(),
            decoration: InputDecoration(
              hintText: "Cari Nama/Gmail/No HP...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isUniv) ...[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFakultas,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Fakultas",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Semua")),
                      ...HierarchyData.listFakultas.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedFakultas = v;
                        _selectedDepartemen = null;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isUniv || isFak) ...[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDepartemen,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Departemen",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Semua")),
                      if (isFak)
                        ...HierarchyData.getDepartemen(_currentUser?['fakultas'] ?? '').map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                      else if (_selectedFakultas != null)
                        ...HierarchyData.getDepartemen(_selectedFakultas!).map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedDepartemen = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> manager) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.person, color: Colors.blue[900]),
        ),
        title: Text(
          manager['nama_manager'] ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(manager['email_manager'] ?? 'N/A'),
            const SizedBox(height: 2),
            Text(
              "${manager['level']?.toUpperCase()}${manager['fakultas'] != null ? ' - ${manager['fakultas']}' : ''}${manager['departemen'] != null ? ' - ${manager['departemen']}' : ''}",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ManagerDetailPage(manager: manager)),
          );
        },
      ),
    );
  }
}
