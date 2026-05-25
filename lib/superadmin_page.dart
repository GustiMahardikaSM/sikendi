import 'package:flutter/material.dart';
import 'package:sikendi/main.dart';
import 'package:sikendi/manager_map_page.dart';
import 'package:sikendi/manager_peringatan_page.dart';
import 'package:sikendi/manager_sopir_page.dart';
import 'package:sikendi/manager_penugasan_page.dart';
import 'package:sikendi/manager_vehicle_page.dart';
import 'package:sikendi/manager_verifikasi_page.dart';
import 'package:sikendi/manager_informasi_tugas_page.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/manager_list_page.dart';
import 'package:sikendi/manager_laporan_penugasan_page.dart';
import 'package:sikendi/superadmin_manager_page.dart';
import 'package:sikendi/superadmin_logs_page.dart';
import 'package:sikendi/superadmin_sopir_page.dart';
import 'package:sikendi/superadmin_kendaraan_page.dart';
import 'package:sikendi/superadmin_api_service.dart';

const _primaryColor = Color(0xFF4A148C);
const _primaryLight = Color(0xFF6A1B9A);
const _accentColor = Color(0xFFFFD700);

class SuperAdminPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const SuperAdminPage({super.key, this.user});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  final List<Map<String, dynamic>> _menuItems = [
    // ---- EKSKLUSIF SUPERADMIN (tampil pertama) ----
    {
      'title': 'Kelola Manager',
      'icon': Icons.admin_panel_settings,
      'color': _primaryColor,
      'page': () => const SuperAdminManagerPage(),
      'isExclusive': true,
    },
    {
      'title': 'Kelola Sopir',
      'icon': Icons.people_alt,
      'color': Color(0xFF1565C0),
      'page': () => const SuperAdminSopirPage(),
      'isExclusive': true,
    },
    {
      'title': 'Kelola Kendaraan',
      'icon': Icons.directions_car_filled,
      'color': Color(0xFF00695C),
      'page': () => const SuperAdminKendaraanPage(),
      'isExclusive': true,
    },
    {
      'title': 'Log Aktivitas',
      'icon': Icons.receipt_long,
      'color': Color(0xFF4A148C),
      'page': () => const SuperAdminLogsPage(),
      'isExclusive': true,
    },
    // ---- MENU MANAJERIAL SHARED ----
    {
      'title': 'Monitoring Peta',
      'icon': Icons.map_outlined,
      'color': Colors.blueAccent,
      'page': () => const ManagerMapPage(),
    },
    {
      'title': 'Data Kendaraan',
      'icon': Icons.car_rental,
      'color': Colors.orangeAccent,
      'page': () => const ManagerVehiclePage(),
    },
    {
      'title': 'Data Sopir',
      'icon': Icons.badge_outlined,
      'color': Colors.teal,
      'page': () => const ManagerSopirPage(),
    },
    {
      'title': 'Penugasan Sopir',
      'icon': Icons.assignment_ind,
      'color': Colors.deepPurple,
      'page': () => const ManagerPenugasanPage(),
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
    {
      'title': 'Status Penugasan',
      'icon': Icons.history_edu,
      'color': Colors.blueGrey,
      'page': () => const ManagerInformasiTugasPage(),
    },
    {
      'title': 'Laporan Penugasan',
      'icon': Icons.description_outlined,
      'color': Color(0xFF1A237E),
      'page': () => const ManagerLaporanPenugasanPage(),
    },
    {
      'title': 'Verifikasi Manajer',
      'icon': Icons.manage_accounts,
      'color': Colors.redAccent,
      'page': () => const ManagerVerifikasiPage(isManagerVerif: true),
    },
    {
      'title': 'Data Manajer',
      'icon': Icons.group_outlined,
      'color': Colors.blueGrey,
      'page': () => const ManagerListPage(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    final data = await SuperAdminApiService.getStats();
    if (mounted) {
      setState(() { _stats = data; _isLoadingStats = false; });
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Row(children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text('Sedang keluar, mohon tunggu...'),
                  ]),
                ),
              );
              await AuthService.logout();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Dashboard Superadmin',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'SA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header stats
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Halo, Superadmin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Akses penuh ke seluruh sistem',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Statistik Sistem',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingStats)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else ...[
                      Row(children: [
                        _statCard('Total Manager', '${_stats?['totalManager'] ?? 0}',
                            Icons.manage_accounts, Colors.blue.shade700),
                        _statCard('Total Sopir', '${_stats?['totalSopir'] ?? 0}',
                            Icons.people, Colors.teal.shade700),
                        _statCard('Total Armada', '${_stats?['totalKendaraan'] ?? 0}',
                            Icons.directions_car, Colors.orange.shade700),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _statCard('Dipakai', '${_stats?['kendaraanDipakai'] ?? 0}',
                            Icons.speed, Colors.deepOrange.shade700),
                        _statCard('Manajer Pending', '${_stats?['managerPending'] ?? 0}',
                            Icons.admin_panel_settings, Colors.purple.shade700),
                        _statCard('Sopir Pending', '${_stats?['sopirPending'] ?? 0}',
                            Icons.person_search, Colors.red.shade700),
                      ]),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section label eksklusif
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: _accentColor),
                        SizedBox(width: 6),
                        Text(
                          'Fitur Eksklusif Superadmin',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tambah, edit, dan hapus data secara langsung',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 130,
                ),
                itemCount: 4,
                itemBuilder: (_, i) => _buildMenuCard(_menuItems[i]),
              ),

              const SizedBox(height: 16),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Menu Manajerial',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 130,
                ),
                itemCount: _menuItems.length - 4,
                itemBuilder: (_, i) => _buildMenuCard(_menuItems[i + 4]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> item) {
    final isExclusive = item['isExclusive'] == true;
    return Card(
      elevation: isExclusive ? 6 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isExclusive
            ? const BorderSide(color: _primaryColor, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item['page']()),
          ).then((_) => _loadStats());
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'], size: 30, color: item['color']),
                    ),
                    if (isExclusive)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, size: 10, color: _accentColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['title'],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isExclusive ? _primaryColor : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
