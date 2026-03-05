import 'package:flutter/material.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/manager_page.dart';

class ManagerLoginPage extends StatefulWidget {
  const ManagerLoginPage({super.key});

  @override
  State<ManagerLoginPage> createState() => _ManagerLoginPageState();
}

class _ManagerLoginPageState extends State<ManagerLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password harus diisi')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    // 1. Hash the password using the function from AuthService
    final hashedPassword = AuthService.hashPassword(password);

    // 2. Call the loginManager function from MongoDBService
    final bool isLoggedIn = await MongoDBService.loginManager(email, hashedPassword);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (isLoggedIn) {
        // Panggil dialog privasi setelah login berhasil
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kredensial Benar! Silakan setujui privasi data.'),
            backgroundColor: Colors.green,
          ),
        );
        _showPrivacyDialog();
      } else {
        // 4. Show SnackBar on failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Gagal: Email atau Password salah.')),
        );
      }
    }
  }

  // Fungsi untuk menampilkan dialog persetujuan privasi data
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa menutup dialog dengan tap di luar
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Persetujuan Privasi Data'),
          content: const Text(
            'Sesuai dengan UU No. 27 Tahun 2022 tentang Perlindungan Data Pribadi:\n\n'
            '1. Aplikasi ini akan mengakses lokasi perangkat Anda secara real-time.\n'
            '2. Data lokasi digunakan hanya untuk keperluan operasional kendaraan dinas Undip.\n'
            '3. Dengan melanjutkan, Anda menyetujui pengumpulan dan pemrosesan data ini.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog jika batal
              },
              child: const Text('Tolak'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                
                // Setelah setuju, baru arahkan ke halaman ManagerPage sesungguhnya
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerPage()),
                );
              },
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
      appBar: AppBar(
        title: const Text('Login Manajer'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat Datang, Manajer',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan masuk untuk melanjutkan',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Login'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
