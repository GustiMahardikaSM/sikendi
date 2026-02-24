import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:sikendi/models/kegiatan_sopir.dart';

class MongoDBService {
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
      print(
        "✅ Berhasil Terkoneksi ke MongoDB Atlas (gps_location & kendaraan)",
      );
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
      final data = await _collectionJadwal!
          .find(where.eq('email', email))
          .toList();
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
        modify.set('judul', judul).set('waktu', waktu).set('status', status),
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
        print(
          'Collection sopir belum ter-inisialisasi. Memanggil connectJadwal()...',
        );
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

  // READ: Ambil sopir yang statusnya pending untuk verifikasi
  static Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    try {
      if (_collectionSopir == null) {
        await connectJadwal();
        if (_collectionSopir == null) {
          throw Exception("Gagal: Collection Sopir masih null (Cek Internet/Database)");
        }
      }
      final data = await _collectionSopir!
          .find(where.eq('status_akun', 'pending').sortBy('tgl_daftar'))
          .toList();
      return data;
    } catch (e) {
      print('Error getting pending drivers: $e');
      rethrow;
    }
  }

  // UPDATE: Penghubung untuk mengubah status sopir. Throws exception on failure.
  static Future<void> updateDriverStatus(ObjectId id, String status) async {
    if (status == 'aktif') {
      await approveDriver(id);
    } else if (status == 'ditolak') {
      await rejectDriver(id);
    } else {
      throw Exception("Status tidak dikenal: $status");
    }
  }

  /// Menyetujui pendaftaran sopir. Throws exception on low-level failure.
  static Future<void> approveDriver(ObjectId driverId) async {
    try {
      if (_collectionSopir == null) {
        await connectJadwal();
        if (_collectionSopir == null) {
          throw Exception("Gagal: Collection Sopir masih null (Cek Internet/Database)");
        }
      }

      // Assume success if no exception is thrown by the driver.
      // The manual result check is removed as it proved unreliable.
      await _collectionSopir!.update(
        where.id(driverId),
        modify
            .set('status_akun', 'aktif')
            .set('tgl_verifikasi', DateTime.now())
            .unset('foto_selfie_temp')
            .unset('foto_ktp_temp'),
      );
      
    } catch (e) {
      print('Error approving driver: $e');
      rethrow; // Re-throw the low-level exception to be caught by the UI
    }
  }

  /// Menolak dan menghapus permanen data pendaftar. Throws exception on low-level failure.
  static Future<void> rejectDriver(ObjectId driverId) async {
    try {
      if (_collectionSopir == null) {
        await connectJadwal();
        if (_collectionSopir == null) {
          throw Exception("Gagal: Collection Sopir masih null (Cek Internet/Database)");
        }
      }
      
      // Assume success if no exception is thrown by the driver.
      // The manual result check is removed as it proved unreliable.
      await _collectionSopir!.remove(where.id(driverId));

    } catch (e) {
      print('Error rejecting driver: $e');
      rethrow; // Re-throw the low-level exception to be caught by the UI
    }
  }

  // =================================================================
  // BAGIAN MANAJER
  // (Manager bisa melihat semua & menambah kendaraan valid)
  // =================================================================

  // Helper: Sinkronkan data ke collection kendaraan
  static Future<void> _syncToKendaraanCollection(
    Map<String, dynamic> vehicleData,
  ) async {
    try {
      if (_collectionKendaraan == null) {
        print("⚠️ Collection kendaraan belum terinisialisasi");
        return;
      }

      final deviceId = vehicleData['gps_1'] ?? vehicleData['device_id'];
      if (deviceId == null) {
        print(
          "⚠️ Device ID tidak ditemukan untuk sync ke collection kendaraan",
        );
        return;
      }

      // Cari dokumen yang sudah ada berdasarkan device_id atau gps_1
      final docsDeviceId = await _collectionKendaraan!
          .find(where.eq('device_id', deviceId))
          .toList();
      final docsGps1 = await _collectionKendaraan!
          .find(where.eq('gps_1', deviceId))
          .toList();
      final allDocs = [...docsDeviceId, ...docsGps1];
      // Hapus duplikat berdasarkan _id
      final uniqueDocs = <String, Map<String, dynamic>>{};
      for (var doc in allDocs) {
        uniqueDocs[doc['_id'].toString()] = doc;
      }
      final existingDocs = uniqueDocs.values.toList();

      // Siapkan data untuk collection kendaraan (hanya field yang relevan)
      final kendaraanData = {
        'plat': vehicleData['plat'],
        'model': vehicleData['model'],
        'device_id': deviceId,
        'gps_1': deviceId,
        'status': vehicleData['status'],
        'peminjam': vehicleData['peminjam'],
        'waktu_ambil': vehicleData['waktu_ambil'],
        'waktu_lepas': vehicleData['waktu_lepas'],
      };

      if (existingDocs.isNotEmpty) {
        // Update dokumen yang sudah ada
        for (var doc in existingDocs) {
          await _collectionKendaraan!.update(
            where.id(doc['_id']),
            modify
                .set('plat', kendaraanData['plat'])
                .set('model', kendaraanData['model'])
                .set('device_id', kendaraanData['device_id'])
                .set('gps_1', kendaraanData['gps_1'])
                .set('status', kendaraanData['status'])
                .set('peminjam', kendaraanData['peminjam'])
                .set('waktu_ambil', kendaraanData['waktu_ambil'])
                .set('waktu_lepas', kendaraanData['waktu_lepas']),
          );
        }
      } else {
        // Insert dokumen baru
        await _collectionKendaraan!.insert(kendaraanData);
      }
    } catch (e) {
      print("Error sync ke collection kendaraan: $e");
    }
  }

  // CREATE: Tambahkan metadata kendaraan ke device GPS yang sudah ada atau buat baru
  static Future<bool> tambahKendaraanManager(
    String plat,
    String model,
    String deviceId,
  ) async {
    try {
      // Cek apakah sudah ada metadata dengan gps_1 atau device_id yang sama
      // Cari dokumen yang memiliki gps_1 atau device_id yang sama DAN memiliki model atau plat
      final docsGps1 = await _collectionLokasi!
          .find(where.eq('gps_1', deviceId))
          .toList();
      final docsDeviceId = await _collectionLokasi!
          .find(where.eq('device_id', deviceId))
          .toList();
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

      Map<String, dynamic> vehicleData;
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
              .set('waktu_ambil', null)
              .set('waktu_lepas', null),
        );
        vehicleData = {
          'plat': plat,
          'model': model,
          'gps_1': deviceId,
          'device_id': deviceId,
          'status': 'Tersedia',
          'peminjam': null,
          'waktu_ambil': null,
          'waktu_lepas': null,
        };
      } else {
        // Buat dokumen baru jika belum ada sama sekali
        vehicleData = {
          'plat': plat,
          'model': model,
          'gps_1': deviceId,
          'device_id': deviceId,
          'status': 'Tersedia',
          'peminjam': null,
          'waktu_ambil': null,
          'waktu_lepas': null,
        };
        await _collectionLokasi!.insert({
          ...vehicleData,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Sync ke collection kendaraan
      await _syncToKendaraanCollection(vehicleData);
      return true;
    } catch (e) {
      print("Error tambah kendaraan: $e");
      return false;
    }
  }

  // UPDATE: Update metadata kendaraan berdasarkan gps_1
  // Update semua dokumen yang memiliki gps_1 atau device_id yang sama
  static Future<bool> updateKendaraanManager(
    String gps1,
    String plat,
    String model,
    String? status,
  ) async {
    try {
      // Query untuk semua dokumen dengan gps_1 atau device_id yang sama
      final docsGps1 = await _collectionLokasi!
          .find(where.eq('gps_1', gps1))
          .toList();
      final docsDeviceId = await _collectionLokasi!
          .find(where.eq('device_id', gps1))
          .toList();
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

      Map<String, dynamic>? vehicleDataForSync;

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

          // Simpan data untuk sync (ambil dari dokumen yang diupdate)
          if (vehicleDataForSync == null) {
            vehicleDataForSync = {
              'plat': plat,
              'model': model,
              'gps_1': gps1,
              'device_id': gps1,
              'status': status ?? doc['status'] ?? 'Tersedia',
              'peminjam': doc['peminjam'],
              'waktu_ambil': doc['waktu_ambil'],
              'waktu_lepas': doc['waktu_lepas'],
            };
          }
        }
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

          // Simpan data untuk sync (ambil dari dokumen yang diupdate)
          if (vehicleDataForSync == null) {
            vehicleDataForSync = {
              'plat': plat,
              'model': model,
              'gps_1': gps1,
              'device_id': gps1,
              'status': status ?? 'Tersedia',
              'peminjam': doc['peminjam'],
              'waktu_ambil': doc['waktu_ambil'],
              'waktu_lepas': doc['waktu_lepas'],
            };
          }
        }
      } else {
        // Buat dokumen baru jika belum ada sama sekali
        vehicleDataForSync = {
          'plat': plat,
          'model': model,
          'gps_1': gps1,
          'device_id': gps1,
          'status': status ?? 'Tersedia',
          'peminjam': null,
          'waktu_ambil': null,
          'waktu_lepas': null,
        };
        await _collectionLokasi!.insert({
          ...vehicleDataForSync,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Sync ke collection kendaraan
      if (vehicleDataForSync != null) {
        await _syncToKendaraanCollection(vehicleDataForSync);
      }
      return true;
    } catch (e) {
      print("Error update kendaraan: $e");
      return false;
    }
  }

  // DELETE: Hapus metadata kendaraan (tidak menghapus data GPS location)
  static Future<bool> hapusMetadataKendaraan(String gps1) async {
    try {
      // Cari semua dokumen dengan gps_1 atau device_id yang sama
      final docsGps1 = await _collectionLokasi!
          .find(where.eq('gps_1', gps1))
          .toList();
      final docsDeviceId = await _collectionLokasi!
          .find(where.eq('device_id', gps1))
          .toList();
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
  static Future<Map<String, List<Map<String, dynamic>>>>
  getSemuaDataUntukManagerDipisah() async {
    try {
      // Ambil semua data
      final allData = await _collectionLokasi!.find().toList();

      // Pisahkan dokumen GPS location dan metadata kendaraan
      Map<String, Map<String, dynamic>> gpsLocations =
          {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata =
          {}; // Key: gps_1/device_id, Value: metadata

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
            DateTime? currentTime =
                gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(
                    gpsLocations[deviceId]!['server_received_at'].toString(),
                  )
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;

            if (newTime != null &&
                (currentTime == null || newTime.isAfter(currentTime))) {
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
          vehicleData['model'] =
              vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] =
              vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] =
              vehicleMetadata[deviceId]!['status'] ??
              vehicleData['status'] ??
              'N/A';
          vehicleData['peminjam'] =
              vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
        }

        // Pastikan gps_1 selalu ada
        vehicleData['gps_1'] = deviceId;

        // Cek apakah sudah punya metadata (model atau plat)
        if (hasMetadata &&
            (vehicleData['model'] != null || vehicleData['plat'] != null)) {
          definedVehicles.add(vehicleData);
        } else {
          undefinedVehicles.add(vehicleData);
        }
      }

      return {'defined': definedVehicles, 'undefined': undefinedVehicles};
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
      Map<String, Map<String, dynamic>> gpsLocations =
          {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata =
          {}; // Key: gps_1/device_id, Value: metadata

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
            DateTime? currentTime =
                gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(
                    gpsLocations[deviceId]!['server_received_at'].toString(),
                  )
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;

            if (newTime != null &&
                (currentTime == null || newTime.isAfter(currentTime))) {
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
          vehicleData['model'] =
              vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] =
              vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] =
              vehicleMetadata[deviceId]!['status'] ??
              vehicleData['status'] ??
              'N/A';
          vehicleData['peminjam'] =
              vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
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
      // TAMBAHAN: Cek apakah koleksi sudah siap
      if (_collectionLokasi == null) {
        print("⚠️ Database belum terkoneksi, mencoba koneksi ulang...");
        await connect(); // Coba koneksi ulang
        if (_collectionLokasi == null)
          return []; // Jika masih gagal, kembalikan list kosong
      }

      // Ambil semua data untuk mendapatkan GPS location dan metadata
      final allData = await _collectionLokasi!.find().toList();

      // Pisahkan dokumen GPS location dan metadata kendaraan
      Map<String, Map<String, dynamic>> gpsLocations =
          {}; // Key: gps_1, Value: latest GPS data
      Map<String, Map<String, dynamic>> vehicleMetadata =
          {}; // Key: gps_1/device_id, Value: metadata

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
            DateTime? currentTime =
                gpsLocations[deviceId]!['server_received_at'] != null
                ? DateTime.tryParse(
                    gpsLocations[deviceId]!['server_received_at'].toString(),
                  )
                : null;
            DateTime? newTime = doc['server_received_at'] != null
                ? DateTime.tryParse(doc['server_received_at'].toString())
                : null;

            if (newTime != null &&
                (currentTime == null || newTime.isAfter(currentTime))) {
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
        Map<String, dynamic> vehicleData = Map<String, dynamic>.from(
          gpsLocations[deviceId]!,
        );

        // Gabungkan dengan metadata jika ada
        if (vehicleMetadata.containsKey(deviceId)) {
          vehicleData['model'] =
              vehicleMetadata[deviceId]!['model'] ?? vehicleData['model'];
          vehicleData['plat'] =
              vehicleMetadata[deviceId]!['plat'] ?? vehicleData['plat'];
          vehicleData['status'] =
              vehicleMetadata[deviceId]!['status'] ??
              vehicleData['status'] ??
              'N/A';
          vehicleData['peminjam'] =
              vehicleMetadata[deviceId]!['peminjam'] ?? vehicleData['peminjam'];
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

  /// Mengambil ringkasan data untuk Dashboard Manager
  /// Mengembalikan Map berisi: 'total', 'dipakai', 'tersedia', dan 'pending'
  static Future<Map<String, int>> getDashboardSummary() async {
    Map<String, int> summary = {
      'total': 0,
      'dipakai': 0,
      'tersedia': 0,
      'pending': 0,
    };
    try {
      // 1. Ambil data dari koleksi kendaraan
      if (_dbLokasi == null || !_dbLokasi!.isConnected || _collectionKendaraan == null) {
        await connect();
        if (_collectionKendaraan == null) {
          print("❌ Gagal mendapatkan koleksi kendaraan untuk summary.");
        }
      }
      if (_collectionKendaraan != null && _dbLokasi != null && _dbLokasi!.isConnected) {
        final total = await _collectionKendaraan!.count(where.exists('plat'));
        final dipakai = await _collectionKendaraan!.count(
          where.eq('status', 'Dipakai'),
        );
        final tersedia = await _collectionKendaraan!.count(
          where.eq('status', 'Tersedia'),
        );
        summary['total'] = total;
        summary['dipakai'] = dipakai;
        summary['tersedia'] = tersedia;
      }

      // 2. Ambil data dari koleksi sopir
      if (_dbJadwal == null || !_dbJadwal!.isConnected || _collectionSopir == null) {
        await connectJadwal();
        if (_collectionSopir == null) {
          print("❌ Gagal mendapatkan koleksi sopir untuk summary.");
        }
      }
      if (_collectionSopir != null && _dbJadwal != null && _dbJadwal!.isConnected) {
        final pending = await _collectionSopir!.count(
          where.eq('status_akun', 'pending'),
        );
        summary['pending'] = pending;
      }

      return summary;
    } catch (e) {
      print("Error mengambil summary dashboard: $e");
      // Reset koneksi jika error "No master connection" agar retry berikutnya berhasil
      if (e.toString().contains("No master connection") || e.toString().contains("Closed")) {
        _dbLokasi = null;
        _dbJadwal = null;
      }
      return summary; // Kembalikan nilai default jika ada error
    }
  }

  // =================================================================
  // BAGIAN SOPIR
  // (Sopir hanya melihat yg tersedia & pekerjaannya sendiri)
  // =================================================================

  // READ (AVAILABLE): Sopir mencari mobil untuk bekerja
  static Future<List<Map<String, dynamic>>> getKendaraanTersedia({int retryCount = 0}) async {
    try {
      if (_dbLokasi == null || !_dbLokasi!.isConnected) await connect();
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      return await _collectionLokasi!
          .find(where.eq('status', 'Tersedia'))
          .toList();
    } catch (e) {
      print("Error get tersedia: $e");
      // Auto-Retry Maksimal 2 Kali jika koneksi bertabrakan
      if (retryCount < 2 && (e.toString().contains("No master connection") || e.toString().contains("Closed"))) {
        _dbLokasi = null; // Reset koneksi
        await Future.delayed(const Duration(milliseconds: 300)); // Beri jeda 0.3 detik agar db bernapas
        return await getKendaraanTersedia(retryCount: retryCount + 1);
      }
      return [];
    }
  }

  // READ (MY JOB): Sopir melihat pekerjaan dia sendiri
  static Future<Map<String, dynamic>?> getPekerjaanBySopir(String namaSopir) async {
    try {
      final pekerjaanList = await getPekerjaanSaya(namaSopir);
      if (pekerjaanList.isNotEmpty) {
        return pekerjaanList.first;
      }
      return null;
    } catch (e) {
      print("Error getPekerjaanBySopir: $e");
      return null;
    }
  }

  // READ (MY JOB): Sopir melihat pekerjaan dia sendiri
  static Future<List<Map<String, dynamic>>> getPekerjaanSaya(String namaSopir, {int retryCount = 0}) async {
    try {
      if (_dbLokasi == null || !_dbLokasi!.isConnected) await connect();
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      return await _collectionLokasi!
          .find(where.eq('peminjam', namaSopir)) 
          .toList();
    } catch (e) {
      print("Error get pekerjaan saya: $e");
      if (retryCount < 2 && (e.toString().contains("No master connection") || e.toString().contains("Closed"))) {
        _dbLokasi = null;
        await Future.delayed(const Duration(milliseconds: 300));
        return await getPekerjaanSaya(namaSopir, retryCount: retryCount + 1);
      }
      return [];
    }
  }

  // UPDATE (CHECK-IN): Sopir mengambil mobil
  static Future<void> ambilKendaraan(ObjectId id, String namaSopir, {int retryCount = 0}) async {
    try {
      if (_dbLokasi == null || !_dbLokasi!.isConnected) await connect();
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      final doc = await _collectionLokasi!.findOne(where.id(id));
      if (doc == null) return;

      final waktuAmbil = DateTime.now().toIso8601String();

      await _collectionLokasi!.update(
        where.id(id),
        modify
            .set('status', 'Dipakai') 
            .set('peminjam', namaSopir) 
            .set('waktu_ambil', waktuAmbil) 
            .set('waktu_lepas', null), 
      );

      final vehicleData = {
        'plat': doc['plat'],
        'model': doc['model'],
        'gps_1': doc['gps_1'] ?? doc['device_id'],
        'device_id': doc['device_id'] ?? doc['gps_1'],
        'status': 'Dipakai',
        'peminjam': namaSopir,
        'waktu_ambil': waktuAmbil,
        'waktu_lepas': null,
      };
      await _syncToKendaraanCollection(vehicleData);

    } catch (e) {
      print("Error ambil kendaraan: $e");
      if (retryCount < 2 && (e.toString().contains("No master connection") || e.toString().contains("Closed"))) {
        _dbLokasi = null;
        await Future.delayed(const Duration(milliseconds: 300));
        await ambilKendaraan(id, namaSopir, retryCount: retryCount + 1);
      }
    }
  }

  // UPDATE (CHECK-OUT): Sopir mengembalikan mobil (Selesai tugas)
  static Future<void> selesaikanPekerjaan(ObjectId id, {int retryCount = 0}) async {
    try {
      if (_dbLokasi == null || !_dbLokasi!.isConnected) await connect();
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      final doc = await _collectionLokasi!.findOne(where.id(id));
      if (doc == null) return;

      final waktuLepas = DateTime.now().toIso8601String();

      await _collectionLokasi!.update(
        where.id(id),
        modify
            .set('status', 'Tersedia')
            .set('peminjam', null)
            .set('waktu_ambil', null)
            .set('waktu_lepas', waktuLepas), 
      );

      final vehicleData = {
        'plat': doc['plat'],
        'model': doc['model'],
        'gps_1': doc['gps_1'] ?? doc['device_id'],
        'device_id': doc['device_id'] ?? doc['gps_1'],
        'status': 'Tersedia',
        'peminjam': null,
        'waktu_ambil': null,
        'waktu_lepas': waktuLepas,
      };
      await _syncToKendaraanCollection(vehicleData);

    } catch (e) {
      print("Error selesai pekerjaan: $e");
      if (retryCount < 2 && (e.toString().contains("No master connection") || e.toString().contains("Closed"))) {
        _dbLokasi = null;
        await Future.delayed(const Duration(milliseconds: 300));
        await selesaikanPekerjaan(id, retryCount: retryCount + 1);
      }
    }
  }

  // =================================================================
  // BAGIAN TRACKING
  // =================================================================

  // =================================================================
  // BAGIAN TRACKING (DIPERBAIKI)
  // =================================================================

  // Mengambil 1 data GPS paling baru dari collection dengan Auto-Reconnect
  static Future<Map<String, dynamic>?> getLatestGpsData() async {
    try {
      // 1. CEK KONEKSI: Jika db belum ada atau statusnya tidak connected
      if (_dbLokasi == null || !_dbLokasi!.isConnected) {
        print("⚠️ Koneksi GPS terputus/belum siap. Mencoba connect ulang...");
        await connect();

        // Jika setelah dicoba connect masih gagal, return null agar tidak crash
        if (_dbLokasi == null || !_dbLokasi!.isConnected) {
          print("❌ Gagal reconnect di getLatestGpsData.");
          return null;
        }
      }

      // 2. Pastikan collection sudah terdefinisi
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      // 3. Eksekusi Query
      final data = await _collectionLokasi!
          .find(where.sortBy('server_received_at', descending: true).limit(1))
          .toList();

      if (data.isNotEmpty) {
        return data.first;
      }
      return null;
    } catch (e) {
      print("Error get latest GPS data: $e");

      // DETEKSI KHUSUS: Jika errornya "No master connection", paksa reset koneksi untuk request berikutnya
      if (e.toString().contains("No master connection") ||
          e.toString().contains("Closed")) {
        print("♻️ Mendeteksi broken pipe, mereset koneksi database...");
        _dbLokasi =
            null; // Set null agar connect() dipanggil ulang di request berikutnya
      }
      return null;
    }
  }

  // =================================================================
  // BAGIAN DETAIL KENDARAAN
  // =================================================================

  // READ: Ambil detail kendaraan dengan MERGE (Gabungan Data Identitas & Lokasi Terbaru)
  static Future<Map<String, dynamic>?> getDetailKendaraan(
    String deviceId,
  ) async {
    try {
      // 1. Pastikan koneksi siap
      if (_dbLokasi == null) await connect();
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);
      _collectionKendaraan ??= _dbLokasi!.collection(_collectionKendaraanName);

      // A. Ambil DATA IDENTITAS (Plat, Model) dari collection 'kendaraan'
      Map<String, dynamic>? identityData;
      // Coba cari by device_id
      var doc = await _collectionKendaraan!.findOne(
        where.eq('device_id', deviceId),
      );
      if (doc == null) {
        // Coba cari by gps_1
        doc = await _collectionKendaraan!.findOne(where.eq('gps_1', deviceId));
      }
      identityData = doc;

      // B. Ambil DATA LOKASI REAL-TIME dari 'gps_location'
      //    (Ambil 1 data paling baru berdasarkan waktu server)
      Map<String, dynamic>? realtimeData;

      // Query sort descending agar dapat yang terbaru
      final q1 = await _collectionLokasi!
          .find(
            where
                .eq('gps_1', deviceId)
                .sortBy('server_received_at', descending: true)
                .limit(1),
          )
          .toList();

      if (q1.isNotEmpty) {
        realtimeData = q1.first;
      } else {
        final q2 = await _collectionLokasi!
            .find(
              where
                  .eq('device_id', deviceId)
                  .sortBy('server_received_at', descending: true)
                  .limit(1),
            )
            .toList();
        if (q2.isNotEmpty) realtimeData = q2.first;
      }

      // C. PROSES MERGE (PENGGABUNGAN)
      if (identityData == null && realtimeData == null) return null;

      final result = <String, dynamic>{};

      // Masukkan identitas dulu
      if (identityData != null) result.addAll(identityData);

      // Timpa dengan data lokasi terbaru
      if (realtimeData != null) {
        // Ambil koordinat dengan aman
        if (realtimeData['gps_location'] != null) {
          result['gps_location'] = realtimeData['gps_location'];
        }
        // Ambil field lain yang live
        result['speed'] = realtimeData['speed'];
        result['server_received_at'] = realtimeData['server_received_at'];

        // Pastikan ID terbawa
        result['gps_1'] ??= realtimeData['gps_1'];
        result['device_id'] ??= realtimeData['device_id'];
      }

      // Default value agar UI tidak null
      result['plat'] ??= '-';
      result['model'] ??= '-';
      result['status'] ??= 'Tersedia';
      result['device_id'] ??= deviceId;

      return result;
    } catch (e) {
      print("Error get detail merge: $e");
      return null;
    }
  }

  // UPDATE: Update plat dan model kendaraan di collection kendaraan
  static Future<bool> updateKendaraanDetail(
    String deviceId,
    String plat,
    String model,
  ) async {
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
          _collectionKendaraan ??= _dbLokasi!.collection(
            _collectionKendaraanName,
          );
          _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);
        } else {
          print("Collection kendaraan/gps_location belum ter-inisialisasi.");
          return false;
        }
      }

      // Helper untuk menggabungkan hasil query gps_1/device_id
      Future<List<Map<String, dynamic>>> _findDocs(
        DbCollection collection,
      ) async {
        final docsGps1 = await collection
            .find(where.eq('gps_1', deviceId))
            .toList();
        final docsDeviceId = await collection
            .find(where.eq('device_id', deviceId))
            .toList();
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
          modify.set('plat', normalizedPlat).set('model', normalizedModel),
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

  // UPDATE: Simpan Foto Kendaraan (Base64 atau URL)
  static Future<bool> updateFotoKendaraan(
    String deviceId,
    String fotoData,
  ) async {
    Future<bool> _doUpdate() async {
      if (_dbLokasi == null) await connect();

      _collectionKendaraan ??= _dbLokasi!.collection(_collectionKendaraanName);
      _collectionLokasi ??= _dbLokasi!.collection(_collectionLokasiName);

      // Cari ID dokumen berdasarkan gps_1 atau device_id
      final docsGps1 = await _collectionKendaraan!
          .find(where.eq('gps_1', deviceId))
          .toList();
      final docsDeviceId = await _collectionKendaraan!
          .find(where.eq('device_id', deviceId))
          .toList();

      final allDocs = [...docsGps1, ...docsDeviceId];
      // Ambil ID unik saja
      final uniqueIds = <String>{};
      for (var doc in allDocs) {
        uniqueIds.add(doc['_id'].toString());
      }

      bool updated = false;

      // Update di collection 'kendaraan'
      for (var idStr in uniqueIds) {
        final id = allDocs.firstWhere(
          (doc) => doc['_id'].toString() == idStr,
        )['_id'];
        await _collectionKendaraan!.update(
          where.id(id),
          modify.set('foto_url', fotoData), // Simpan data foto
        );

        // Update juga di collection 'gps_location' agar sinkron
        final lokasiDocsGps1 = await _collectionLokasi!
            .find(where.eq('gps_1', deviceId))
            .toList();
        final lokasiDocsDeviceId = await _collectionLokasi!
            .find(where.eq('device_id', deviceId))
            .toList();
        final allLokasiDocs = [...lokasiDocsGps1, ...lokasiDocsDeviceId];
        final uniqueLokasiIds = <String>{};
        for (var doc in allLokasiDocs) {
          uniqueLokasiIds.add(doc['_id'].toString());
        }

        for (var lokasiIdStr in uniqueLokasiIds) {
          final lokasiId = allLokasiDocs.firstWhere(
            (doc) => doc['_id'].toString() == lokasiIdStr,
          )['_id'];
          await _collectionLokasi!.update(
            where.id(lokasiId),
            modify.set('foto_url', fotoData),
          );
        }
        updated = true;
      }

      // Fallback: Jika tidak ada di 'kendaraan', update langsung di 'gps_location'
      if (!updated) {
        final locDocsGps1 = await _collectionLokasi!
            .find(where.eq('gps_1', deviceId))
            .toList();
        final locDocsDeviceId = await _collectionLokasi!
            .find(where.eq('device_id', deviceId))
            .toList();
        final allLocDocs = [...locDocsGps1, ...locDocsDeviceId];
        final uniqueLocIds = <String>{};
        for (var doc in allLocDocs) {
          uniqueLocIds.add(doc['_id'].toString());
        }

        for (var locIdStr in uniqueLocIds) {
          final locId = allLocDocs.firstWhere(
            (doc) => doc['_id'].toString() == locIdStr,
          )['_id'];
          await _collectionLokasi!.update(
            where.id(locId),
            modify.set('foto_url', fotoData),
          );
          updated = true;
        }
      }

      return updated;
    }

    try {
      return await _doUpdate();
    } catch (e) {
      print("Error update foto: $e");
      // Reconnect jika putus
      if (e.toString().contains('connection') ||
          e.toString().contains('No master connection')) {
        await connect();
        _collectionKendaraan = _dbLokasi!.collection(_collectionKendaraanName);
        _collectionLokasi = _dbLokasi!.collection(_collectionLokasiName);
        return await _doUpdate();
      }
      return false;
    }
  }

  // ==========================================================
  // FUNGSI UNTUK PROFIL SOPIR
  // ==========================================================
  
  /// Memperbarui atau menambahkan field 'foto_profil' pada dokumen sopir
  static Future<bool> updateFotoProfilSopir(String email, String base64Image) async {
    try {
      if (_collectionSopir == null) {
        await connectJadwal();
        if (_collectionSopir == null) {
          throw Exception("Gagal: Collection Sopir masih null (Cek Internet/Database)");
        }
      }
      
      // Mencari sopir berdasarkan email dan mengupdate field 'foto_profil'
      var result = await _collectionSopir!.updateOne(
        where.eq('email', email),
        modify.set('foto_profil', base64Image),
      );
      
      // Mengembalikan true jika berhasil diubah
      return result.isAcknowledged;
    } catch (e) {
      print("Error saat update foto profil: $e");
      return false;
    }
  }
}
