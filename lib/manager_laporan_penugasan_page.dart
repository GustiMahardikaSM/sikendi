import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/manager_laporan_detail_page.dart';
import 'package:intl/intl.dart';

class ManagerLaporanPenugasanPage extends StatefulWidget {
  const ManagerLaporanPenugasanPage({super.key});

  @override
  State<ManagerLaporanPenugasanPage> createState() => _ManagerLaporanPenugasanPageState();
}

class _ManagerLaporanPenugasanPageState extends State<ManagerLaporanPenugasanPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingRecent = true;
  bool _isLoadingDrivers = true;
  List<Map<String, dynamic>> _recentReports = [];
  Map<String, dynamic> _metadata = {};
  int _currentPage = 1;
  int _currentLimit = 10;
  List<Map<String, dynamic>> _drivers = [];
  String _driverSearchQuery = "";
  final TextEditingController _driverSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _driverSearchQuery = "";
    _loadData();
    _loadDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingRecent = true);
    final response = await MongoDBService.getPenugasanSelesaiRecent(
      page: _currentPage,
      limit: _currentLimit,
    );
    if (mounted) {
      setState(() {
        _recentReports = (response['data'] as List).cast<Map<String, dynamic>>();
        _metadata = response['metadata'] ?? {};
        _isLoadingRecent = false;
      });
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingDrivers = true);
    final drivers = await MongoDBService.getSemuaSopir();
    if (mounted) {
      setState(() {
        _drivers = drivers;
        _isLoadingDrivers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Hasil Penugasan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Terbaru", icon: Icon(Icons.history)),
            Tab(text: "Berdasarkan Sopir", icon: Icon(Icons.person_pin)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentTab(),
          _buildDriversTab(),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_isLoadingRecent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentReports.isEmpty) {
      return _buildEmptyState("Belum ada laporan penugasan selesai.");
    }

    return Column(
      children: [
        // --- LIMIT SELECTOR & INFO ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total: ${_metadata['totalRecords'] ?? 0} laporan",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              Row(
                children: [
                  const Text("Tampilkan: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _currentLimit,
                        items: [10, 25, 50, 100].map((int val) {
                          return DropdownMenuItem<int>(
                            value: val,
                            child: Text(val.toString(), style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _currentLimit = val;
                              _currentPage = 1;
                            });
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _recentReports.length,
              itemBuilder: (context, index) {
                final report = _recentReports[index];
                return _buildReportCard(report);
              },
            ),
          ),
        ),

        // --- PAGINATION CONTROLS ---
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final int totalPages = _metadata['totalPages'] ?? 1;
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Back Button
          _buildPageNavButton(
            icon: Icons.chevron_left,
            onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
          ),
          
          const SizedBox(width: 8),

          // Page Numbers
          ..._buildPageNumbers(totalPages),

          const SizedBox(width: 8),

          // Next Button
          _buildPageNavButton(
            icon: Icons.chevron_right,
            onPressed: _currentPage < totalPages ? () => _changePage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> widgets = [];
    
    // Logic to show pages with ellipses if too many
    if (totalPages <= 5) {
      for (int i = 1; i <= totalPages; i++) {
        widgets.add(_buildPageNumberButton(i));
      }
    } else {
      // Always show first
      widgets.add(_buildPageNumberButton(1));

      if (_currentPage > 3) widgets.add(const Text("..."));

      // Show current and neighbors
      int start = _currentPage - 1;
      int end = _currentPage + 1;
      if (start < 2) start = 2;
      if (end > totalPages - 1) end = totalPages - 1;

      for (int i = start; i <= end; i++) {
        widgets.add(_buildPageNumberButton(i));
      }

      if (_currentPage < totalPages - 2) widgets.add(const Text("..."));

      // Always show last
      widgets.add(_buildPageNumberButton(totalPages));
    }
    return widgets;
  }

  Widget _buildPageNumberButton(int page) {
    bool isSelected = _currentPage == page;
    return GestureDetector(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[900] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.blue[900],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavButton({required IconData icon, VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: Colors.blue[900],
      disabledColor: Colors.grey[300],
    );
  }

  void _changePage(int page) {
    setState(() => _currentPage = page);
    _loadData();
  }

  Widget _buildDriversTab() {
    if (_isLoadingDrivers) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredDrivers = _drivers.where((sopir) {
      final name = (sopir['nama'] ?? sopir['nama_lengkap'] ?? sopir['username'] ?? '').toString().toLowerCase();
      final email = (sopir['email'] ?? '').toString().toLowerCase();
      final phone = (sopir['no_hp'] ?? '').toString().toLowerCase();
      final query = _driverSearchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();

    return Column(
      children: [
        // --- SEARCH BAR (Diperhalus) ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _driverSearchController,
            onChanged: (val) => setState(() => _driverSearchQuery = val),
            decoration: InputDecoration(
              hintText: "Cari nama, email, atau no hp...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _driverSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _driverSearchController.clear();
                        setState(() => _driverSearchQuery = "");
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),

        Expanded(
          child: filteredDrivers.isEmpty
              ? _buildEmptyState(_driverSearchQuery.isEmpty
                  ? "Data sopir tidak ditemukan."
                  : "Sopir tidak ditemukan.")
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = filteredDrivers[index];
                    return _buildDriverListTile(driver);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final date = DateTime.parse(report['waktu_selesai']).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ManagerLaporanDetailPage(report: report)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${report['model']} (${report['plat']})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: report['alasan_pencabutan'] != null ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report['alasan_pencabutan'] != null ? "Dicabut" : "Selesai",
                      style: TextStyle(
                        color: report['alasan_pencabutan'] != null ? Colors.red[700] : Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("Sopir: ${report['namaSopir']}", style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.route, "${report['jarak_km']} km"),
                  _buildMiniStat(Icons.speed, "${report['kecepatan_maksimal']} km/h"),
                  _buildMiniStat(Icons.timer_outlined, "${report['durasi_menit']}m"),
                  if (report['predominant_driving_style'] != null)
                    _buildDrivingStyleBadge(report['predominant_driving_style']),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blue[900]),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[900])),
      ],
    );
  }

  Widget _buildDrivingStyleBadge(String style) {
    Color color = Colors.grey;
    if (style == 'Defensive Driving') {
      color = Colors.green;
    } else if (style == 'Normal Driving') {
      color = Colors.blue;
    } else if (style == 'Aggressive Driving') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        style.replaceFirst(' Driving', ''),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDriverListTile(Map<String, dynamic> driver) {
    final name = driver['nama'] ?? driver['username'] ?? 'Tanpa Nama';
    final phone = driver['no_hp'] ?? driver['email'] ?? 'Tidak ada kontak';
    
    final String initial = name.toString().trim().isNotEmpty 
        ? name.toString().trim()[0].toUpperCase() 
        : '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDriverReports(driver),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue[100],
                child: Text(
                  initial, 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.blue[900]
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Laporan", style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: Colors.blue[800]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverReports(Map<String, dynamic> driver) async {
    final nama = driver['nama'] ?? driver['username'];
    if (nama == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Laporan Penugasan: $nama",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: MongoDBService.getPenugasanSelesaiBySopir(nama),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Belum ada laporan selesai."));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) => _buildReportCard(snapshot.data![index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}
