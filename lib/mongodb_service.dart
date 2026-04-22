import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';
import 'package:sikendi/models/kegiatan_sopir.dart';
import 'package:sikendi/auth_service.dart';

// TODO: Ganti nama file ini menjadi 'api_service.dart' atau nama lain yang lebih sesuai
class MongoDBService {
  // --- KONFIGURASI & KONEKSI LAMA (AKAN DIHAPUS) ---
  // Semua variabel dan fungsi koneksi (_mongoLokasiUrl, connect(), dll) telah dihapus
  // karena koneksi database sekarang ditangani oleh backend.

  // --- HELPER UNTUK MENDAPATKAN HEADERS + TOKEN ---
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =================================================================
  // BAGIAN JADWAL SOPIR
  // =================================================================

  static Future<void> addKegiatan({
    required String email,
    required String judul,
    required DateTime waktu,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'email': email,
          'judul': judul,
          'waktu': waktu.toIso8601String(),
          'status': 'Belum',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint("Gagal menambah kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('Error adding kegiatan: $e');
    }
  }

  static Future<List<KegiatanSopir>> getKegiatan(String email) async {
    try {
      final response = await http.get(
        // Sesuaikan dengan route backend yang baru
        Uri.parse('${ApiConfig.baseUrl}/kegiatan/sopir/$email'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => KegiatanSopir(
          id: json['_id'] ?? json['id'] ?? '',
          email: json['email'] ?? email,
          judul: json['judul'] ?? 'Tanpa Judul',
          waktu: json['waktu'] != null ? DateTime.parse(json['waktu']) : DateTime.now(),
          status: json['status'] ?? 'Belum',
        )).toList();
      } else {
        debugPrint("Gagal mengambil jadwal kegiatan: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint('Error getting kegiatan: $e');
      return [];
    }
  }

  static Future<List<KegiatanSopir>> getAllKegiatan() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => KegiatanSopir(
          id: json['_id'] ?? json['id'] ?? '',
          email: json['email'] ?? '',
          judul: json['judul'] ?? 'Tanpa Judul',
          waktu: json['waktu'] != null ? DateTime.parse(json['waktu']) : DateTime.now(),
          status: json['status'] ?? 'Belum',
        )).toList();
      } else {
        debugPrint("Gagal mengambil semua jadwal kegiatan: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint('Error getting all kegiatan: $e');
      return [];
    }
  }

  static Future<void> updateKegiatan({
    required Object id, // Tipe ID mungkin perlu diubah menjadi String
    required String judul,
    required DateTime waktu,
    required String status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan/${id.toString()}'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'judul': judul,
          'waktu': waktu.toIso8601String(),
          'status': status,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint("Gagal update kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('Error updating kegiatan: $e');
    }
  }

  static Future<void> deleteKegiatan(Object id) async { // Tipe ID mungkin perlu diubah menjadi String
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan/${id.toString()}'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
        debugPrint("Gagal menghapus kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('Error deleting kegiatan: $e');
    }
  }

  // =================================================================
  // BAGIAN DATA SOPIR
  // =================================================================

  static Future<List<Map<String, dynamic>>> getSemuaSopir() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sopir'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil data sopir: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Terjadi error saat memanggil API sopir: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sopir/pending'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil data sopir pending: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Terjadi error saat memanggil API sopir pending: $e");
      // Di implementasi lama, error di-throw ulang. Kita bisa memilih untuk
      // melempar exception atau mengembalikan list kosong tergantung kebutuhan UI.
      // Untuk konsistensi, kita kembalikan list kosong.
      return [];
    }
  }

