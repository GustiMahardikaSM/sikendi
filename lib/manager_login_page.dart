import 'package:flutter/material.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/manager_page.dart';

class ManagerLoginPage extends StatefulWidget {
  const ManagerLoginPage({super.key});

  @override
  State<ManagerLoginPage> createState() => _ManagerLoginPageState();
}

// Tambahkan SingleTickerProviderStateMixin untuk menggunakan AnimationController
class _ManagerLoginPageState extends State<ManagerLoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Tema Warna Kustom
  final Color primaryColor = const Color(0xFF003366); // Navy Blue
  final Color accentColor = const Color(0xFFFFD700); // Gold

  // Variabel Animasi
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Inisialisasi AnimationController (durasi 1.2 detik untuk kesan lambat & mewah)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Animasi Opacity (Fade In)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Animasi Meluncur dari bawah (Slide Up)
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Animasi Membesar (Scale) untuk Logo
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // Mulai animasi saat halaman dibuka
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose(); // Wajib di-dispose agar tidak memory leak
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email dan password harus diisi'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    // Panggil API Node.js untuk Login Manager
    var result = await AuthService.loginManager(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Terjadi kesalahan koneksi atau server."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Email atau Password salah."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kredensial Benar! Silakan setujui privasi data.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _showPrivacyDialog();
      }
    }
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(Icons.privacy_tip, color: primaryColor, size: 48),
          title: const Text(
            'Persetujuan Privasi Data',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Sesuai dengan UU No. 27 Tahun 2022 tentang Perlindungan Data Pribadi:\n\n'
            '1. Aplikasi ini akan mengakses lokasi perangkat Anda secara real-time.\n'
            '2. Data lokasi digunakan hanya untuk keperluan operasional kendaraan dinas.\n'
            '3. Dengan melanjutkan, Anda menyetujui pengumpulan dan pemrosesan data ini.',
            style: TextStyle(fontSize: 14, height: 1.5),
            textAlign: TextAlign.justify,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Tolak'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Setuju & Masuk'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient yang Mewah
          Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  const Color(0xFF001F3F), // Navy yang lebih gelap agar elegan
                ],
              ),
            ),
          ),
          
          // Dekorasi Lingkaran
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.02),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- ANIMASI LOGO ---
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded, // Menggunakan icon admin/manager
                            size: 64,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- ANIMASI CARD LOGIN ---
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2), // Soft shadow
                                blurRadius: 30, // Sebarannya dibuat besar agar elegan
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Portal Manajer',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Akses eksklusif untuk pengelolaan operasional kendaraan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),
                              
                              // Input Email
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Masukkan email manajer',
                                  prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                ),
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 20),
                              
                              // Input Password
                              TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi',
                                  hintText: 'Masukkan kata sandi',
                                  prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey[500],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 40),
                              
                              // Tombol Login
                              Container(
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0, // Matikan elevation bawaan karena sudah pakai BoxShadow
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Text(
                                          'Masuk',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
