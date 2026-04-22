import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sikendi/mongodb_service.dart';

class ManagerProfilePage extends StatefulWidget {
  const ManagerProfilePage({super.key});

  @override
  State<ManagerProfilePage> createState() => _ManagerProfilePageState();
}

class _ManagerProfilePageState extends State<ManagerProfilePage> {
  Map<String, dynamic>? _managerData;
  bool _isLoading = true;
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();
  File? _imageFile;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await MongoDBService.getManagerMe();
    if (mounted && data != null) {
      setState(() {
        _managerData = data;
        _phoneController.text = data['no_hp'] ?? '';
        _base64Image = data['foto_selfie'];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Compress for faster upload
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = File(pickedFile.path);
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final success = await MongoDBService.updateManagerMe(
      noHp: _phoneController.text,
      base64Selfie: _base64Image,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil diperbarui"), backgroundColor: Colors.green),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memperbarui profil"), backgroundColor: Colors.red),
        );
      }
    }
  }

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      try {
        String cleanBase64 = _base64Image!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        return MemoryImage(base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), '')));
      } catch (e) {
        debugPrint("Error decoding image: $e");
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final image = _getProfileImage();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: image,
                  child: image == null ? const Icon(Icons.person, size: 70, color: Colors.grey) : null,
                ),
                PositionBagged(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.blue[900],
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildReadOnlyField(Icons.email, "Email", _managerData?['email_manager']),
            const SizedBox(height: 16),
            _buildReadOnlyField(Icons.person, "Nama", _managerData?['nama_manager']),
            const SizedBox(height: 16),
            _buildReadOnlyField(Icons.layers, "Level", _managerData?['level']?.toUpperCase()),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: "Nomor Telepon",
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Simpan Perubahan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(IconData icon, String label, String? value) {
    return TextField(
      controller: TextEditingController(text: value ?? '-'),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }
}

class PositionBagged extends StatelessWidget {
  final Widget child;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  const PositionBagged({super.key, required this.child, this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}
