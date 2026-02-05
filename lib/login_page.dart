import 'package:flutter/material.dart';
import 'package:sikendi/driver_page.dart';
import 'auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Ganti fungsi _handleLogin dengan ini
  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password harus diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Panggil service
    // Result bisa berupa User Map (jika sukses/pending) atau Map Error
    var result = await AuthService.loginSopir(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      // 1. Cek apakah result bernilai null (gagal koneksi/db)
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terjadi kesalahan koneksi atau database."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Cek apakah ada key 'error' (password salah / user tidak ketemu)
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Login Gagal"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. Cek Status Akun dari Database (field: 'status_akun')
      String status = result['status_akun'] ?? 'pending';

      if (status == 'aktif') {
        // --- SUKSES: AKUN AKTIF ---
        _showConsentDialog(context, "Sopir", result);
      } else {
        // Ini akan menangani 'pending', 'ditolak', atau status lain yang tidak dikenal
        // Pesan error spesifik sudah ditangani di AuthService dan dicek di `result.containsKey('error')`
        // Blok ini berfungsi sebagai fallback jika 'error' tidak ada tapi status bukan 'aktif'
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(result['message'] ?? "Akun tidak aktif."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Ganti fungsi _showConsentDialog dengan ini
  void _showConsentDialog(
    BuildContext context,
    String role,
    Map<String, dynamic> user,
  ) {
    // FIX: Gunakan key 'nama' sesuai database MongoDB Anda
    String namaUser = user['nama'] ?? "User"; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Selamat Datang, $namaUser"), // Nama sekarang akan muncul benar
        content: const Text(
          "Sesuai UU No. 27 Tahun 2022, aplikasi ini akan mengakses lokasi Anda secara real-time untuk keperluan monitoring dinas.\n\nApakah Anda setuju?",
          textAlign: TextAlign.justify,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), // Tutup dialog
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Tutup dialog
              // Pindah ke halaman driver dengan data user yang valid
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => DriverPage(user: user)),
              );
            },
            child: const Text("Setuju & Masuk"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Sopir")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
            const Text(
              "Login Sopir SiKenDi",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.key),
                labelText: "Password",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                      ),
                      child: const Text(
                        "MASUK",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
              child: const Text("Belum punya akun? Daftar sebagai Sopir"),
            ),
          ],
        ),
      ),
    );
  }
}
