import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:sikendi/auth_service.dart';

class DriverProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const DriverProfilePage({super.key, required this.user});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  late TextEditingController _namaController;
  late TextEditingController _noHpController;

  bool _isLoading = false;

  // Variabel untuk menyimpan foto profil
  File? _imageFile;
  String? _base64Foto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.user['nama'] ?? '');
    _noHpController = TextEditingController(text: widget.user['no_hp'] ?? '');
    
    // Menarik foto profil lama dari database jika ada
    if (widget.user['foto_profil'] != null && widget.user['foto_profil'].toString().isNotEmpty) {
      _base64Foto = widget.user['foto_profil'];
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil, mengompres, dan mengubah gambar ke Base64
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      final tempDir = Directory.systemTemp;
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Kompresi gambar agar database tidak penuh
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 65, 
      );

      if (compressedXFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal memproses gambar.")),
          );
        }
        return;
      }

      final List<int> compressedBytes = await compressedXFile.readAsBytes();
      final String base64String = base64Encode(compressedBytes);

      setState(() {
        _imageFile = File(compressedXFile.path);
        _base64Foto = base64String;
      });
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // Dialog untuk memilih sumber gambar
  void _showImagePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ubah Foto Profil"),
        content: const Text("Pilih sumber gambar dari:"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
            child: const Text("Kamera"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
            child: const Text("Galeri"),
          ),
        ],
      ),
    );
  }

  Future<void> _simpanProfil() async {
    setState(() {
      _isLoading = true;
    });

    String namaBaru = _namaController.text.trim();
    String noHpBaru = _noHpController.text.trim();

    if (namaBaru.isEmpty || noHpBaru.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Nomor HP tidak boleh kosong!')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Memanggil fungsi update di backend tanpa password
    String result = await AuthService.updateProfilSopir(
      email: widget.user['email'],
      namaBaru: namaBaru,
      noHpBaru: noHpBaru,
      fotoProfilBase64: _base64Foto,
    );

    setState(() {
      _isLoading = false;
    });

    if (result == "Sukses") {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        
        // Memperbarui data lokal untuk dikembalikan ke Dashboard
        Map<String, dynamic> updatedUser = Map<String, dynamic>.from(widget.user);
        updatedUser['nama'] = namaBaru;
        updatedUser['no_hp'] = noHpBaru;
        if (_base64Foto != null) {
          updatedUser['foto_profil'] = _base64Foto;
        }
        
        Navigator.pop(context, updatedUser);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profil"),
        backgroundColor: Colors.blue[900], 
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Foto Profil Interaktif
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _showImagePicker,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          // Prioritaskan file gambar lokal, jika tidak ada pakai Base64 dari database
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (_base64Foto != null && _base64Foto!.isNotEmpty
                                  ? MemoryImage(base64Decode(_base64Foto!))
                                  : null) as ImageProvider?,
                          child: (_imageFile == null && (_base64Foto == null || _base64Foto!.isEmpty))
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[900],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _showImagePicker,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.user['email'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  
                  // Form Nama
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Form No HP
                  TextField(
                    controller: _noHpController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Handphone',
                      prefixIcon: Icon(Icons.phone_android),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _simpanProfil,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Simpan Perubahan",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
