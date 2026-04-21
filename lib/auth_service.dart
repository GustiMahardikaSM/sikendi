import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {

  static const storage = FlutterSecureStorage();

  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- MANAJEMEN TOKEN JWT ---
  static Future<void> saveToken(String token) async {
    await storage.write(key: 'jwt_token', value: token);
  }

  static Future<String?> getToken() async {
    return await storage.read(key: 'jwt_token');
  }

  static Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  static Future<Map<String, dynamic>?> loginSopir(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login-sopir'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);

      // Status 200 = Sukses (aktif)
      if (response.statusCode == 200) {
        // Simpan token ke memori lokal HP
        if (decoded['token'] != null) {
          await saveToken(decoded['token']);
        }
        
        final user = decoded['user'];
        if (user != null) {
          final nama = user['nama'] ?? user['nama_lengkap'];
          if (nama != null) {
            await storage.write(key: 'nama_sopir', value: nama);
          }
        }
        
        return decoded; 
      } else {
        // Status gagal (pending, ditolak, atau salah password)
        return {
          'error': decoded['error'] ?? 'unknown',
          'message': decoded['message'] ?? 'Terjadi kesalahan server.',
        };
      }
    } catch (e, s) {
      debugPrint("Error Login HTTP: $e");
      debugPrint("Stack trace: $s");
      return {'error': 'exception', 'message': 'Tidak dapat terhubung ke server. Detail: $e'};
    }
  }

  static Future<Map<String, dynamic>?> loginManager(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login-manager'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Simpan token manajer ke memori lokal HP
        if (decoded['token'] != null) {
          await saveToken(decoded['token']);
        }
        return decoded; 
      } else {
        return {
          'error': decoded['error'] ?? 'unknown',
          'message': decoded['message'] ?? 'Terjadi kesalahan server.',
        };
      }
    } catch (e, s) {
      debugPrint("Error Login Manager HTTP: $e");
      debugPrint("Stack trace: $s");
      return {'error': 'exception', 'message': 'Tidak dapat terhubung ke server. Detail: $e'};
    }
  }

  // CREATE: Mendaftarkan akun sopir baru via REST API
  static Future<String?> daftarAkunSopir({
    required String nama,
    required String email,
    required String password,
    required String noHp,
    required String fotoKtpTemp,
    required String fotoSelfieTemp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sopir/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "nama": nama,
          "email": email,
          "password": password, // Pastikan Hash dilakukan sebelum dipanggil, atau sesuai logika Anda
          "no_hp": noHp,
          "foto_ktp_temp": fotoKtpTemp,
          "foto_selfie_temp": fotoSelfieTemp,
        }),
      );

      if (response.statusCode == 201) {
        return null; // Sukses! (Tidak ada pesan error)
      } else if (response.statusCode == 409) {
        return "Email sudah terdaftar! Gunakan email lain.";
      } else {
        final decoded = jsonDecode(response.body);
        return decoded['error'] ?? decoded['message'] ?? "Pendaftaran gagal. Kode: ${response.statusCode}";
      }
    } catch (e, s) {
      debugPrint("Error Register HTTP: $e");
      debugPrint("Stack trace: $s");
      return "Error jaringan: Tidak dapat terhubung ke server. Detail: $e";
    }
  }
}
