import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/vehicle_detail_page.dart';

// ==========================================================
// TAB 4: MANAJEMEN KENDARAAN (REFACTORED - Dua Bagian)
// ==========================================================
class ManagerVehiclePage extends StatefulWidget {
  const ManagerVehiclePage({super.key});

  @override
  State<ManagerVehiclePage> createState() => _ManagerVehiclePageState();
}

class _ManagerVehiclePageState extends State<ManagerVehiclePage> {
  late Future<Map<String, List<Map<String, dynamic>>>> _vehiclesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = MongoService.getSemuaDataUntukManagerDipisah();
    });
  }

  // Fungsi untuk memfilter kendaraan berdasarkan query pencarian
  List<Map<String, dynamic>> _filterVehicles(List<Map<String, dynamic>> vehicles, bool isDefined) {
    if (_searchQuery.isEmpty) {
      return vehicles;
    }

    return vehicles.where((vehicle) {
      if (isDefined) {
        // Untuk kendaraan yang sudah didefinisikan, cari berdasarkan model dan plat
        final model = (vehicle['model'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        final plat = (vehicle['plat'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        final searchQueryNoSpace = _searchQuery.replaceAll(' ', '');
        return model.contains(searchQueryNoSpace) || plat.contains(searchQueryNoSpace);
      } else {
        // Untuk kendaraan yang belum didefinisikan, cari berdasarkan device_id/gps_1
        final deviceId = (vehicle['gps_1'] ?? vehicle['device_id'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        final searchQueryNoSpace = _searchQuery.replaceAll(' ', '');
        return deviceId.contains(searchQueryNoSpace);
      }
    }).toList();
  }

  void _showDefineVehicleDialog(BuildContext context, Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return DefineVehicleDialog(
          gps1: vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown",
          onVehicleDefined: () {
            _loadVehicles();
          },
        );
      },
    );
  }

  void _showVehicleCrudDialog(BuildContext context, Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return VehicleCrudDialog(
          vehicle: vehicle,
          onVehicleUpdated: () {
            _loadVehicles();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Kendaraan'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Belum ada data."));
          }

          final allUndefinedVehicles = snapshot.data!['undefined'] ?? [];
          final allDefinedVehicles = snapshot.data!['defined'] ?? [];
          
          // Filter kendaraan berdasarkan query pencarian
          final undefinedVehicles = _filterVehicles(allUndefinedVehicles, false);
          final definedVehicles = _filterVehicles(allDefinedVehicles, true);

          return RefreshIndicator(
            onRefresh: () async => _loadVehicles(),
            child: CustomScrollView(
              slivers: [
                // Search Bar di bagian atas
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari berdasarkan nama/model atau plat nomor...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                
                // Bagian Atas: Kendaraan yang belum didefinisikan
                if (undefinedVehicles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Kendaraan Belum Didefinisikan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                if (undefinedVehicles.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final vehicle = undefinedVehicles[index];
                        final gps1 = vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown";
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.directions_car,
                              color: Colors.orange,
                            ),
                            title: Text(
                              'Model Tidak Dikenal',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("$gps1 - Plat Tidak Dikenal - Status: N/A"),
                            trailing: Text('Tidak Dipakai', style: TextStyle(color: Colors.grey[600])),
                            onTap: () => _showDefineVehicleDialog(context, vehicle),
                          ),
                        );
                      },
                      childCount: undefinedVehicles.length,
                    ),
                  ),
                
                // Divider antara dua bagian
                if (undefinedVehicles.isNotEmpty && definedVehicles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Divider(height: 32, thickness: 1, color: Colors.grey[300]),
                  ),
                
                // Bagian Bawah: Kendaraan yang sudah dimasukkan
                if (definedVehicles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Kendaraan Terdaftar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                if (definedVehicles.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final vehicle = definedVehicles[index];
                        final status = vehicle['status'] ?? 'N/A';
                        final peminjam = vehicle['peminjam'] ?? 'Tidak Dipakai';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.directions_car,
                              color: status == 'Tersedia' ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              vehicle['model'] ?? 'Model Tidak Dikenal',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("${vehicle['plat'] ?? 'Plat Tidak Dikenal'} - Status: $status"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(peminjam, style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                            onTap: () {
                              final deviceId = vehicle['gps_1'] ?? vehicle['device_id'] ?? "Unknown";
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VehicleDetailPage(deviceId: deviceId),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: definedVehicles.length,
                    ),
                  ),
                
                // Pesan jika tidak ada data
                if (undefinedVehicles.isEmpty && definedVehicles.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.directions_car_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "Tidak ada kendaraan yang cocok dengan pencarian \"$_searchQuery\""
                                : "Belum ada kendaraan terdaftar.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Dialog untuk mendefinisikan kendaraan yang belum didefinisikan
class DefineVehicleDialog extends StatefulWidget {
  final String gps1;
  final VoidCallback onVehicleDefined;

  const DefineVehicleDialog({
    super.key,
    required this.gps1,
    required this.onVehicleDefined,
  });

  @override
  State<DefineVehicleDialog> createState() => _DefineVehicleDialogState();
}

class _DefineVehicleDialogState extends State<DefineVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _platController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _platController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final success = await MongoService.tambahKendaraanManager(
          _platController.text.toUpperCase(),
          _modelController.text,
          widget.gps1,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Kendaraan berhasil didefinisikan."),
                backgroundColor: Colors.green,
              ),
            );
            widget.onVehicleDefined();
            Navigator.of(context).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gagal: Device ID mungkin sudah terdaftar."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Definisikan Kendaraan"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Device ID: ${widget.gps1}",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _platController,
                decoration: const InputDecoration(labelText: 'Plat Nomor (e.g., H 1234 XY)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Plat nomor tidak boleh kosong';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model (e.g., Toyota Avanza)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Model tidak boleh kosong';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// Dialog CRUD untuk kendaraan yang sudah terdaftar
class VehicleCrudDialog extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onVehicleUpdated;

  const VehicleCrudDialog({
    super.key,
    required this.vehicle,
    required this.onVehicleUpdated,
  });

  @override
  State<VehicleCrudDialog> createState() => _VehicleCrudDialogState();
}

class _VehicleCrudDialogState extends State<VehicleCrudDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _platController;
  late TextEditingController _modelController;
  late String _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _platController = TextEditingController(text: widget.vehicle['plat'] ?? '');
    _modelController = TextEditingController(text: widget.vehicle['model'] ?? '');
    _selectedStatus = widget.vehicle['status'] ?? 'Tersedia';
  }

  @override
  void dispose() {
    _platController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _updateVehicle() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final gps1 = widget.vehicle['gps_1'] ?? widget.vehicle['device_id'] ?? "Unknown";
        final success = await MongoService.updateKendaraanManager(
          gps1,
          _platController.text.toUpperCase(),
          _modelController.text,
          _selectedStatus,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Kendaraan berhasil diperbarui."),
                backgroundColor: Colors.green,
              ),
            );
            widget.onVehicleUpdated();
            Navigator.of(context).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gagal memperbarui kendaraan."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteVehicle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Metadata Kendaraan"),
        content: const Text(
          "Apakah Anda yakin ingin menghapus metadata kendaraan ini? "
          "Data GPS location akan tetap tersimpan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        final gps1 = widget.vehicle['gps_1'] ?? widget.vehicle['device_id'] ?? "Unknown";
        final success = await MongoService.hapusMetadataKendaraan(gps1);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Metadata kendaraan berhasil dihapus."),
                backgroundColor: Colors.green,
              ),
            );
            widget.onVehicleUpdated();
            Navigator.of(context).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gagal menghapus metadata kendaraan."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gps1 = widget.vehicle['gps_1'] ?? widget.vehicle['device_id'] ?? "Unknown";
    
    return AlertDialog(
      title: const Text("Kelola Kendaraan"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Device ID: $gps1",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _platController,
                decoration: const InputDecoration(labelText: 'Plat Nomor'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Plat nomor tidak boleh kosong';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Model tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Tersedia', child: Text('Tersedia')),
                  DropdownMenuItem(value: 'Dipakai', child: Text('Dipakai')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : _deleteVehicle,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Hapus'),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateVehicle,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
