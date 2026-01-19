import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:sikendi/models/kegiatan_sopir.dart';

class MongoService {
  // --- KONFIGURASI DB LOKASI---
  static final String _mongoLokasiUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/gps_1?retryWrites=true&w=majority";
  
  static final String _collectionLokasiName = "gps_location";
  static final String _collectionKendaraanName = "kendaraan";

  static Db? _dbLokasi;
  static DbCollection? _collectionLokasi;
  static DbCollection? _collectionKendaraan;

  // --- KONFIGURASI DB JADWAL & SOPIR ---
  static final String _mongoJadwalUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/demo_akun?retryWrites=true&w=majority";
  static final String _collectionJadwalName = "kegiatan_sopir";
  static final String _collectionSopirName = "sopir";

  static Db? _dbJadwal;
  static DbCollection? _collectionJadwal;
  static DbCollection? _collectionSopir;


  // 1. KONEKSI DATABASE LOKASI
  static Future<void> connect() async {
    try {
      _dbLokasi = await Db.create(_mongoLokasiUrl);
      await _dbLokasi!.open();
      inspect(_dbLokasi);
      _collectionLokasi = _dbLokasi!.collection(_collectionLokasiName);
      _collectionKendaraan = _dbLokasi!.collection(_collectionKendaraanName);
      print("✅ Berhasil Terkoneksi ke MongoDB Atlas (gps_location & kendaraan)");
    } catch (e) {
      print("❌ Gagal Koneksi ke gps_location: $e");
    }
  }

  // 2. KONEKSI DATABASE JADWAL & SOPIR
  static Future<void> connectJadwal() async {
    try {
      _dbJadwal = await Db.create(_mongoJadwalUrl);
      await _dbJadwal!.open();
      inspect(_dbJadwal);
      _collectionJadwal = _dbJadwal!.collection(_collectionJadwalName);
      _collectionSopir = _dbJadwal!.collection(_collectionSopirName);
      print("✅ Berhasil Terkoneksi ke MongoDB Atlas (kegiatan_sopir & sopir)");
    } catch (e) {
      print("❌ Gagal Koneksi ke demo_akun: $e");
    }
  }

  // =================================================================
  // BAGIAN JADWAL SOPIR
  // =================================================================

  // CREATE: Tambah kegiatan baru untuk sopir
  static Future<void> addKegiatan({
    required String email,
    required String judul,
    required DateTime waktu,
  }) async {
    try {
      final kegiatan = KegiatanSopir(
        id: ObjectId(),
        email: email,
        judul: judul,
        waktu: waktu,
        status: 'Belum', // Status default
      );
      await _collectionJadwal!.insert(kegiatan.toMap());
    } catch (e) {
      print('Error adding kegiatan: $e');
    }
  }

  // READ: Ambil semua kegiatan untuk sopir tertentu
  static Future<List<KegiatanSopir>> getKegiatan(String email) async {
    try {
      final data = await _collectionJadwal!.find(where.eq('email', email)).toList();
      return data.map((map) => KegiatanSopir.fromMap(map)).toList();
    } catch (e) {
      print('Error getting kegiatan: $e');
      return [];
    }
  }

