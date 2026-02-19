import 'package:flutter/material.dart';
import 'package:sikendi/main.dart';
import 'package:sikendi/manager_map_page.dart';
import 'package:sikendi/manager_peringatan_page.dart';
import 'package:sikendi/manager_sopir_page.dart';
import 'package:sikendi/manager_vehicle_page.dart';
import 'package:sikendi/manager_verifikasi_page.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerPage extends StatefulWidget {
  final String? focusDeviceId;

  const ManagerPage({super.key, this.focusDeviceId});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Monitoring Peta',
      'icon': Icons.map_outlined,
      'color': Colors.blueAccent,
      'page': () => const ManagerMapPage(),
    },
    {
      'title': 'Data Kendaraan',
      'icon': Icons.directions_car_filled,
      'color': Colors.orangeAccent,
      'page': () => const ManagerVehiclePage(),
    },
    {
      'title': 'Data Sopir',
      'icon': Icons.people_alt_outlined,
      'color': Colors.teal,
      'page': () => const ManagerSopirPage(),
    },
    {
      'title': 'Verifikasi Sopir',
      'icon': Icons.person_add_alt_1_outlined,
      'color': Colors.indigo,
      'page': () => const ManagerVerifikasiPage(),
    },
    {
      'title': 'Peringatan',
      'icon': Icons.notifications_active_outlined,
      'color': Colors.amber,
      'page': () => const ManagerPeringatanPage(),
    },
  ];

  Map<String, int> _summaryData = {
    'total': 0,
    'dipakai': 0,
    'tersedia': 0,
    'pending': 0,
  };
  bool _isLoadingSummary = true;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoadingSummary = true);
    final data = await MongoService.getDashboardSummary();
    if (mounted) {
      setState(() {
        _summaryData = data;
        _isLoadingSummary = false;
      });
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionPage(),
                ),
                (route) => false,
              );
            },
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => item['page']()),
          ).then((_) => _refreshDashboard()); // Refresh data when returning
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'], size: 40, color: item['color']),
                ),
                if (item['title'] == 'Verifikasi Sopir' &&
                    _summaryData['pending']! > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_summaryData['pending']}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item['title'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Manajer"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Keluar",
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.blue[900],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ringkasan Operasional",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSummaryCard(
                          "Total Armada",
                          _isLoadingSummary ? "-" : "${_summaryData['total']}",
                          Colors.blue.shade700,
                          Icons.local_shipping,
                        ),
                        _buildSummaryCard(
                          "Sedang Dipakai",
                          _isLoadingSummary
                              ? "-"
                              : "${_summaryData['dipakai']}",
                          Colors.orange.shade700,
                          Icons.speed,
                        ),
                        _buildSummaryCard(
                          "Tersedia",
                          _isLoadingSummary
                              ? "-"
                              : "${_summaryData['tersedia']}",
                          Colors.green.shade700,
                          Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSummaryCard(
                          "Verifikasi Pending",
                          _isLoadingSummary
                              ? "-"
                              : "${_summaryData['pending']}",
                          Colors.red.shade700,
                          Icons.hourglass_bottom,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Menu Utama",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // Change cross axis count to 3
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9, // Adjust aspect ratio
                ),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuCard(_menuItems[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
