import 'package:flutter/material.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/driver_tracking_page.dart';
import 'package:sikendi/driver_tugas_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sikendi/driver_page.dart';
import 'package:sikendi/main.dart';
import 'package:sikendi/auth_service.dart';
import 'dart:async';

class DriverIncomingTaskPage extends StatefulWidget {
  final Map<String, dynamic> tugas;
  final Map<String, dynamic> user;
  final VoidCallback onDecision;

  const DriverIncomingTaskPage({super.key, required this.tugas, required this.onDecision, required this.user});

  @override
  State<DriverIncomingTaskPage> createState() => _DriverIncomingTaskPageState();
}

class _DriverIncomingTaskPageState extends State<DriverIncomingTaskPage> {
  bool _isProcessing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _playCount = 0;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  void _playRingtone() async {
    await _audioPlayer.play(AssetSource('sounds/universfield-ringtone-055-494939.mp3'));
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _playCount++;
      if (_playCount < 10 && mounted) {
        _audioPlayer.play(AssetSource('sounds/universfield-ringtone-055-494939.mp3'));
      }
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _accept() async {
    _audioPlayer.stop();
    setState(() => _isProcessing = true);
    final deviceId = widget.tugas['deviceId']?.toString() ?? widget.tugas['device_id']?.toString() ?? widget.tugas['gps_1']?.toString() ?? '';
    final success = await MongoDBService.acceptTugas(deviceId);
    
    if (mounted) {
      widget.onDecision();
      
      if (success) {
        // Tampilkan pop up tugas sedang dilaksanakan
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text("Berhasil"),
              ],
            ),
            content: const Text("Tugas sedang dilaksanakan."),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx); // Tutup Dialog
                  
                  // Ambil data user dari storage untuk navigasi balik yang aman
                  final currentUser = await AuthService.getCurrentUser();
                  if (mounted) {
                    if (currentUser != null) {
                      Navigator.pushAndRemoveUntil(
                        context, 
                        MaterialPageRoute(builder: (_) => DriverPage(user: currentUser)),
                        (route) => false
                      );
                    } else {
                      // Fallback ke RoleSelectionPage jika session hilang
                      Navigator.pushAndRemoveUntil(
                        context, 
                        MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                        (route) => false
                      );
                    }
                  }
                },
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menerima tugas"), backgroundColor: Colors.red));
        setState(() => _isProcessing = false);
      }
    }
  }

  void _reject() {
    _audioPlayer.stop();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Tolak Penugasan"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Masukkan alasan penolakan..."),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan wajib diisi!")));
                return;
              }
              Navigator.pop(ctx);
              _processReject(reasonController.text);
            },
            child: const Text("Kirim Penolakan", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _processReject(String alasan) async {
    setState(() => _isProcessing = true);
    final deviceId = widget.tugas['deviceId']?.toString() ?? widget.tugas['device_id']?.toString() ?? widget.tugas['gps_1']?.toString() ?? '';
    final success = await MongoDBService.rejectTugas(deviceId, alasan);
    if (mounted) {
      widget.onDecision();
      if (success) {
        final currentUser = await AuthService.getCurrentUser();
        if (mounted) {
          if (currentUser != null) {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => DriverPage(user: currentUser)),
              (route) => false
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
              (route) => false
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menolak tugas"), backgroundColor: Colors.red));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan menyerupai telepon masuk
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text("PENUGASAN BARU!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text("Kendaraan:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("${widget.tugas['model']} (${widget.tugas['plat']})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    const Text("Deskripsi Tugas:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(widget.tugas['tugas'] ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              if (_isProcessing)
                const CircularProgressIndicator(color: Colors.white)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tombol Tolak
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _reject,
                          child: const CircleAvatar(radius: 30, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 30)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Tolak", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // Tombol Detail
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _audioPlayer.stop();
                            widget.onDecision();
                            Navigator.pop(context); // Tutup pop up
                            Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTugasPage(user: widget.user)));
                          },
                          child: const CircleAvatar(radius: 30, backgroundColor: Colors.orange, child: Icon(Icons.info_outline, color: Colors.white, size: 30)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Detail", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // Tombol Terima
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _accept,
                          child: const CircleAvatar(radius: 30, backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 30)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Terima", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
