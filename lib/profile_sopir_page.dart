import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sikendi/mongodb_service.dart';

class ProfileSopirPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileSopirPage({super.key, required this.user});

  @override
  State<ProfileSopirPage> createState() => _ProfileSopirPageState();
}

class _ProfileSopirPageState extends State<ProfileSopirPage> {
  // Variabel untuk menyimpan foto yang dipilih nanti di Langkah 4
  File? _imageFile;
  
  // Variabel untuk status kendaraan (nanti diisi dari database di Langkah 3)
  Map<String, dynamic>? _kendaraanSaatIni;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // 1. Fungsi untuk menampilkan menu bawah (Bottom Sheet) pilihan Kamera/Galeri
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.blue),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Fungsi untuk mengambil foto, mengompres, dan menyimpan ke Database
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Ambil gambar
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Batas ukuran awal
        maxHeight: 800,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sedang memproses dan menyimpan foto...")),
        );

        // Kompresi gambar agar database MongoDB tidak berat
        var compressedFile = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 400,
          minHeight: 400,
          quality: 60, // Kualitas gambar diturunkan sedikit (60%)
        );

        if (compressedFile != null) {
          // Ubah gambar yang sudah dikompres menjadi String Base64
          String base64Image = base64Encode(compressedFile);
          String email = widget.user['email'];

          // Simpan ke MongoDB menggunakan fungsi dari Langkah 3
          bool success = await MongoDBService.updateFotoProfilSopir(email, base64Image);

          if (success) {
            setState(() {
              _imageFile = file; // Perbarui tampilan UI
              widget.user['foto_profil'] = base64Image; // Perbarui data lokal user
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Foto profil berhasil diperbarui!"), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gagal menyimpan foto ke database."), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      print("Error saat memproses foto: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan saat memproses foto."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData(); // Memanggil fungsi ambil data saat halaman pertama kali dibuka
  }

  // Fungsi untuk mengambil status kendaraan dari database
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mengambil nama sopir dari data user yang login
      String namaSopir = widget.user['nama'] ?? widget.user['nama_lengkap'] ?? '';
      
      // Memanggil fungsi yang sudah ada sebelumnya di MongoDBService
      // untuk mengecek pekerjaan/kendaraan yang sedang dipegang sopir
      var pekerjaan = await MongoDBService.getPekerjaanSaya(namaSopir);
      
      setState(() {
        if (pekerjaan.isNotEmpty) {
          // Asumsi struktur data kembalian memiliki field 'plat_nomor'
          _kendaraanSaatIni = pekerjaan.first; 
        } else {
          _kendaraanSaatIni = null; // Tidak sedang membawa mobil
        }
      });
    } catch (e) {
      print("Gagal mengambil data kendaraan: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil data user yang dikirim dari dashboard
    final userData = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ==========================================
                // BAGIAN 1: FOTO PROFIL & TOMBOL EDIT
                // ==========================================
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      // Logika Tampilan Foto: 
                      // 1. Cek file lokal (_imageFile) jika baru ganti foto
                      // 2. Jika tidak ada, cek apakah ada base64 di database
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) as ImageProvider
                          : (userData['foto_profil'] != null && userData['foto_profil'].toString().isNotEmpty)
                              ? MemoryImage(base64Decode(userData['foto_profil']))
                              : null,
                      // Jika tidak ada foto sama sekali, tampilkan ikon default
                      child: (_imageFile == null && (userData['foto_profil'] == null || userData['foto_profil'].toString().isEmpty))
                          ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          // Panggil fungsi dialog yang baru kita buat
                          onPressed: _showImageSourceDialog, 
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ==========================================
                // BAGIAN 2: DATA DIRI
                // ==========================================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Informasi Pribadi",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.badge, color: Colors.blue),
                          title: const Text("Nama Lengkap"),
                          subtitle: Text(userData['nama'] ?? userData['nama_lengkap'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.orange),
                          title: const Text("Email"),
                          subtitle: Text(userData['email'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Colors.green),
                          title: const Text("No. Handphone"),
                          subtitle: Text(userData['no_hp'] ?? '-'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ==========================================
                // BAGIAN 3: STATUS KENDARAAN SAAT INI
                // ==========================================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Status Operasional",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(
                            _kendaraanSaatIni != null ? Icons.directions_car : Icons.car_crash, 
                            color: _kendaraanSaatIni != null ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          title: Text(
                            _kendaraanSaatIni != null ? "Sedang Bertugas" : "Standby (Tidak bawa mobil)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _kendaraanSaatIni != null ? Colors.green : Colors.red,
                            ),
                          ),
                          subtitle: Text(
                            _kendaraanSaatIni != null 
                                ? "Plat: ${_kendaraanSaatIni!['plat']}" 
                                : "Silakan check-in kendaraan di Dasbor",
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
