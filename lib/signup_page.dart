import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _namaController = TextEditingController();
  final _hpController = TextEditingController();

  File? _imageSelfie;
  File? _imageKtp;
  String? _base64Selfie;
  String? _base64Ktp;

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Tema Warna (Disesuaikan dengan LoginPage)
  final Color primaryColor = const Color(0xFF003366);
  final Color accentColor = const Color(0xFFFFD700);

  // Variabel Animasi
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _namaController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isSelfie) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    
    final tempDir = Directory.systemTemp;
    final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      quality: 65,
    );

    if (compressedXFile == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memproses gambar.")),
        );
      }
      return;
    }

    final List<int> compressedBytes = await compressedXFile.readAsBytes();
    final String base64String = base64Encode(compressedBytes);

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
  
  void _showKtpPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Pilih Sumber Gambar"),
          content: const Text("Ambil foto KTP dari kamera atau galeri?"),
          actions: <Widget>[
            TextButton(
              child: Text("Kamera", style: TextStyle(color: primaryColor)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera, false);
              },
            ),
            TextButton(
              child: Text("Galeri", style: TextStyle(color: primaryColor)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery, false);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _namaController.text.isEmpty ||
        _hpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Mohon lengkapi semua data teks."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Password dan konfirmasi tidak cocok."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_base64Selfie == null || _base64Ktp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Mohon lengkapi foto Selfie dan KTP."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? errorMessage = await AuthService.daftarAkunSopir(
      email: _emailController.text,
      password: _passwordController.text,
      nama: _namaController.text,
      noHp: _hpController.text,
      fotoSelfieTemp: _base64Selfie!,
      fotoKtpTemp: _base64Ktp!,
    );

    setState(() => _isLoading = false);

    if (errorMessage == null) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(Icons.check_circle_outline, color: primaryColor, size: 48),
              title: const Text("Registrasi Berhasil"),
              content: const Text(
                "Data Anda sedang diverifikasi Manajer. Mohon tunggu persetujuan.",
                textAlign: TextAlign.center,
              ),
              actions: <Widget>[
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Kembali ke Login"),
                    onPressed: () {
                      Navigator.of(ctx).pop(); 
                      Navigator.of(context).pop(); 
                    },
                  ),
                ),
              ],
            );
          },
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        );
      }
    }
  }

  // Desain Input yang lebih ringkas (isDense: true) agar muat di 1 layar
  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      isDense: true, // Membuat tinggi kolom lebih kecil
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      labelStyle: const TextStyle(fontSize: 14),
      hintStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // PENTING: Mencegah error overflow saat keyboard HP naik karena tidak ada scroll
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Gradient (Sama seperti LoginPage)
          Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  const Color(0xFF001F3F), 
                ],
              ),
            ),
          ),
          
          // Ornamen Lingkaran
          Positioned(top: -50, right: -50, child: _buildCircleOrnament(250, 0.03)),
          Positioned(bottom: -100, left: -100, child: _buildCircleOrnament(300, 0.02)),

          SafeArea(
            child: Padding(
              // Padding fleksibel, tidak menggunakan SingleChildScrollView
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // --- Header (Ikon & Judul) ---
                              Icon(Icons.person_add_alt_1_rounded, size: 36, color: primaryColor),
                              const SizedBox(height: 8),
                              Text(
                                'Daftar Akun',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lengkapi identitas untuk pendaftaran',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              
                              const Spacer(flex: 2),

                              // --- Area Form Teks (Fleksibel membagi ruang) ---
                              Expanded(
                                flex: 12,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextField(
                                      controller: _namaController,
                                      decoration: _buildInputDecoration("Nama Lengkap", "Sesuai KTP", Icons.person_outline),
                                      enabled: !_isLoading,
                                    ),
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _buildInputDecoration("Email", "Email aktif", Icons.email_outlined),
                                      enabled: !_isLoading,
                                    ),
                                    TextField(
                                      controller: _hpController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _buildInputDecoration("Nomor HP", "Contoh: 08123456789", Icons.phone_android_outlined),
                                      enabled: !_isLoading,
                                    ),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      decoration: _buildInputDecoration("Kata Sandi", "Buat kata sandi", Icons.lock_outline).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey[500], size: 20),
                                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                        ),
                                      ),
                                      enabled: !_isLoading,
                                    ),
                                    TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: !_isConfirmPasswordVisible,
                                      decoration: _buildInputDecoration("Konfirmasi Kata Sandi", "Ulangi kata sandi", Icons.lock_reset).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey[500], size: 20),
                                          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                        ),
                                      ),
                                      enabled: !_isLoading,
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(flex: 2),

                              // --- Area Image Pickers ---
                              Text("Dokumen Pendukung", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Selfie
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _pickImage(ImageSource.camera, true),
                                      child: Container(
                                        height: 75,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                          borderRadius: BorderRadius.circular(12),
                                          image: _imageSelfie != null ? DecorationImage(image: FileImage(_imageSelfie!), fit: BoxFit.cover) : null,
                                        ),
                                        child: _imageSelfie == null
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.camera_front, size: 24, color: primaryColor.withOpacity(0.6)),
                                                  const SizedBox(height: 4),
                                                  Text("Selfie", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // KTP
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showKtpPicker(context),
                                      child: Container(
                                        height: 75,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                          borderRadius: BorderRadius.circular(12),
                                          image: _imageKtp != null ? DecorationImage(image: FileImage(_imageKtp!), fit: BoxFit.cover) : null,
                                        ),
                                        child: _imageKtp == null
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.badge_outlined, size: 24, color: primaryColor.withOpacity(0.6)),
                                                  const SizedBox(height: 4),
                                                  Text("KTP", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Spacer(flex: 2),

                              // --- Tombol Submit ---
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Text(
                                          'DAFTAR',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk lingkaran ornamen background
  Widget _buildCircleOrnament(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
