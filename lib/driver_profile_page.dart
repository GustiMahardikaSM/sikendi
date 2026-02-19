import 'package:flutter/material.dart';
import 'package:sikendi/auth_service.dart';

class DriverProfilePage extends StatefulWidget {
  // Menerima data sopir yang sedang login dari halaman sebelumnya
  final Map<String, dynamic> user;

  const DriverProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _DriverProfilePageState createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  late TextEditingController _namaController;
  late TextEditingController _noHpController;
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mengisi form secara otomatis dengan data saat ini
    _namaController = TextEditingController(text: widget.user['nama'] ?? '');
    _noHpController = TextEditingController(text: widget.user['no_hp'] ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _simpanProfil() async {
    setState(() {
      _isLoading = true;
    });

    String namaBaru = _namaController.text.trim();
    String noHpBaru = _noHpController.text.trim();
    String passwordBaru = _passwordController.text.trim();

    // Validasi input dasar
    if (namaBaru.isEmpty || noHpBaru.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Nomor HP tidak boleh kosong!')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Memanggil fungsi update di backend (auth_service.dart)
    String result = await AuthService.updateProfilSopir(
      email: widget.user['email'],
      namaBaru: namaBaru,
      noHpBaru: noHpBaru,
      passwordBaru: passwordBaru.isNotEmpty ? passwordBaru : null,
      // Catatan: Untuk fitur upload foto kamera/galeri, Anda bisa menambahkan
      // package image_picker nanti dan mengirim string base64-nya ke sini.
    );

    setState(() {
      _isLoading = false;
    });

    if (result == "Sukses") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui!')),
      );
      
      // Mengemas data terbaru untuk dikirim kembali ke dashboard
      Map<String, dynamic> updatedUser = Map<String, dynamic>.from(widget.user);
      updatedUser['nama'] = namaBaru;
      updatedUser['no_hp'] = noHpBaru;
      
      // Kembali ke halaman sebelumnya dengan membawa data baru
      Navigator.pop(context, updatedUser);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profil"),
        backgroundColor: Colors.blue, // Sesuaikan dengan warna tema SiKenDi
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Placeholder untuk Foto Profil
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fitur ubah foto akan segera hadir')),
                            );
                          },
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
                  const SizedBox(height: 16),
                  
                  // Form Password Baru
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Baru (Opsional)',
                      hintText: 'Kosongkan jika tidak ingin diubah',
                      prefixIcon: Icon(Icons.lock_outline),
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
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Simpan Perubahan",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}