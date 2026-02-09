import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'auth_service.dart';
import 'login_page.dart'; // Import login page for navigation

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers for form fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _namaController = TextEditingController();
  final _hpController = TextEditingController();

  // State variables for images
  File? _imageSelfie;
  File? _imageKtp;
  String? _base64Selfie;
  String? _base64Ktp;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // UI state
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  /// Smart function to handle picking, compressing, and converting an image.
  Future<void> _pickImage(ImageSource source, bool isSelfie) async {
    final XFile? image = await _picker.pickImage(source: source);

    // If the user cancels, do nothing.
    if (image == null) return;
    
    // 1. Define a target path in a temporary directory
    final tempDir = Directory.systemTemp;
    final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 2. Kompresi (Sangat Penting) using the correct method
    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      quality: 65, // Target kualitas 50-70%
    );

    if (compressedXFile == null) {
      // Handle compression error if needed
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memproses gambar.")),
        );
      }
      return;
    }

    // 3. Read the bytes from the compressed file for Base64 conversion
    final List<int> compressedBytes = await compressedXFile.readAsBytes();
    final String base64String = base64Encode(compressedBytes);

    // 4. Update UI (setState)
    setState(() {
      if (isSelfie) {
        _imageSelfie = File(compressedXFile.path);
        _base64Selfie = base64String;
      } else {
        _imageKtp = File(compressedXFile.path);
        _base64Ktp = base64String;
      }
    });
  }
  
  /// Shows a dialog to choose between Camera or Gallery for the ID card photo.
  void _showKtpPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Pilih Sumber Gambar"),
          content: const Text("Ambil foto KTP dari kamera atau galeri?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Kamera"),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera, false); // isSelfie = false
              },
            ),
            TextButton(
              child: const Text("Galeri"),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery, false); // isSelfie = false
              },
            ),
          ],
        );
      },
    );
  }

  /// Handles the entire sign-up process.
  void _handleSignUp() async {
    // 1. Validasi Tambahan
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _namaController.text.isEmpty ||
        _hpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi semua data teks.")),
      );
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password dan konfirmasi tidak cocok.")),
      );
      return;
    }

    if (_base64Selfie == null || _base64Ktp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi foto Selfie dan KTP.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Kirim Data
    String result = await AuthService.signUpSopir(
      email: _emailController.text,
      password: _passwordController.text,
      nama: _namaController.text,
      noHp: _hpController.text,
      fotoSelfieBase64: _base64Selfie!,
      fotoKtpBase64: _base64Ktp!,
    );

    setState(() => _isLoading = false);

    // 3. Feedback Sukses
    if (result == "Sukses") {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text("Registrasi Berhasil"),
              content: const Text(
                  "Data Anda sedang diverifikasi Manajer. Mohon tunggu persetujuan."),
              actions: <Widget>[
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    // Arahkan kembali ke LoginPage
                    Navigator.of(ctx).pop(); // Close the dialog
                    Navigator.of(context).pop(); // Kembali ke halaman Login sebelumnya
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal: $result")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun Sopir")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Form Fields ---
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
             TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: "Konfirmasi Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hpController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Nomor HP", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            // --- Image Pickers ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A. Area Selfie
                Column(
                  children: [
                    const Text("Foto Selfie", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera, true), // Wajib Kamera
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageSelfie != null ? FileImage(_imageSelfie!) : null,
                        child: _imageSelfie == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                                  Text("Ambil Selfie", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                
                // B. Area KTP
                Column(
                  children: [
                    const Text("Foto KTP/SIM", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showKtpPicker(context), // Boleh Kamera/Galeri
                      child: Container(
                        height: 120,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          image: _imageKtp != null
                              ? DecorationImage(image: FileImage(_imageKtp!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _imageKtp == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card, size: 40, color: Colors.grey[600]),
                                  Text("Upload KTP", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- Submit Button ---
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      "DAFTAR",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
