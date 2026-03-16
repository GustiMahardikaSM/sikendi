import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Gunakan 10.0.2.2 jika diuji di Emulator Android.
  // Jika di HP Fisik, ganti dengan IP Address WiFi Anda (misal 192.168.1.10)
  static const String _baseUrl = "http://10.0.2.2:3000/api";

  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<Map<String, dynamic>?> loginSopir(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login-sopir'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);

      // Status 200 = Sukses (aktif)
      if (response.statusCode == 200) {
        return decoded; 
      } else {
        // Status gagal (pending, ditolak, atau salah password)
        return {
          'error': decoded['error'] ?? 'unknown',
          'message': decoded['message'] ?? 'Terjadi kesalahan server.',
        };
      }
    } catch (e) {
      print("Error Login HTTP: $e");
      return {'error': 'exception', 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  static Future<String> signUpSopir({
    required String email,
    required String password,
    required String nama,
    required String noHp,
    required String fotoSelfieBase64,
    required String fotoKtpBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register-sopir'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'nama': nama,
          'noHp': noHp,
          'base64Selfie': fotoSelfieBase64,
          'base64Ktp': fotoKtpBase64,
        }),
      );

      if (response.statusCode == 201) {
        return "Sukses";
      } else {
        final decoded = jsonDecode(response.body);
        return decoded['message'] ?? "Pendaftaran gagal.";
      }
    } catch (e) {
      print("Error Register HTTP: $e");
      return "Error jaringan: Tidak dapat terhubung ke server.";
    }
  }
}