  // READ ALL: Ambil semua kegiatan untuk manager
  static Future<List<KegiatanSopir>> getAllKegiatan() async {
    try {
      final data = await _collectionJadwal!.find().toList();
      return data.map((map) => KegiatanSopir.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all kegiatan: $e');
      return [];
    }
  }

  // UPDATE: Perbarui kegiatan sopir
  static Future<void> updateKegiatan({
    required ObjectId id,
    required String judul,
    required DateTime waktu,
    required String status,
  }) async {
    try {
      await _collectionJadwal!.update(
        where.id(id),
        modify
          .set('judul', judul)
          .set('waktu', waktu)
          .set('status', status),
      );
    } catch (e) {
      print('Error updating kegiatan: $e');
    }
  }

  // DELETE: Hapus kegiatan sopir
  static Future<void> deleteKegiatan(ObjectId id) async {
    try {
      await _collectionJadwal!.remove(where.id(id));
    } catch (e) {
      print('Error deleting kegiatan: $e');
    }
  }

  // =================================================================
  // BAGIAN DATA SOPIR
  // =================================================================

  // READ: Ambil semua sopir untuk manager
  static Future<List<Map<String, dynamic>>> getSemuaSopir() async {
    try {
      if (_collectionSopir == null) {
        print('Collection sopir belum ter-inisialisasi. Memanggil connectJadwal()...');
        await connectJadwal();
        if (_collectionSopir == null) {
          print('Gagal inisialisasi collection sopir setelah connectJadwal().');
          return [];
        }
      }
      final data = await _collectionSopir!.find().toList();
      print('getSemuaSopir() - jumlah dokumen: ${data.length}');
      if (data.isNotEmpty) {
        print('Contoh dokumen sopir[0]: ${data.first}');
      }
      return data;
    } catch (e) {
      print('Error getting sopir: $e');
      return [];
    }
  }


  // =================================================================
  // BAGIAN MANAJER
  // (Manager bisa melihat semua & menambah kendaraan valid)
  // =================================================================

  // CREATE: Tambahkan metadata kendaraan ke device GPS yang sudah ada atau buat baru
  static Future<bool> tambahKendaraanManager(String plat, String model, String deviceId) async {
    try {
      // Cek apakah sudah ada metadata dengan gps_1 atau device_id yang sama
      // Cari dokumen yang memiliki gps_1 atau device_id yang sama DAN memiliki model atau plat
      final docsGps1 = await _collectionLokasi!.find(where.eq('gps_1', deviceId)).toList();
      final docsDeviceId = await _collectionLokasi!.find(where.eq('device_id', deviceId)).toList();
      final allDocs = [...docsGps1, ...docsDeviceId];
      // Hapus duplikat berdasarkan _id
      final uniqueDocs = <String, Map<String, dynamic>>{};
      for (var doc in allDocs) {
        uniqueDocs[doc['_id'].toString()] = doc;
      }
      final allDocsUnique = uniqueDocs.values.toList();
      
      // Cek apakah ada yang sudah punya metadata
      final adaMetadata = allDocsUnique.firstWhere(
        (doc) => doc['model'] != null || doc['plat'] != null,
        orElse: () => <String, dynamic>{},
      );
      
      if (adaMetadata.isNotEmpty) {
        print("Device ID (gps_1) sudah terdaftar dengan metadata!");
        return false;
      }

      // Cek apakah ada dokumen GPS location yang sudah ada (tanpa metadata)
      final adaGps = allDocsUnique.isNotEmpty ? allDocsUnique.first : null;
      
      if (adaGps != null) {
        // Update dokumen GPS location yang sudah ada dengan menambahkan metadata
        await _collectionLokasi!.update(
          where.id(adaGps['_id']),
          modify
            .set('plat', plat)
            .set('model', model)
            .set('gps_1', deviceId)
            .set('device_id', deviceId)
            .set('status', 'Tersedia')
            .set('peminjam', null)
            .set('waktu_ambil', null),
        );
      } else {
        // Buat dokumen baru jika belum ada sama sekali
        await _collectionLokasi!.insert({
          'plat': plat,
          'model': model,
          'gps_1': deviceId,
          'device_id': deviceId,
          'status': 'Tersedia',
          'peminjam': null,
          'waktu_ambil': null,
          'created_at': DateTime.now().toIso8601String()
        });
      }
      return true;
    } catch (e) {
      print("Error tambah kendaraan: $e");
      return false;
    }
  }

  // UPDATE: Update metadata kendaraan berdasarkan gps_1
  // Update semua dokumen yang memiliki gps_1 atau device_id yang sama
  static Future<bool> updateKendaraanManager(String gps1, String plat, String model, String? status) async {
    try {
      // Query untuk semua dokumen dengan gps_1 atau device_id yang sama
      final docsGps1 = await _collectionLokasi!.find(where.eq('gps_1', gps1)).toList();
      final docsDeviceId = await _collectionLokasi!.find(where.eq('device_id', gps1)).toList();
      final allDocs = [...docsGps1, ...docsDeviceId];
      // Hapus duplikat berdasarkan _id
      final uniqueDocs = <String, Map<String, dynamic>>{};
      for (var doc in allDocs) {
        uniqueDocs[doc['_id'].toString()] = doc;
      }
      final allDocsUnique = uniqueDocs.values.toList();
      
      // Cari dokumen yang sudah punya metadata
      final existingDoc = allDocsUnique.firstWhere(
        (doc) => doc['model'] != null || doc['plat'] != null,
        orElse: () => <String, dynamic>{},
      );
      
      if (existingDoc.isNotEmpty) {
        // Update semua dokumen yang memiliki gps_1 atau device_id yang sama
        for (var doc in allDocsUnique) {
          final updateModifier = modify
            .set('plat', plat)
            .set('model', model)
            .set('gps_1', gps1)
            .set('device_id', gps1);
          
          if (status != null) {
            updateModifier.set('status', status);
          }
          
          await _collectionLokasi!.update(where.id(doc['_id']), updateModifier);
        }
        return true;
      } else if (allDocsUnique.isNotEmpty) {
        // Jika tidak ada dokumen metadata, update dokumen GPS location yang sudah ada
        for (var doc in allDocsUnique) {
          final updateModifier = modify
            .set('plat', plat)
            .set('model', model)
            .set('gps_1', gps1)
            .set('device_id', gps1);
          
          if (status != null) {
            updateModifier.set('status', status);
          }
          
          await _collectionLokasi!.update(where.id(doc['_id']), updateModifier);
        }
        return true;
      } else {
        // Buat dokumen baru jika belum ada sama sekali
        await _collectionLokasi!.insert({
          'plat': plat,
          'model': model,
          'gps_1': gps1,
          'device_id': gps1,
          'status': status ?? 'Tersedia',
          'peminjam': null,
          'waktu_ambil': null,
          'created_at': DateTime.now().toIso8601String()
        });
        return true;
      }
    } catch (e) {
      print("Error update kendaraan: $e");
      return false;
    }
  }

  // DELETE: Hapus metadata kendaraan (tidak menghapus data GPS location)
  static Future<bool> hapusMetadataKendaraan(String gps1) async {
    try {
      // Cari semua dokumen dengan gps_1 atau device_id yang sama
      final docsGps1 = await _collectionLokasi!.find(where.eq('gps_1', gps1)).toList();
      final docsDeviceId = await _collectionLokasi!.find(where.eq('device_id', gps1)).toList();
      final allDocs = [...docsGps1, ...docsDeviceId];
      // Hapus duplikat berdasarkan _id
      final uniqueDocs = <String, Map<String, dynamic>>{};
      for (var doc in allDocs) {
        uniqueDocs[doc['_id'].toString()] = doc;
      }
      final allDocsUnique = uniqueDocs.values.toList();
      
      // Hanya hapus dokumen yang memiliki metadata (model atau plat)
      // Jangan hapus dokumen GPS location murni
      bool deleted = false;
      for (var doc in allDocsUnique) {
        if (doc['model'] != null || doc['plat'] != null) {
          await _collectionLokasi!.remove(where.id(doc['_id']));
          deleted = true;
        }
      }
      
      return deleted;
    } catch (e) {
      print("Error hapus metadata kendaraan: $e");
      return false;
    }
  }

  // READ (ALL): Manager melihat SIAPA mengerjakan APA - dipisah menjadi yang sudah dan belum didefinisikan
  // Mengembalikan Map dengan 'defined' dan 'undefined' keys
  static Future<Map<String, List<Map<String, dynamic>>>> getSemuaDataUntukManagerDipisah() async {
    try {
      // Ambil semua data
      final allData = await _collectionLokasi!.find().toList();
      
      // Pisahkan dokumen GPS location dan metadata kendaraan
      Map<String, Map<String, dynamic>> gpsLocations = {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata = {}; // Key: gps_1/device_id, Value: metadata
      
      for (var doc in allData) {
        // Gunakan gps_1 sebagai identifier utama, fallback ke device_id
        String deviceId = doc['gps_1'] ?? doc['device_id'] ?? "Unknown";
        
        // Jika dokumen memiliki GPS location data (server_received_at atau gps_location)
        if (doc['server_received_at'] != null || doc['gps_location'] != null) {
          if (!gpsLocations.containsKey(deviceId)) {
            gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
            gpsLocations[deviceId]!['gps_1'] = deviceId;
          } else {
            // Pilih yang lebih baru berdasarkan server_received_at
            DateTime? currentTime = gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(gpsLocations[deviceId]!['server_received_at'].toString())
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;
            
            if (newTime != null && (currentTime == null || newTime.isAfter(currentTime))) {
              gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
              gpsLocations[deviceId]!['gps_1'] = deviceId;
            }
          }
        }
        
        // Jika dokumen memiliki metadata kendaraan (model atau plat)
        if (doc['model'] != null || doc['plat'] != null) {
          String metaKey = doc['gps_1'] ?? doc['device_id'] ?? deviceId;
          if (!vehicleMetadata.containsKey(metaKey)) {
            vehicleMetadata[metaKey] = Map<String, dynamic>.from(doc);
          }
        }
      }
      
      // Pisahkan menjadi yang sudah didefinisikan dan belum
      List<Map<String, dynamic>> definedVehicles = [];
      List<Map<String, dynamic>> undefinedVehicles = [];
      
      // Gunakan semua device yang ditemukan dari GPS locations
      Set<String> allDeviceIds = {};
      allDeviceIds.addAll(gpsLocations.keys);
      allDeviceIds.addAll(vehicleMetadata.keys);
      
      for (var deviceId in allDeviceIds) {
        Map<String, dynamic> vehicleData = <String, dynamic>{};
        
        // Ambil data GPS location jika ada
        if (gpsLocations.containsKey(deviceId)) {
          vehicleData.addAll(gpsLocations[deviceId]!);
        }
        
        // Gabungkan dengan metadata jika ada
        bool hasMetadata = vehicleMetadata.containsKey(deviceId);
        if (hasMetadata) {
          vehicleData['model'] = vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] = vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] = vehicleMetadata[deviceId]!['status'] ?? vehicleData['status'] ?? 'N/A';
          vehicleData['peminjam'] = vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
        }
        
        // Pastikan gps_1 selalu ada
        vehicleData['gps_1'] = deviceId;
        
        // Cek apakah sudah punya metadata (model atau plat)
        if (hasMetadata && (vehicleData['model'] != null || vehicleData['plat'] != null)) {
          definedVehicles.add(vehicleData);
        } else {
          undefinedVehicles.add(vehicleData);
        }
      }
      
      return {
        'defined': definedVehicles,
        'undefined': undefinedVehicles,
      };
    } catch (e) {
      print("Error get data manager: $e");
      return {'defined': [], 'undefined': []};
    }
  }