  // 2. PUT Approve Driver
  static Future<bool> approveDriver(String driverId) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$driverId/approve'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error Approve Driver: $e");
      return false;
    }
  }

  // 3. DELETE Reject Driver
  static Future<bool> rejectDriver(String driverId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$driverId/reject'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error Reject Driver: $e");
      return false;
    }
  }

  // 4. Jembatan Utama Update Status (Gunakan String untuk ID)
  static Future<void> updateDriverStatus(String driverId, String status) async {
    bool success;
    if (status == 'aktif') {
      success = await approveDriver(driverId);
    } else if (status == 'ditolak') {
      success = await rejectDriver(driverId);
    } else {
      throw Exception("Status tidak dikenal: $status");
    }
    if (!success) throw Exception("Gagal memperbarui status sopir dari server.");
  }

  // approveDriver dan rejectDriver akan menjadi logika di backend, tidak perlu di sini.

  // =================================================================
  // BAGIAN MANAJER
  // =================================================================

  static Future<Map<String, dynamic>?> lepasPaksaKendaraan(String deviceId) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/lepas'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Gagal melakukan lepas paksa kendaraan: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Terjadi error saat API lepas paksa kendaraan: $e");
      return null;
    }
  }

  static Future<bool> tambahKendaraanManager(
    String plat,
    String model,
    String deviceId, {
    String? kepemilikan,
    String? fakultas,
    String? departemen,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'plat': plat,
          'model': model,
          'deviceId': deviceId,
          'kepemilikan': kepemilikan,
          'fakultas': fakultas,
          'departemen': departemen,
        }),
      );
      // Berhasil jika status code 200 (OK) atau 201 (Created)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Terjadi error saat API tambah kendaraan: $e");
      return false;
    }
  }


  static Future<bool> updateKendaraanManager(
    String gps1,
    String plat,
    String model,
    String? status, {
    String? kepemilikan,
    String? fakultas,
    String? departemen,
  }) async {
    try {
      final body = {
        'plat': plat,
        'model': model,
      };

      // Hanya tambahkan status ke body jika tidak null
      if (status != null) {
        body['status'] = status;
      }
      
      if (kepemilikan != null) body['kepemilikan'] = kepemilikan;
      if (fakultas != null) body['fakultas'] = fakultas;
      if (departemen != null) body['departemen'] = departemen;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$gps1'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Terjadi error saat API update kendaraan: $e");
      return false;
    }
  }

  static Future<bool> transferKendaraan(String deviceId, {
    required String kepemilikan,
    String? fakultas,
    String? departemen,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/transfer'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'kepemilikan': kepemilikan,
          'fakultas': fakultas,
          'departemen': departemen,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error transfer kendaraan: $e");
      return false;
    }
  }


  static Future<bool> hapusMetadataKendaraan(String gps1) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$gps1/metadata'),
        headers: await _getHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Terjadi error saat API hapus metadata kendaraan: $e");
      return false;
    }
  }
  
  static Future<Map<String, List<Map<String, dynamic>>>>
      getSemuaDataUntukManagerDipisah() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/kendaraan/separated'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Backend diharapkan mengembalikan JSON: {"defined": [...], "undefined": [...]}
        final data = jsonDecode(response.body);
        
        // Parsing manual untuk memastikan tipe data list di dalamnya benar
        final List<Map<String, dynamic>> defined =
            (data['defined'] as List).cast<Map<String, dynamic>>();
        final List<Map<String, dynamic>> undefined =
            (data['undefined'] as List).cast<Map<String, dynamic>>();

        return {'defined': defined, 'undefined': undefined};
      } else {
        debugPrint("Gagal mengambil data manager (dipisah): ${response.statusCode} - ${response.body}");
        return {'defined': [], 'undefined': []};
      }
    } catch (e) {
      debugPrint("Terjadi error saat API data manager (dipisah): $e");
      return {'defined': [], 'undefined': []};
    }
  }

  static Future<List<Map<String, dynamic>>> getSemuaDataUntukManager() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/kendaraan/all'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil semua data manager: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error API getSemuaDataUntukManager: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFleetDataForManager() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/fleet'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil data armada (fleet): ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error API getFleetDataForManager: $e");
      return [];
    }
  }

  static Future<Map<String, int>> getDashboardSummary() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/dashboard/summary'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'total': data['total'] ?? 0,
          'dipakai': data['dipakai'] ?? 0,
          'tersedia': data['tersedia'] ?? 0,
          'pending': data['pending'] ?? 0,
          'pendingManager': data['pendingManager'] ?? 0,
          'pendingVehicle': data['pendingVehicle'] ?? 0,
        };
      } else {
        debugPrint("Gagal mengambil dashboard summary: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error API getDashboardSummary: $e");
    }
    return {'total': 0, 'dipakai': 0, 'tersedia': 0, 'pending': 0, 'pendingManager': 0, 'pendingVehicle': 0};


  }

  // MANAJEMEN MANAJER
  static Future<List<Map<String, dynamic>>> getManagerList({String? status}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/list${status != null ? '?status=$status' : ''}'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Error getManagerList: $e");
    }
    return [];
  }


  static Future<bool> verifyManager(String managerId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manager/verify'),
        headers: await _getHeaders(),
        body: jsonEncode({'managerId': managerId, 'action': action}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error verifyManager: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> registerManager({
    required String email,
    required String password,
    required String nama,
    required String no_hp,
    required String level,
    String? fakultas,
    String? departemen,
    String? base64Selfie,
    String? base64Ktp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register-manager'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'nama': nama,
          'no_hp': no_hp,
          'level': level,
          'fakultas': fakultas,
          'departemen': departemen,
          'base64Selfie': base64Selfie,
          'base64Ktp': base64Ktp,
        }),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': body['message'] ?? 'Gagal mendaftar',
      };
    } catch (e) {
      debugPrint("Error registerManager: $e");
      return {'success': false, 'message': 'Kesalahan koneksi server'};
    }
  }


  // =================================================================
  // BAGIAN SOPIR
  // =================================================================

  // READ (AVAILABLE): Sopir mencari mobil untuk bekerja
  static Future<List<Map<String, dynamic>>> getKendaraanTersedia() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/tersedia'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint("Error GET Kendaraan Tersedia: $e");
      return [];
    }
  }

  // READ (MY JOB): Sopir melihat pekerjaan dia sendiri
  static Future<Map<String, dynamic>?> getPekerjaanBySopir(String namaSopir) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/pekerjaan-saya/$namaSopir'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint("Error API getPekerjaanBySopir: $e");
    }
    return null;
  }

  // READ (MY JOB): Sopir melihat pekerjaan dia sendiri
  static Future<List<Map<String, dynamic>>> getPekerjaanSaya(String namaSopir) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/pekerjaan-saya/$namaSopir'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Error API getPekerjaanSaya: $e");
    }
    return [];
  }

  // UPDATE (CHECK-IN): Sopir mengambil mobil
  static Future<bool> ambilKendaraan(String deviceId, String namaSopir) async {
    try {
      // Endpoint diubah dari POST ke PUT agar lebih sesuai dengan REST convention
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/ambil'),
        headers: await _getHeaders(),
        body: json.encode({"namaSopir": namaSopir}),
      );
      
      // Mengembalikan true jika berhasil
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error PUT Ambil Kendaraan: $e");
      return false;
    }
  }

  // UPDATE (CHECK-OUT): Sopir mengembalikan mobil (Selesai tugas)
  static Future<void> selesaikanPekerjaan(Object id) async { // Tipe ID mungkin perlu diubah menjadi String
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/check-out'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id.toString()}),
      );
    } catch (e) {
      debugPrint("Error API selesaikanPekerjaan: $e");
    }
  }

  // =================================================================
  // BAGIAN TRACKING
  // =================================================================

  static Future<Map<String, dynamic>?> getLatestGpsData(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/tracking/latest/$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error API getLatestGpsData: $e");
    }
    return null;
  }

  // =================================================================
  // BAGIAN DETAIL KENDARAAN
  // =================================================================

  static Future<Map<String, dynamic>?> getDetailKendaraan(
    String deviceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error API getDetailKendaraan: $e");
    }
    return null;
  }

  static Future<bool> updateKendaraanDetail(
    String deviceId,
    String plat,
    String model,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId'),
        headers: await _getHeaders(),
        body: jsonEncode({'plat': plat, 'model': model}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error API updateKendaraanDetail: $e");
    }
    return false;
  }

  static Future<bool> updateFotoKendaraan(
    String deviceId,
    String fotoData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/foto'),
        headers: await _getHeaders(),
        body: jsonEncode({'foto_url': fotoData}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error API updateFotoKendaraan: $e");
    }
    return false;
  }

  // ==========================================================
  // FUNGSI UNTUK PROFIL SOPIR
  // ==========================================================
  
  static Future<bool> updateFotoProfilSopir(String email, String base64Image) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/foto'),
        headers: await _getHeaders(),
        body: jsonEncode({'foto_profil': base64Image}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error API updateFotoProfilSopir: $e");
    }
    return false;
  }

  // Fungsi baru untuk menyimpan FCM Token ke backend
  static Future<void> updateFcmToken(String email, String fcmToken) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      if (response.statusCode == 200) {
        debugPrint("FCM Token berhasil disimpan untuk $email");
      } else {
        debugPrint(
            "Gagal menyimpan FCM Token: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error API updateFcmToken: $e");
    }
  }

  // =================================================================
  // BAGIAN TRIP HISTORY
  // =================================================================

  static Future<List<Map<String, dynamic>>> getTripHistory(String gpsId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$gpsId/history'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Error API getTripHistory: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getTripHistoryBySopir(String namaSopir) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$namaSopir/history'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Error API getTripHistoryBySopir: $e");
    }
    return [];
  }

  // =================================================================
  // BAGIAN PENUGASAN SOPIR (Driver Assignment)
  // =================================================================

  /// Ambil semua data penugasan (kendaraan + status penugasan)
  static Future<List<Map<String, dynamic>>> getSemuaPenugasan() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil data penugasan: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error API getSemuaPenugasan: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getHasilPenugasan() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/hasil-penugasan'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Gagal mengambil data hasil penugasan: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error API getHasilPenugasan: $e");
    }
    return [];
  }

  /// Buat penugasan baru: assign sopir ke kendaraan dengan tugas
  static Future<Map<String, dynamic>> buatPenugasan({
    required String deviceId,
    required String namaSopir,
    String? tugas,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'deviceId': deviceId,
          'namaSopir': namaSopir,
          'tugas': tugas,
        }),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      debugPrint("Error API buatPenugasan: $e");
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  /// Cabut penugasan: unassign sopir dari kendaraan
  static Future<Map<String, dynamic>> cabutPenugasan(String deviceId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan/$deviceId'),
        headers: await _getHeaders(),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      debugPrint("Error API cabutPenugasan: $e");
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  // =================================================================
  // BAGIAN PENUGASAN (DRIVER SIDE)
  // =================================================================

  static Future<Map<String, dynamic>?> getTugasSekarang(String namaSopir) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$namaSopir/tugas-sekarang'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['tugas'];
      }
    } catch (e) {
      debugPrint("Error API getTugasSekarang: $e");
    }
    return null;
  }

  static Future<bool> acceptTugas(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sopir/tugas/accept'),
        headers: await _getHeaders(),
        body: jsonEncode({'deviceId': deviceId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error API acceptTugas: $e");
      return false;
    }
  }

  static Future<bool> rejectTugas(String deviceId, String alasan) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sopir/tugas/reject'),
        headers: await _getHeaders(),
        body: jsonEncode({'deviceId': deviceId, 'alasan': alasan}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error API rejectTugas: $e");
      return false;
    }
  }
}
