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
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
      }
    } catch (e) {
    }
  }

  static Future<void> deleteKegiatan(Object id) async { // Tipe ID mungkin perlu diubah menjadi String
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan/${id.toString()}'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
        return null;
      }
    } catch (e) {
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
    String? fotoUrl,
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
          'foto_url': fotoUrl,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
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
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> defined =
            (data['defined'] as List).cast<Map<String, dynamic>>();
        final List<Map<String, dynamic>> undefined =
            (data['undefined'] as List).cast<Map<String, dynamic>>();

        return {'defined': defined, 'undefined': undefined};
      } else {
        return {'defined': [], 'undefined': []};
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
        return [];
      }
    } catch (e) {
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
      }
    } catch (e) {
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
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getManagerHierarchy() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/hierarchy'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getManagerActivityLog(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/activity/$email'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getManagerMe() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/me'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
    }
    return null;
  }

  static Future<bool> updateManagerMe({String? noHp, String? base64Selfie}) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/manager/update-me'),
        headers: await _getHeaders(),
        body: jsonEncode({
          if (noHp != null) 'no_hp': noHp,
          if (base64Selfie != null) 'foto_selfie': base64Selfie,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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
      return {'success': false, 'message': 'Kesalahan koneksi server'};
    }
  }

  // =================================================================
  // BAGIAN SOPIR
  // =================================================================

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
      return [];
    }
  }

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
    }
    return null;
  }

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
    }
    return [];
  }

  static Future<bool> ambilKendaraan(String deviceId, String namaSopir) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/ambil'),
        headers: await _getHeaders(),
        body: json.encode({"namaSopir": namaSopir}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> selesaikanPekerjaan(Object id) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/check-out'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id.toString()}),
      );
    } catch (e) {
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
    }
    return null;
  }

  // =================================================================
  // BAGIAN DETAIL KENDARAAN
  // =================================================================

  static Future<Map<String, dynamic>?> getDetailKendaraan(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }

  static Future<bool> updateKendaraanDetail(String deviceId, String plat, String model) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId'),
        headers: await _getHeaders(),
        body: jsonEncode({'plat': plat, 'model': model}),
      );
      return response.statusCode == 200;
    } catch (e) {
    }
    return false;
  }

  static Future<bool> updateFotoKendaraan(String deviceId, String fotoData) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/foto'),
        headers: await _getHeaders(),
        body: jsonEncode({'foto_url': fotoData}),
      );
      return response.statusCode == 200;
    } catch (e) {
    }
    return false;
  }

  static Future<bool> updateFotoProfilSopir(String email, String base64Image) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/foto'),
        headers: await _getHeaders(),
        body: jsonEncode({'foto_profil': base64Image}),
      );
      return response.statusCode == 200;
    } catch (e) {
    }
    return false;
  }

  static Future<void> updateFcmToken(String email, String fcmToken) async {
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({'fcmToken': fcmToken}),
      );
    } catch (e) {
    }
  }

  static Future<void> clearFcmToken(String email) async {
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({'fcmToken': null}),
      );
    } catch (e) {
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
    }
    return [];
  }

  // =================================================================
  // BAGIAN PENUGASAN SOPIR (Driver Assignment)
  // =================================================================

  static Future<List<Map<String, dynamic>>> getSemuaPenugasan() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
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
      }
    } catch (e) {
    }
    return [];
  }

  static Future<Map<String, dynamic>> getPenugasanSelesaiRecent({int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan-selesai/recent?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
    }
    return {'data': [], 'metadata': {'totalRecords': 0, 'totalPages': 0, 'currentPage': 1, 'limit': limit}};
  }

  static Future<List<Map<String, dynamic>>> getPenugasanSelesaiBySopir(String namaSopir) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan-selesai/sopir/$namaSopir'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
    }
    return [];
  }

  static Future<Map<String, dynamic>> selesaikanTugas({
    required String deviceId,
    String? fotoMobilAkhir,
    String? catatanDriver,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manager/selesaikan-tugas'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'deviceId': deviceId,
          'foto_mobil_akhir': fotoMobilAkhir,
          'catatan_driver': catatanDriver,
        }),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  static Future<Map<String, dynamic>> buatPenugasan({
    required String deviceId,
    required String namaSopir,
    String? tugas,
    double? maxSpeed,
    double? maxRadius,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'deviceId': deviceId,
          'namaSopir': namaSopir,
          'tugas': tugas,
          'max_speed': maxSpeed,
          'max_radius': maxRadius,
        }),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  static Future<Map<String, dynamic>> updateAvailability({
    required String email,
    required String statusKetersediaan,
    String? alasanTidakTersedia,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/sopir/$email/update-availability'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'status_ketersediaan': statusKetersediaan,
          if (alasanTidakTersedia != null) 'alasan_tidak_tersedia': alasanTidakTersedia,
        }),
      );
      final body = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Terjadi kesalahan',
        'user': body['user'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  static Future<bool> cabutPenugasan(String deviceId, {String? alasan}) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/manager/penugasan/$deviceId'),
        headers: await _getHeaders(),
        body: jsonEncode({'alasan': alasan ?? 'Dicabut oleh Manager'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
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
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['tugas'];
      }
    } catch (e) {
    }
    return null;
  }

  static Future<bool> acceptTugas(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sopir/tugas/accept'),
        headers: await _getHeaders(),
        body: jsonEncode({'deviceId': deviceId}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectTugas(String deviceId, String alasan) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sopir/tugas/reject'),
        headers: await _getHeaders(),
        body: jsonEncode({'deviceId': deviceId, 'alasan': alasan}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getGeofencingAlerts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manager/alerts'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        debugPrint('[Alerts] Response bukan array: ${response.body.substring(0, 200)}');
        return [];
      }
      debugPrint('[Alerts] HTTP ${response.statusCode}: ${response.body.substring(0, 200)}');
    } catch (e) {
      debugPrint('[Alerts] Exception: $e');
    }
    return [];
  }
}