  // READ (ALL): Manager melihat SIAPA mengerjakan APA
  // Manager melihat semua data tanpa filter, dikelompokkan berdasarkan gps_1
  static Future<List<Map<String, dynamic>>> getSemuaDataUntukManager() async {
    try {
      // Ambil semua data
      final allData = await _collectionLokasi!.find().toList();
      
      // Pisahkan dokumen GPS location dan metadata kendaraan
      Map<String, Map<String, dynamic>> gpsLocations = {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata = {}; // Key: gps_1/device_id, Value: metadata
      
      for (var doc in allData) {
        // Gunakan gps_1 sebagai identifier utama, fallback ke device_id
        String deviceId = doc['gps_1'] ?? doc['device_id'] ?? "Unknown";
        
        // Jika dokumen memiliki GPS location data (server_received_at atau gps_location)
        if (doc['server_received_at'] != null || doc['gps_location'] != null) {
          if (!gpsLocations.containsKey(deviceId)) {
            gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
            gpsLocations[deviceId]!['gps_1'] = deviceId;
          } else {
            // Pilih yang lebih baru berdasarkan server_received_at
            DateTime? currentTime = gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(gpsLocations[deviceId]!['server_received_at'].toString())
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;
            
            if (newTime != null && (currentTime == null || newTime.isAfter(currentTime))) {
              gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
              gpsLocations[deviceId]!['gps_1'] = deviceId;
            }
          }
        }
        
        // Jika dokumen memiliki metadata kendaraan (model atau plat)
        if (doc['model'] != null || doc['plat'] != null) {
          String metaKey = doc['gps_1'] ?? doc['device_id'] ?? deviceId;
          if (!vehicleMetadata.containsKey(metaKey)) {
            vehicleMetadata[metaKey] = Map<String, dynamic>.from(doc);
          }
        }
      }
      
      // Gabungkan GPS location dengan metadata
      List<Map<String, dynamic>> result = [];
      
      // Gunakan semua device yang ditemukan dari GPS locations
      Set<String> allDeviceIds = {};
      allDeviceIds.addAll(gpsLocations.keys);
      allDeviceIds.addAll(vehicleMetadata.keys);
      
      for (var deviceId in allDeviceIds) {
        Map<String, dynamic> vehicleData = <String, dynamic>{};
        
        // Ambil data GPS location jika ada
        if (gpsLocations.containsKey(deviceId)) {
          vehicleData.addAll(gpsLocations[deviceId]!);
        }
        
        // Gabungkan dengan metadata jika ada
        if (vehicleMetadata.containsKey(deviceId)) {
          vehicleData['model'] = vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] = vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] = vehicleMetadata[deviceId]!['status'] ?? vehicleData['status'] ?? 'N/A';
          vehicleData['peminjam'] = vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
        }
        
        // Pastikan gps_1 selalu ada
        vehicleData['gps_1'] = deviceId;
        
        result.add(vehicleData);
      }
      
      return result;
    } catch (e) {
      print("Error get data manager: $e");
      return [];
    }
  }

  // READ (FLEET): Manager melihat posisi terakhir SETIAP device unik di peta
  static Future<List<Map<String, dynamic>>> getFleetDataForManager() async {
    try {
      // Ambil semua data untuk mendapatkan GPS location dan metadata
      final allData = await _collectionLokasi!.find().toList();
      
      // Pisahkan dokumen GPS location dan metadata kendaraan
      Map<String, Map<String, dynamic>> gpsLocations = {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata = {}; // Key: gps_1/device_id, Value: metadata
      
      for (var doc in allData) {
        // Gunakan gps_1 sebagai identifier utama, fallback ke device_id
        String deviceId = doc['gps_1'] ?? doc['device_id'] ?? "Unknown";
        
        // Jika dokumen memiliki GPS location data (server_received_at atau gps_location)
        if (doc['server_received_at'] != null || doc['gps_location'] != null) {
          if (!gpsLocations.containsKey(deviceId)) {
            gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
            gpsLocations[deviceId]!['gps_1'] = deviceId;
          } else {
            // Pilih yang lebih baru berdasarkan server_received_at
            DateTime? currentTime = gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(gpsLocations[deviceId]!['server_received_at'].toString())
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;
            
            if (newTime != null && (currentTime == null || newTime.isAfter(currentTime))) {
              gpsLocations[deviceId] = Map<String, dynamic>.from(doc);
              gpsLocations[deviceId]!['gps_1'] = deviceId;
            }
          }
        }
        
        // Jika dokumen memiliki metadata kendaraan (model atau plat)
        if (doc['model'] != null || doc['plat'] != null) {
          String metaKey = doc['gps_1'] ?? doc['device_id'] ?? deviceId;
          if (!vehicleMetadata.containsKey(metaKey)) {
            vehicleMetadata[metaKey] = Map<String, dynamic>.from(doc);
          }
        }
      }
      
      // Gabungkan GPS location dengan metadata
      List<Map<String, dynamic>> result = [];
      
      // Gunakan semua device yang ditemukan dari GPS locations
      for (var deviceId in gpsLocations.keys) {
        Map<String, dynamic> vehicleData = Map<String, dynamic>.from(gpsLocations[deviceId]!);
        
        // Gabungkan dengan metadata jika ada
        if (vehicleMetadata.containsKey(deviceId)) {
          vehicleData['model'] = vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] = vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] = vehicleMetadata[deviceId]!['status'] ?? vehicleData['status'] ?? 'N/A';
          vehicleData['peminjam'] = vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
        }
        
        // Pastikan gps_1 selalu ada
        vehicleData['gps_1'] = deviceId;
        
        result.add(vehicleData);
      }
      
      return result;
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
      final data = await _collectionLokasi!
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
      final data = await _collectionLokasi!
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
      await _collectionLokasi!.update(
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
      await _collectionLokasi!.update(
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
      final data = await _collectionLokasi!
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

  // =================================================================
  // BAGIAN DETAIL KENDARAAN
  // =================================================================

  // READ: Ambil detail kendaraan dari collection kendaraan berdasarkan device_id atau gps_1
  static Future<Map<String, dynamic>?> getDetailKendaraan(String deviceId) async {
    try {
      // Pastikan koneksi database terbuka
      if (_dbLokasi == null) {
        await connect();
      }
      
      // Pastikan collection sudah terinisialisasi
      if (_collectionKendaraan == null) {
        if (_dbLokasi != null) {
          _collectionKendaraan = _dbLokasi!.collection(_collectionKendaraanName);
        } else {
          print("Collection kendaraan belum ter-inisialisasi.");
          return null;
        }
      }
      
      // Jika terjadi error koneksi, reconnect dan coba lagi
      try {

        // Cari berdasarkan gps_1 atau device_id
        final docsGps1 = await _collectionKendaraan!
            .find(where.eq('gps_1', deviceId))
            .toList();
        final docsDeviceId = await _collectionKendaraan!
            .find(where.eq('device_id', deviceId))
            .toList();
        
        // Gabungkan hasil dan hapus duplikat berdasarkan _id
        final allDocs = [...docsGps1, ...docsDeviceId];
        final uniqueDocs = <String, Map<String, dynamic>>{};
        for (var doc in allDocs) {
          uniqueDocs[doc['_id'].toString()] = doc;
        }
        
        if (uniqueDocs.isNotEmpty) {
          return uniqueDocs.values.first;
        }
        return null;
      } catch (e) {
        // Jika terjadi error koneksi, reconnect dan coba sekali lagi
        if (e.toString().contains('No master connection') || 
            e.toString().contains('connection')) {
          print("⚠️ Koneksi terputus, mencoba reconnect...");
          await connect();
          _collectionKendaraan = _dbLokasi!.collection(_collectionKendaraanName);
          
          // Coba lagi setelah reconnect
          final docsGps1 = await _collectionKendaraan!
              .find(where.eq('gps_1', deviceId))
              .toList();
          final docsDeviceId = await _collectionKendaraan!
              .find(where.eq('device_id', deviceId))
              .toList();
          
          final allDocs = [...docsGps1, ...docsDeviceId];
          final uniqueDocs = <String, Map<String, dynamic>>{};
          for (var doc in allDocs) {
            uniqueDocs[doc['_id'].toString()] = doc;
          }
          
          if (uniqueDocs.isNotEmpty) {
            return uniqueDocs.values.first;
          }
          return null;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print("Error get detail kendaraan: $e");
      return null;
    }
  }

  // UPDATE: Update plat dan model kendaraan di collection kendaraan
  static Future<bool> updateKendaraanDetail(String deviceId, String plat, String model) async {
    // Normalisasi input agar plat konsisten dan spasi terpotong
    final normalizedPlat = plat.trim().toUpperCase();
    final normalizedModel = model.trim();

    // Fungsi internal untuk mencari dokumen by gps_1 atau device_id lalu update keduanya
    Future<bool> _doUpdate() async {
      // Pastikan koneksi database terbuka
      if (_dbLokasi == null) {
        await connect();
      }

      // Pastikan collection sudah terinisialisasi
      if (_collectionKendaraan == null || _collectionLokasi == null) {
        if (_dbLokasi != null) {
          _collectionKendaraan ??= _dbLokasi!.collection(_collectionKendaraanName);
          _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);
        } else {
          print("Collection kendaraan/gps_location belum ter-inisialisasi.");
          return false;
        }
      }

      // Helper untuk menggabungkan hasil query gps_1/device_id
      Future<List<Map<String, dynamic>>> _findDocs(DbCollection collection) async {
        final docsGps1 = await collection.find(where.eq('gps_1', deviceId)).toList();
        final docsDeviceId = await collection.find(where.eq('device_id', deviceId)).toList();
        final allDocs = [...docsGps1, ...docsDeviceId];
        final uniqueDocs = <String, Map<String, dynamic>>{};
        for (var doc in allDocs) {
          uniqueDocs[doc['_id'].toString()] = doc;
        }
        return uniqueDocs.values.toList();
      }

      final kendaraanDocs = await _findDocs(_collectionKendaraan!);
      final lokasiDocs = await _findDocs(_collectionLokasi!);

      bool updated = false;

      // Sinkronkan koleksi kendaraan
      for (var doc in kendaraanDocs) {
        await _collectionKendaraan!.update(
          where.id(doc['_id']),
          modify
              .set('plat', normalizedPlat)
              .set('model', normalizedModel),
        );
        updated = true;
      }

      // Sinkronkan juga koleksi gps_location agar data konsisten di semua layar
      for (var doc in lokasiDocs) {
        await _collectionLokasi!.update(
          where.id(doc['_id']),
          modify
              .set('plat', normalizedPlat)
              .set('model', normalizedModel)
              .set('gps_1', deviceId)
              .set('device_id', deviceId),
        );
        updated = true;
      }

      if (updated) {
        print("✅ Berhasil update kendaraan & gps_location: $deviceId");
      } else {
        print("❌ Dokumen kendaraan/gps_location tidak ditemukan: $deviceId");
      }

      return updated;
    }

    try {
      return await _doUpdate();
    } catch (e) {
      // Jika terjadi error koneksi, reconnect sekali lalu coba ulang
      if (e.toString().contains('No master connection') ||
          e.toString().contains('connection')) {
        print("⚠️ Koneksi terputus, mencoba reconnect...");
        await connect();
        _collectionKendaraan = _dbLokasi!.collection(_collectionKendaraanName);
        _collectionLokasi = _dbLokasi!.collection(_collectionLokasiName);
        try {
          return await _doUpdate();
        } catch (e2) {
          print("Error update detail kendaraan setelah reconnect: $e2");
          return false;
        }
      }

      print("Error update detail kendaraan: $e");
      return false;
    }
  }
}