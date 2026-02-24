import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sikendi/models/kegiatan_sopir.dart';
import 'package:sikendi/mongodb_service.dart';

class JadwalSopirPage extends StatefulWidget {
  final String email;

  const JadwalSopirPage({super.key, required this.email});

  @override
  State<JadwalSopirPage> createState() => _JadwalSopirPageState();
}

class _JadwalSopirPageState extends State<JadwalSopirPage> {
  late Future<List<KegiatanSopir>> _kegiatanFuture;

  @override
  void initState() {
    super.initState();
    _loadKegiatan();
  }

  void _loadKegiatan() {
    setState(() {
      _kegiatanFuture = MongoDBService.getKegiatan(widget.email);
    });
  }

  void _showEditKegiatanDialog(KegiatanSopir kegiatan) {
    showDialog(
      context: context,
      builder: (context) {
        return _KegiatanDialog(
          kegiatan: kegiatan,
          onSave: (judul, waktu, status) async {
            await MongoDBService.updateKegiatan(
              id: kegiatan.id,
              judul: judul,
              waktu: waktu,
              status: status,
            );
            _loadKegiatan();
          },
        );
      },
    );
  }

  void _showAddKegiatanDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _KegiatanDialog(
          onSave: (judul, waktu, status) async {
            await MongoDBService.addKegiatan(
              email: widget.email,
              judul: judul,
              waktu: waktu,
            );
            _loadKegiatan();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agenda Perjalanan"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List Jadwal
          Expanded(
            child: FutureBuilder<List<KegiatanSopir>>(
              future: _kegiatanFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada jadwal kegiatan.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final kegiatanList = snapshot.data!;
                // Sort by date (Terbaru di atas)
                kegiatanList.sort((a, b) => b.waktu.compareTo(a.waktu));

                return RefreshIndicator(
                  onRefresh: () async => _loadKegiatan(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: kegiatanList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final kegiatan = kegiatanList[index];
                      return _KegiatanCard(
                        kegiatan: kegiatan,
                        onTap: () => _showEditKegiatanDialog(kegiatan),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddKegiatanDialog,
        backgroundColor: Colors.blue[900],
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text("Tambah Jadwal", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _KegiatanCard extends StatelessWidget {
  final KegiatanSopir kegiatan;
  final VoidCallback onTap;

  const _KegiatanCard({required this.kegiatan, required this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Selesai':
        return Colors.green;
      case 'Dalam Perjalanan':
        return Colors.orange;
      case 'Batal':
        return Colors.red;
      case 'Belum':
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Selesai': return Icons.check_circle;
      case 'Dalam Perjalanan': return Icons.directions_car;
      case 'Batal': return Icons.cancel;
      default: return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(kegiatan.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Agar strip warna mengikuti border radius
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 6), // Strip warna kiri
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal (Box Kotak)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d').format(kegiatan.waktu),
                        style: const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(kegiatan.waktu),
                        style: const TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: Colors.grey
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Konten Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kegiatan.judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(kegiatan.waktu),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(_getStatusIcon(kegiatan.status), size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  kegiatan.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Icon Edit Hint
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog tetap dipertahankan logikanya, hanya dirapikan sedikit jika perlu
class _KegiatanDialog extends StatefulWidget {
  final KegiatanSopir? kegiatan;
  final Function(String judul, DateTime waktu, String status) onSave;

  const _KegiatanDialog({this.kegiatan, required this.onSave});

  @override
  State<_KegiatanDialog> createState() => _KegiatanDialogState();
}

class _KegiatanDialogState extends State<_KegiatanDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _judulController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedStatus;
  bool _isLoading = false;

  final List<String> _statusOptions = [
    'Belum',
    'Dalam Perjalanan',
    'Selesai',
    'Batal',
  ];

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(
      text: widget.kegiatan?.judul ?? '',
    );
    _selectedDate = widget.kegiatan?.waktu ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(
      widget.kegiatan?.waktu ?? DateTime.now(),
    );
    _selectedStatus = widget.kegiatan?.status ?? 'Belum';
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    // Menggunakan Standard Time Picker agar UX lebih familiar
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      widget
          .onSave(_judulController.text, combinedDateTime, _selectedStatus)
          .then((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.kegiatan == null ? 'Tambah Kegiatan' : 'Edit Kegiatan',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: const InputDecoration(
                  labelText: 'Judul Kegiatan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              
              // Input Tanggal & Waktu (Row)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(_selectedTime.format(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              if (widget.kegiatan != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}