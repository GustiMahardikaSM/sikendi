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

  void _handleLogin() async {
    setState(() => _isLoading = true);

    var user = await AuthService.loginSopir(
      _emailController.text, 
      _passwordController.text
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (mounted) {
        _showConsentDialog(context, "Sopir", user['nama_lengkap']);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Gagal! Email atau Password salah.")),
        );
      }
    }
  }

  void _showConsentDialog(BuildContext context, String role, String? namaUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Selamat Datang, $namaUser"),
        content: const Text(
          "Sesuai UU No. 27 Tahun 2022, aplikasi ini akan mengakses lokasi Anda untuk keperluan dinas.",
          textAlign: TextAlign.justify,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverPage()),
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
      appBar: AppBar(
        title: const Text("Login Sopir"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
            const Text("Login Sopir SiKenDi", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                  child: const Text("MASUK", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
              },
              child: const Text("Belum punya akun? Daftar sebagai Sopir"),
            ),
          ],
        ),
      ),
    );
  }
}
