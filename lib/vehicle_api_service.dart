import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';

class VehicleApiService {
  // READ (AVAILABLE)
  static Future<List<Map<String, dynamic>>> getKendaraanTersedia() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/kendaraan/tersedia'));
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
      // Gunakan Uri.encodeComponent agar spasi pada nama tidak memecah URL API
      final encodedNama = Uri.encodeComponent(namaSopir);
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/kendaraan/pekerjaan-saya/$encodedNama'));
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
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/check-in'),
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/lepas'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error API selesaikanPekerjaan: $e");
      return false;
    }
  }
}