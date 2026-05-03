import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/constants/hierarchy.dart';
import 'package:sikendi/manager_detail_page.dart';
import 'package:shimmer/shimmer.dart';

class ManagerListPage extends StatefulWidget {
  const ManagerListPage({super.key});

  @override
  State<ManagerListPage> createState() => _ManagerListPageState();
}

class _ManagerListPageState extends State<ManagerListPage> {
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
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshList,
        color: Colors.blue[900],
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true, // Make it reappear when scrolling up
              centerTitle: false,
              titleSpacing: 0,
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
              elevation: 2,
              title: const Text(
                "Data Manager",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSearchAndFilterSection(context),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildShimmerCard(),
                    childCount: 5,
                  ),
                ),
              )
            else if (_filteredManagers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final manager = _filteredManagers[index];
                      return _buildManagerCard(manager);
                    },
                    childCount: _filteredManagers.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => _applyFilters(),
        decoration: InputDecoration(
          hintText: "Cari Nama/Gmail/No HP...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _showFilterBottomSheet(context),
                color: Colors.blue[900],
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final bool isUniv = _currentUser?['level'] == 'universitas';
    final bool isFak = _currentUser?['level'] == 'fakultas';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Filter Data Manager",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedFakultas = null;
                            _selectedDepartemen = null;
                          });
                          setState(() => _applyFilters());
                        },
                        child: const Text("Reset"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isUniv) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedFakultas,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Fakultas",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("Semua Fakultas")),
                        ...HierarchyData.listFakultas.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          _selectedFakultas = v;
                          _selectedDepartemen = null;
                        });
                        setState(() => _applyFilters());
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isUniv || isFak) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedDepartemen,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Departemen",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("Semua Departemen")),
                        if (isFak)
                          ...HierarchyData.getDepartemen(_currentUser?['fakultas'] ?? '').map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                        else if (_selectedFakultas != null)
                          ...HierarchyData.getDepartemen(_selectedFakultas!).map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setModalState(() => _selectedDepartemen = v);
                        setState(() => _applyFilters());
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Terapkan Filter", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ManagerDetailPage(manager: manager)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.person, color: Colors.blue[900]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manager['nama_manager'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        manager['email_manager'] ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildChip(manager['level']?.toUpperCase() ?? 'N/A', Colors.blue),
                          if (manager['fakultas'] != null)
                            _buildChip(manager['fakultas'], Colors.orange),
                          if (manager['departemen'] != null)
                            _buildChip(manager['departemen'], Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Manager tidak ditemukan",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            "Coba ubah kata kunci atau filter pencarian Anda.",
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
