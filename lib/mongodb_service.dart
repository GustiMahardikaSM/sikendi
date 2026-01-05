import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';

class MongoService {
  // --- KONFIGURASI DB (Sesuai Request) ---
  static final String _mongoUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/gps_1?retryWrites=true&w=majority";
  
  static final String _collectionName = "gps_location";

  static Db? _db;
  static DbCollection? _collection;

  // 1. KONEKSI DATABASE
  // Panggil ini di main() sebelum runApp
  static Future<void> connect() async {
    try {
      _db = await Db.create(_mongoUrl);
      await _db!.open();
      inspect(_db);
      _collection = _db!.collection(_collectionName);
      print("✅ Berhasil Terkoneksi ke MongoDB Atlas (gps_location)");
    } catch (e) {
      print("❌ Gagal Koneksi: $e");
    }
  }

  // =================================================================
  // BAGIAN MANAJER
  // (Manager bisa melihat semua & menambah kendaraan valid)
  // =================================================================

  // CREATE: Hanya Manager yang boleh mendaftarkan Device ID GPS asli
  static Future<bool> tambahKendaraanManager(String plat, String model, String deviceId) async {
    try {
      // Cek duplikasi device_id
      final adaData = await _collection!.findOne(where.eq('device_id', deviceId));
      if (adaData != null) {
        print("Device ID sudah terdaftar!");
        return false;
      }

      await _collection!.insert({
        'plat': plat,
        'model': model,
        'device_id': deviceId, // Kunci utama koneksi GPS
        'status': 'Tersedia',  // Default awal
        'peminjam': null,      // Belum ada sopir
        'waktu_ambil': null,
        'created_at': DateTime.now().toIso8601String()
      });
      return true;
    } catch (e) {
      print("Error tambah kendaraan: $e");
      return false;
    }
  }

  // READ (ALL): Manager melihat SIAPA mengerjakan APA
  // Manager melihat semua data tanpa filter
  static Future<List<Map<String, dynamic>>> getSemuaDataUntukManager() async {
    try {
      final data = await _collection!.find().toList();
      return data;
    } catch (e) {
      print("Error get data manager: $e");
      return [];
    }
  }

  // READ (FLEET): Manager melihat posisi terakhir SETIAP device unik di peta
  static Future<List<Map<String, dynamic>>> getFleetDataForManager() async {
    try {
      // Ambil 100 data terakhir untuk dianalisis
      final data = await _collection!
          .find(where.sortBy('server_received_at', descending: true).limit(100))
          .toList();

      // Filter untuk mendapatkan hanya data paling baru dari setiap device_id unik
      Map<String, Map<String, dynamic>> uniqueVehicles = {};
      for (var doc in data) {
        String deviceId = doc['device_id'] ?? "Unknown";
        if (!uniqueVehicles.containsKey(deviceId)) {
          uniqueVehicles[deviceId] = doc;
        }
      }
      return uniqueVehicles.values.toList();
    } catch (e) {
      print("Error get fleet data: $e");
      return [];
    }
  }

  // =================================================================
  // BAGIAN SOPIR
  // (Sopir hanya melihat yg tersedia & pekerjaannya sendiri)
  // =================================================================

  // READ (AVAILABLE): Sopir mencari mobil untuk bekerja
  // Filter: Hanya yang statusnya 'Tersedia'
  static Future<List<Map<String, dynamic>>> getKendaraanTersedia() async {
    try {
      final data = await _collection!
          .find(where.eq('status', 'Tersedia'))
          .toList();
      return data;
    } catch (e) {
      print("Error get tersedia: $e");
      return [];
    }
  }

  // READ (MY JOB): Sopir melihat pekerjaan dia sendiri
  // Filter: Hanya yang peminjam == namaSopir
  static Future<List<Map<String, dynamic>>> getPekerjaanSaya(String namaSopir) async {
    try {
      final data = await _collection!
          .find(where.eq('peminjam', namaSopir)) // Filter isolasi driver
          .toList();
      return data;
    } catch (e) {
      print("Error get pekerjaan saya: $e");
      return [];
    }
  }

  // UPDATE (CHECK-IN): Sopir mengambil mobil
  static Future<void> ambilKendaraan(ObjectId id, String namaSopir) async {
    try {
      // Update data di server
      await _collection!.update(
        where.id(id),
        modify
          .set('status', 'Dipakai')        // Ubah status
          .set('peminjam', namaSopir)      // Catat nama sopir
          .set('waktu_ambil', DateTime.now().toIso8601String()), // Catat waktu
      );
      print("✅ Mobil berhasil diambil oleh $namaSopir");
    } catch (e) {
      print("Error ambil kendaraan: $e");
    }
  }

  // UPDATE (CHECK-OUT): Sopir mengembalikan mobil (Selesai tugas)
  static Future<void> selesaikanPekerjaan(ObjectId id) async {
    try {
      await _collection!.update(
        where.id(id),
        modify
          .set('status', 'Tersedia')
          .set('peminjam', null)
          .set('waktu_ambil', null),
      );
      print("✅ Pekerjaan selesai, mobil kembali tersedia");
    } catch (e) {
      print("Error selesai pekerjaan: $e");
    }
  }

  // =================================================================
  // BAGIAN TRACKING
  // =================================================================
  
  // Mengambil 1 data GPS paling baru dari collection
  static Future<Map<String, dynamic>?> getLatestGpsData() async {
    try {
      final data = await _collection!
          .find(where.sortBy('server_received_at', descending: true).limit(1))
          .toList();
      if (data.isNotEmpty) {
        return data.first;
      }
      return null;
    } catch (e) {
      print("Error get latest GPS data: $e");
      return null;
    }
  }
}