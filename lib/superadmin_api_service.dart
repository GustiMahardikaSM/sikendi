import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sikendi/api_config.dart';
import 'package:sikendi/auth_service.dart';

class SuperAdminApiService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/superadmin/stats
  static Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/stats'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return null;
  }

  // GET /api/superadmin/managers
  static Future<List<Map<String, dynamic>>> getAllManagers({
    String? status,
    String? level,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'semua') params['status'] = status;
      if (level != null && level != 'semua') params['level'] = level;
      final uri = Uri.parse('${ApiConfig.baseUrl}/superadmin/managers')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return [];
  }

  // POST /api/superadmin/managers
  static Future<Map<String, dynamic>> createManager({
    required String nama,
    required String email,
    required String password,
    required String level,
    String? noHp,
    String? fakultas,
    String? departemen,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/managers'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'nama': nama,
          'email': email,
          'password': password,
          'level': level,
          if (noHp != null) 'no_hp': noHp,
          if (fakultas != null) 'fakultas': fakultas,
          if (departemen != null) 'departemen': departemen,
        }),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 201, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // PUT /api/superadmin/managers/:id
  static Future<Map<String, dynamic>> editManager(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/managers/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // DELETE /api/superadmin/managers/:id
  static Future<Map<String, dynamic>> deleteManager(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/managers/$id'),
        headers: await _getHeaders(),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // POST /api/superadmin/managers/:id/reset-password
  static Future<Map<String, dynamic>> resetManagerPassword(
    String id,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/managers/$id/reset-password'),
        headers: await _getHeaders(),
        body: jsonEncode({'new_password': newPassword}),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // GET /api/superadmin/logs
  static Future<Map<String, dynamic>> getAllLogs({
    int page = 1,
    String? emailFilter,
  }) async {
    try {
      final params = <String, String>{'page': '$page', 'limit': '30'};
      if (emailFilter != null && emailFilter.isNotEmpty) {
        params['email'] = emailFilter;
      }
      final uri = Uri.parse('${ApiConfig.baseUrl}/superadmin/logs')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return {'data': [], 'metadata': {'totalPages': 1, 'currentPage': 1}};
  }

  // GET /api/superadmin/sopir
  static Future<List<Map<String, dynamic>>> getAllSopir({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'semua') params['status'] = status;
      final uri = Uri.parse('${ApiConfig.baseUrl}/superadmin/sopir')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return [];
  }

  // DELETE /api/superadmin/sopir/:id
  static Future<Map<String, dynamic>> deleteSopir(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/sopir/$id'),
        headers: await _getHeaders(),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // POST /api/superadmin/sopir/:id/verify
  static Future<Map<String, dynamic>> verifySopir(
    String id,
    String action, // 'aktif' atau 'ditolak'
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/superadmin/sopir/$id/verify'),
        headers: await _getHeaders(),
        body: jsonEncode({'action': action}),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // GET /api/superadmin/kendaraan (semua armada tanpa filter scope)
  static Future<List<Map<String, dynamic>>> getAllKendaraan({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'semua') params['status'] = status;
      final uri = Uri.parse('${ApiConfig.baseUrl}/superadmin/kendaraan')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return [];
  }

  // POST /api/kendaraan (reuse endpoint manager — superadmin bypass role check)
  static Future<Map<String, dynamic>> addKendaraan({
    required String plat,
    required String model,
    required String deviceId,
    String kepemilikan = 'universitas',
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
          if (fakultas != null) 'fakultas': fakultas,
          if (departemen != null) 'departemen': departemen,
        }),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // PUT /api/kendaraan/:deviceId
  static Future<Map<String, dynamic>> editKendaraan(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // DELETE /api/kendaraan/:deviceId/metadata
  static Future<Map<String, dynamic>> deleteKendaraan(String deviceId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kendaraan/$deviceId/metadata'),
        headers: await _getHeaders(),
      );
      final decoded = jsonDecode(response.body);
      return {'success': response.statusCode == 200, ...decoded};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
