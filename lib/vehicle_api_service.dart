import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';
import 'package:sikendi/auth_service.dart';

class VehicleApiService {
  // Helper to get headers with token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // READ (AVAILABLE)
  static Future<List<Map<String, dynamic>>> getKendaraanTersedia() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/tersedia'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print("Error API getKendaraanTersedia: $e");
      return [];
    }
  }

  // READ (MY JOB)
  static Future<List<Map<String, dynamic>>> getPekerjaanSaya(String namaSopir) async {
    try {
      final headers = await _getHeaders();
      // Gunakan Uri.encodeComponent agar spasi pada nama tidak memecah URL API
      final encodedNama = Uri.encodeComponent(namaSopir);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/pekerjaan-saya/$encodedNama'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print("Error API getPekerjaanSaya: $e");
      return [];
    }
  }

  // UPDATE (CHECK-IN)
  static Future<bool> ambilKendaraan(String deviceId, String namaSopir) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/check-in'),
        headers: headers,
        body: jsonEncode({'deviceId': deviceId, 'namaSopir': namaSopir}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error API ambilKendaraan: $e");
      return false;
    }
  }

  // UPDATE (CHECK-OUT)
  static Future<bool> selesaikanPekerjaan(String deviceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/check-out'),
        headers: headers,
        body: jsonEncode({'deviceId': deviceId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error API selesaikanPekerjaan: $e");
      return false;
    }
  }
}