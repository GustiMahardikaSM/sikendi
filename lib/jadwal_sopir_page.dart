import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
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
      _kegiatanFuture = MongoService.getKegiatan(widget.email);
    });
  }

  void _showEditKegiatanDialog(KegiatanSopir kegiatan) {
    showDialog(
      context: context,
      builder: (context) {
        return _KegiatanDialog(
          kegiatan: kegiatan,
          onSave: (judul, waktu, status) async {
            await MongoService.updateKegiatan(
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
            await MongoService.addKegiatan(
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
        title: const Text('Jadwal Kegiatan'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<KegiatanSopir>>(
        future: _kegiatanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada jadwal kegiatan.'));
          }

          final kegiatanList = snapshot.data!;
          // Sort by date
          kegiatanList.sort((a, b) => b.waktu.compareTo(a.waktu));


          return RefreshIndicator(
            onRefresh: () async => _loadKegiatan(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: kegiatanList.length,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddKegiatanDialog,
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add),
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          kegiatan.judul,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(DateFormat('d MMMM yyyy, HH:mm').format(kegiatan.waktu)),
            const SizedBox(height: 8),
            Chip(
              label: Text(kegiatan.status),
              backgroundColor: _getStatusColor(kegiatan.status),
              labelStyle: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

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

  final List<String> _statusOptions = ['Belum', 'Dalam Perjalanan', 'Selesai', 'Batal'];

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.kegiatan?.judul ?? '');
    _selectedDate = widget.kegiatan?.waktu ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(widget.kegiatan?.waktu ?? DateTime.now());
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
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
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

      widget.onSave(
        _judulController.text,
        combinedDateTime,
        _selectedStatus,
      ).then((_) {
        if(mounted){
          Navigator.of(context).pop();
        }
      }).catchError((_){
         if(mounted){
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
      title: Text(widget.kegiatan == null ? 'Tambah Kegiatan' : 'Edit Kegiatan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: const InputDecoration(labelText: 'Judul Kegiatan'),
                validator: (value) =>
                    value!.isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tanggal: ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Pilih'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Waktu: ${_selectedTime.format(context)}'),
                  ),
                  TextButton(
                    onPressed: _pickTime,
                    child: const Text('Pilih'),
                  ),
                ],
              ),
              if (widget.kegiatan != null) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
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
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Simpan'),
        ),
      ],
    );
  }
}
