import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';

// ==========================================================
// TAB 4: MANAJEMEN KENDARAAN (REFACTORED with MongoService)
// ==========================================================
class ManagerVehicleManagementTab extends StatefulWidget {
  const ManagerVehicleManagementTab({super.key});

  @override
  State<ManagerVehicleManagementTab> createState() => _ManagerVehicleManagementTabState();
}

class _ManagerVehicleManagementTabState extends State<ManagerVehicleManagementTab> {
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    setState(() {
      _vehiclesFuture = MongoService.getSemuaDataUntukManager();
    });
  }

  void _showAddVehicleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddVehicleDialog(
          onVehicleAdded: () {
            _loadVehicles();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada kendaraan terdaftar."));
          }

          final vehicles = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadVehicles(),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final status = vehicle['status'] ?? 'N/A';
                final peminjam = vehicle['peminjam'] ?? 'Tidak Dipakai';

                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.directions_car,
                      color: status == 'Tersedia' ? Colors.green : Colors.orange,
                    ),
                    title: Text(vehicle['model'] ?? 'Model Tidak Dikenal', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${vehicle['plat'] ?? 'Plat Tidak Dikenal'} - Status: $status"),
                    trailing: Text(peminjam),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context),
        tooltip: 'Tambah Kendaraan',
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue[900],
      ),
    );
  }
}

// Dialog for Adding a New Vehicle (REFACTORED for MongoService)
class AddVehicleDialog extends StatefulWidget {
  final VoidCallback onVehicleAdded;

  const AddVehicleDialog({
    super.key,
    required this.onVehicleAdded,
  });

  @override
  State<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _platController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        final success = await MongoService.tambahKendaraanManager(
          _platController.text.toUpperCase(),
          _modelController.text,
          _deviceIdController.text,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Kendaraan berhasil ditambahkan."), backgroundColor: Colors.green),
            );
            widget.onVehicleAdded();
            Navigator.of(context).pop();
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gagal: Device ID mungkin sudah terdaftar."), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if(mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Tambah Kendaraan Baru"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(labelText: "Device ID GPS"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Device ID tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
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
          child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}