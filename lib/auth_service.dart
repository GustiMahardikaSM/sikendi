import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sikendi/mongodb_service.dart';

class AuthService {

  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

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
    // 1. Ambil token secara manual (hindari getCurrentUser() untuk cegah rekursi)
    final token = await getToken();
    Map<String, dynamic>? user;
    
    if (token != null) {
      try {
        user = JwtDecoder.decode(token);
      } catch (e) {}
    }

    // 2. HAPUS DATA LOKAL SEGERA (Agar Auto-Login tidak memicu navigasi balik)
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'nama_sopir');

    // 3. Bersihkan token di server jika data user tersedia
    if (user != null && user['email'] != null) {
      try {
        await MongoDBService.clearFcmToken(user['email']);
      } catch (e) {}
    }
  }

  // --- MANAJEMEN TUGAS YANG SUDAH DILIHAT ---
  static Future<void> markTaskAsSeen(String taskId) async {
    await storage.write(key: 'last_seen_task_id', value: taskId);
  }

  static Future<bool> isTaskSeen(String taskId) async {
    final lastSeenId = await storage.read(key: 'last_seen_task_id');
    return lastSeenId == taskId;
  }

  // Fungsi baru untuk mendapatkan data user dari token yang tersimpan
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token != null) {
        if (JwtDecoder.isExpired(token)) {
          // Token expired, hapus data lokal (jangan panggil logout() untuk cegah rekursi)
          await storage.delete(key: 'jwt_token');
          await storage.delete(key: 'nama_sopir');
          return null;
        }
        return JwtDecoder.decode(token);
      }
    } catch (e) {
      // Return null jika token tidak valid atau error
    }
    return null;
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
      return "Error jaringan: Tidak dapat terhubung ke server. Detail: $e";
    }
  }
}
