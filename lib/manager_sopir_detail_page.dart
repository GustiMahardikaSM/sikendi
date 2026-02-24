import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'mongodb_service.dart'; // Buka komentar ini nanti untuk fungsi status

class ManagerSopirDetailPage extends StatefulWidget {
  final Map<String, dynamic> dataSopir;

  const ManagerSopirDetailPage({Key? key, required this.dataSopir}) : super(key: key);

  @override
  _ManagerSopirDetailPageState createState() => _ManagerSopirDetailPageState();
}

class _ManagerSopirDetailPageState extends State<ManagerSopirDetailPage> {
  bool isLoading = true;
  Map<String, dynamic>? statusPekerjaan;

  @override
  void initState() {
    super.initState();
    _fetchStatusSopir();
  }

  Future<void> _fetchStatusSopir() async {
    // TODO: Langkah 3 (Status Pekerjaan) akan diimplementasikan di sini nanti.
    // Sementara kita buat loading pura-pura agar UI bisa dites dulu.
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fungsi khusus untuk menangani error Base64 Foto
  ImageProvider _getProfileImage() {
    // GANTI 'foto' dengan key yang benar di MongoDB Anda (misal: 'profile_pic', 'image', dll)
    String? base64String = widget.dataSopir['foto']; 

    if (base64String != null && base64String.isNotEmpty) {
      try {
        // Jika ada prefix "data:image/png;base64,", kita harus memotongnya
        if (base64String.contains(',')) {
          base64String = base64String.split(',').last;
        }
        // Hapus spasi atau newline yang mungkin terbawa
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');
        
        Uint8List imageBytes = base64Decode(base64String);
        return MemoryImage(imageBytes);
      } catch (e) {
        debugPrint("Gagal decode gambar: $e");
      }
    }
    // Mengembalikan gambar transparan/kosong jika gagal, nanti ditangani di UI
    return const AssetImage(''); 
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan key ini ('nama', 'email', 'phone') SAMA PERSIS dengan di MongoDB
    final nama = widget.dataSopir['nama'] ?? widget.dataSopir['username'] ?? 'Nama tidak tersedia';
    final email = widget.dataSopir['email'] ?? 'Email tidak tersedia';
    final telepon = widget.dataSopir['phone'] ?? widget.dataSopir['telepon'] ?? widget.dataSopir['no_hp'] ?? '-';
    
    // Cek apakah gambar berhasil diload
    bool hasValidImage = false;
    ImageProvider imageProvider = _getProfileImage();
    if (imageProvider is MemoryImage) {
      hasValidImage = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sopir'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- BAGIAN FOTO PROFIL ---
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: hasValidImage ? imageProvider : null,
                child: !hasValidImage 
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // --- BAGIAN DATA DIRI ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blueAccent),
                      title: const Text('Nama Lengkap'),
                      subtitle: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blueAccent),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.blueAccent),
                      title: const Text('Nomor Telepon'),
                      subtitle: Text(telepon),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- BAGIAN STATUS PEKERJAAN ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.green),
                        title: const Text('Status Operasional'),
                        // Ini akan diubah saat Langkah 3 selesai
                        subtitle: const Text('Saat ini sedang standby (Data dinamis menyusul)'), 
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}