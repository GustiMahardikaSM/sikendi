import 'package:flutter/material.dart';
import 'auth_service.dart'; // Import service yang kita buat tadi

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _namaController = TextEditingController();
  final _hpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;


  void _handleSignUp() async {
    // Validasi input
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty || _namaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua field wajib diisi!")));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password dan konfirmasi password tidak cocok!")));
      return;
    }

    setState(() => _isLoading = true);

    // Panggil fungsi Sign Up dari AuthService
    String result = await AuthService.signUpSopir(
      _emailController.text,
      _passwordController.text,
      _namaController.text,
      _hpController.text,
    );

    setState(() => _isLoading = false);

    if (result == "Sukses") {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pendaftaran Berhasil! Silakan Login.")));
        Navigator.pop(context); // Kembali ke halaman Login
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $result")));
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
          children: [
            const Icon(Icons.person_add, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            TextField(controller: _namaController, decoration: const InputDecoration(labelText: "Nama Lengkap")),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email")),
            TextField(
              controller: _passwordController, 
              obscureText: !_isPasswordVisible, 
              decoration: InputDecoration(
                labelText: "Password",
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
            TextField(
              controller: _confirmPasswordController, 
              obscureText: !_isConfirmPasswordVisible, 
              decoration: InputDecoration(
                labelText: "Konfirmasi Password",
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                )
              ),
            ),
            TextField(controller: _hpController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Nomor HP")),
            const SizedBox(height: 30),
            
            _isLoading 
            ? const CircularProgressIndicator()
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSignUp,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("DAFTAR SEKARANG", style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}