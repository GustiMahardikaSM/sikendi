import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:intl/intl.dart';

// ==========================================================
// HALAMAN DETAIL KENDARAAN
// ==========================================================
class VehicleDetailPage extends StatefulWidget {
  final String deviceId; // gps_1 atau device_id

  const VehicleDetailPage({
    super.key,
    required this.deviceId,
  });

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late Future<Map<String, dynamic>?> _vehicleFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetail();
  }

  void _loadVehicleDetail() {
    setState(() {
      _vehicleFuture = MongoService.getDetailKendaraan(widget.deviceId);
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    _loadVehicleDetail();
    setState(() {
      _isRefreshing = false;
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return '-';
    }
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final formatter = DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID');
      return formatter.format(dateTime.toLocal());
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Kendaraan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _vehicleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat data kendaraan',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final vehicle = snapshot.data;
          if (vehicle == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Data kendaraan tidak ditemukan',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Device ID: ${widget.deviceId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // Ambil data dari vehicle
          final plat = vehicle['plat'] ?? '-';
          final model = vehicle['model'] ?? '-';
          final deviceId = vehicle['device_id'] ?? vehicle['gps_1'] ?? widget.deviceId;
          final status = vehicle['status'] ?? '-';
          final peminjam = vehicle['peminjam'] ?? null;
          final waktuAmbil = vehicle['waktu_ambil']?.toString();
          final gps1 = vehicle['gps_1'] ?? '-';
          final waktuLepas = vehicle['waktu_lepas']?.toString();

          // Tentukan warna status
          Color statusColor;
          switch (status.toString().toLowerCase()) {
            case 'tersedia':
              statusColor = Colors.green;
              break;
            case 'dipakai':
              statusColor = Colors.orange;
              break;
            case 'maintenance':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.grey;
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.directions_car,
                              size: 48,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  model.toString(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plat.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    status.toString(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Informasi Detail
                  const Text(
                    'Informasi Detail',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildEditableInfoCard(
                    context: context,
                    icon: Icons.confirmation_number,
                    label: 'Plat Nomor',
                    value: plat.toString(),
                    vehicle: vehicle,
                    fieldType: 'plat',
                    onUpdate: () => _loadVehicleDetail(),
                  ),
                  const SizedBox(height: 12),
                  _buildEditableInfoCard(
                    context: context,
                    icon: Icons.directions_car,
                    label: 'Model',
                    value: model.toString(),
                    vehicle: vehicle,
                    fieldType: 'model',
                    onUpdate: () => _loadVehicleDetail(),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.devices,
                    label: 'Device ID',
                    value: deviceId.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.gps_fixed,
                    label: 'GPS ID',
                    value: gps1.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: status.toString(),
                    valueColor: statusColor,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.person,
                    label: 'Peminjam',
                    value: peminjam?.toString() ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.access_time,
                    label: 'Waktu Ambil',
                    value: _formatDateTime(waktuAmbil),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.event_available,
                    label: 'Waktu Lepas',
                    value: _formatDateTime(waktuLepas),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue[900], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableInfoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Map<String, dynamic> vehicle,
    required String fieldType,
    required VoidCallback onUpdate,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue[900], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(
                context,
                label,
                value,
                vehicle,
                fieldType,
                onUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String label,
    String currentValue,
    Map<String, dynamic> vehicle,
    String fieldType,
    VoidCallback onUpdate,
  ) {
    final TextEditingController controller = TextEditingController(text: currentValue == '-' ? '' : currentValue);
    final deviceId = vehicle['device_id'] ?? vehicle['gps_1'] ?? widget.deviceId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit $label'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Masukkan $label',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: fieldType == 'plat' 
                    ? TextCapitalization.characters 
                    : TextCapitalization.words,
                enabled: !isLoading,
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final newValue = controller.text.trim();
                    if (newValue.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label tidak boleh kosong'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() => isLoading = true);

                    try {
                      // Ambil nilai current untuk kedua field
                      final currentPlat = (vehicle['plat'] ?? '').toString();
                      final currentModel = (vehicle['model'] ?? '').toString();
                      
                      // Update sesuai field yang diubah
                      final updatedPlat = fieldType == 'plat' 
                          ? newValue.toUpperCase() 
                          : (currentPlat.isEmpty || currentPlat == '-') ? '' : currentPlat;
                      final updatedModel = fieldType == 'model' 
                          ? newValue 
                          : (currentModel.isEmpty || currentModel == '-') ? '' : currentModel;
                      
                      final success = await MongoService.updateKendaraanDetail(
                        deviceId.toString(),
                        updatedPlat,
                        updatedModel,
                      );

                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data berhasil diperbarui'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                          onUpdate();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal memperbarui data'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

