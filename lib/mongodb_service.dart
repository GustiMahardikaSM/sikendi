import 'dart:convert';
import 'dart:developer';
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
        print("Gagal menambah kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('Error adding kegiatan: $e');
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
        print("Gagal mengambil jadwal kegiatan: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print('Error getting kegiatan: $e');
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
        print("Gagal mengambil semua jadwal kegiatan: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print('Error getting all kegiatan: $e');
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
        print("Gagal update kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('Error updating kegiatan: $e');
    }
  }

  static Future<void> deleteKegiatan(Object id) async { // Tipe ID mungkin perlu diubah menjadi String
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kegiatan/${id.toString()}'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
        print("Gagal menghapus kegiatan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('Error deleting kegiatan: $e');
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
        print("Gagal mengambil data sopir: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Terjadi error saat memanggil API sopir: $e");
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
        print("Gagal mengambil data sopir pending: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Terjadi error saat memanggil API sopir pending: $e");
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
      print("Error Approve Driver: $e");
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
      print("Error Reject Driver: $e");
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
        print("Gagal melakukan lepas paksa kendaraan: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Terjadi error saat API lepas paksa kendaraan: $e");
      return null;
    }
  }

  static Future<bool> tambahKendaraanManager(
    String plat,
    String model,
    String deviceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'plat': plat,
          'model': model,
          'deviceId': deviceId,
        }),
      );
      // Berhasil jika status code 200 (OK) atau 201 (Created)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Terjadi error saat API tambah kendaraan: $e");
      return false;
    }
  }

  static Future<bool> updateKendaraanManager(
    String gps1,
    String plat,
    String model,
    String? status,
  ) async {
    try {
      final body = {
        'plat': plat,
        'model': model,
      };

      // Hanya tambahkan status ke body jika tidak null
      if (status != null) {
        body['status'] = status;
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$gps1'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print("Terjadi error saat API update kendaraan: $e");
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
      print("Terjadi error saat API hapus metadata kendaraan: $e");
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
        print("Gagal mengambil data manager (dipisah): ${response.statusCode} - ${response.body}");
        return {'defined': [], 'undefined': []};
      }
    } catch (e) {
      print("Terjadi error saat API data manager (dipisah): $e");
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
        print("Gagal mengambil semua data manager: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error API getSemuaDataUntukManager: $e");
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
        print("Gagal mengambil data armada (fleet): ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error API getFleetDataForManager: $e");
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
        };
      } else {
        print("Gagal mengambil dashboard summary: ${response.statusCode}");
      }
    } catch (e) {
      print("Error API getDashboardSummary: $e");
    }
    return {'total': 0, 'dipakai': 0, 'tersedia': 0, 'pending': 0};
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
      print("Error GET Kendaraan Tersedia: $e");
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
      print("Error API getPekerjaanBySopir: $e");
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
      print("Error API getPekerjaanSaya: $e");
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
      print("Error PUT Ambil Kendaraan: $e");
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
      print("Error API selesaikanPekerjaan: $e");
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
      print("Error API getLatestGpsData: $e");
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
      print("Error API getDetailKendaraan: $e");
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
      print("Error API updateKendaraanDetail: $e");
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
      print("Error API updateFotoKendaraan: $e");
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
      print("Error API updateFotoProfilSopir: $e");
    }
    return false;
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
      print("Error API getTripHistory: $e");
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
      print("Error API getTripHistoryBySopir: $e");
    }
    return [];
  }
}
