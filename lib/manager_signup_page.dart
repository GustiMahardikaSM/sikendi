import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/constants/hierarchy.dart';

class ManagerSignUpPage extends StatefulWidget {
  const ManagerSignUpPage({super.key});

  @override
  State<ManagerSignUpPage> createState() => _ManagerSignUpPageState();
}

class _ManagerSignUpPageState extends State<ManagerSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _noHpController = TextEditingController();


  String _selectedLevel = 'fakultas';

  String? _selectedFakultas;
  String? _selectedDepartemen;

  File? _selfieImage;
  File? _ktpImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;


  final Color primaryColor = const Color(0xFF003366);
  final Color accentColor = const Color(0xFFFFD700);

  Future<void> _pickImage(ImageSource source, bool isSelfie) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        if (isSelfie) {
          _selfieImage = File(pickedFile.path);
        } else {
          _ktpImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<String?> _compressAndGetBase64(File? file) async {
    if (file == null) return null;
    
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 25, // Lower quality for better upload success
      minWidth: 600,
      minHeight: 600,
    );

    if (result == null) return null;
    final bytes = await result.readAsBytes();
    
    // Clean up temporary file
    try { File(outPath).delete(); } catch (_) {}
    
    return base64Encode(bytes);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selfieImage == null || _ktpImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto selfie dan KTP wajib diunggah')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("⏳ Memulai kompresi gambar...");
      final base64Selfie = await _compressAndGetBase64(_selfieImage);
      final base64Ktp = await _compressAndGetBase64(_ktpImage);
      
      debugPrint("🚀 Mengirim data pendaftaran ke server...");
      
      final result = await MongoDBService.registerManager(
        email: _emailController.text,
        password: _passwordController.text,
        nama: _namaController.text,
        no_hp: _noHpController.text,
        level: _selectedLevel,
        fakultas: _selectedFakultas,
        departemen: _selectedDepartemen,
        base64Selfie: base64Selfie,
        base64Ktp: base64Ktp,
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        return {'success': false, 'message': 'Koneksi lambat (Timeout). Pastikan sinyal stabil.'};
      });


    if (mounted) {
      setState(() => _isLoading = false);
      
      if (result['success']) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pendaftaran Berhasil'),
            content: Text(result['message']),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  } catch (e) {
      debugPrint("Error saat pendaftaran: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mendaftar: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }



  void _showImageSourceDialog(bool isSelfie) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Gambar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isSelfie);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isSelfie);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Manajer Baru'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('Data Akun'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _namaController,
                      decoration: _buildInputDecoration('Nama Lengkap', Icons.person),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('Email', Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: _buildInputDecoration('Kata Sandi', Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: _buildInputDecoration('Konfirmasi Kata Sandi', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                        ),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Wajib diisi';
                        if (v != _passwordController.text) return 'Kata sandi tidak cocok';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noHpController,
                      decoration: _buildInputDecoration('Nomor HP', Icons.phone),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),

                    
                    const SizedBox(height: 32),
                    _buildSectionTitle('Tingkatan Manajer'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedLevel,
                      decoration: _buildInputDecoration('Pilih Tingkatan', Icons.layers),
                      items: const [
                        DropdownMenuItem(value: 'fakultas', child: Text('Fakultas')),
                        DropdownMenuItem(value: 'departemen', child: Text('Departemen')),
                      ],


                      onChanged: (v) {
                        setState(() {
                          _selectedLevel = v!;
                          _selectedFakultas = null;
                          _selectedDepartemen = null;
                        });
                      },
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedFakultas,
                      decoration: _buildInputDecoration('Pilih Fakultas', Icons.account_balance),
                      items: HierarchyData.listFakultas.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),

                      onChanged: (v) {
                        setState(() {
                          _selectedFakultas = v;
                          _selectedDepartemen = null;
                        });
                      },
                      validator: (v) => v == null ? 'Wajib pilih fakultas' : null,
                    ),


                    if (_selectedLevel == 'departemen' && _selectedFakultas != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedDepartemen,
                        decoration: _buildInputDecoration('Pilih Departemen', Icons.business),
                        items: HierarchyData.getDepartemen(_selectedFakultas!).map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),

                        onChanged: (v) => setState(() => _selectedDepartemen = v),
                        validator: (v) => v == null ? 'Wajib pilih departemen' : null,
                      ),
                    ],

                    const SizedBox(height: 32),
                    _buildSectionTitle('Verifikasi Identitas'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildImagePicker('Foto Selfie', _selfieImage, () => _pickImage(ImageSource.camera, true))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildImagePicker('Foto KTP / Kartu Identitas', _ktpImage, () => _showImageSourceDialog(false))),
                      ],
                    ),


                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Daftar Sebagai Manajer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
    );
  }

  Widget _buildImagePicker(String label, File? image, VoidCallback onTap) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: image != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(image, fit: BoxFit.cover))
                : const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
