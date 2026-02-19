import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

class AuthService {
  static const String _mongoUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/demo_akun?retryWrites=true&w=majority";

  static const String _collection = "sopir";

  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 1. Fungsi "Pembuat Jejak Digital" (Hashing)
  /// Menggabungkan string base64 dari selfie dan KTP, lalu membuat hash SHA-256.
  static String _createImageHash(String base64Selfie, String base64Ktp) {
    var combinedImageString = base64Selfie + base64Ktp;
    var imageBytes = utf8.encode(combinedImageString);
    var imageHash = sha256.convert(imageBytes).toString();
    return imageHash;
  }

  /// 3. Update Fungsi login (Pengecekan Status)
  static Future<Map<String, dynamic>?> loginSopir(
    String email,
    String password,
  ) async {
    Db? db;
    try {
      db = await Db.create(_mongoUrl);
      await db.open();

      var collection = db.collection(_collection);
      var user = await collection.findOne(where.eq('email', email));

      if (user == null) {
        print("AuthService: User not found for email $email");
        return {
          'error': 'credentials',
          'message': 'Email atau password salah.',
        };
      }

      String inputHash = hashPassword(password);
      if (user['password'] != inputHash) {
        print("AuthService: Incorrect password for ${user['email']}");
        return {
          'error': 'credentials',
          'message': 'Email atau password salah.',
        };
      }

      // --- Alur Logika Baru: Cek Status Akun ---
      final status = user['status_akun'];
      print("AuthService: Account status for ${user['email']} is '$status'.");

      switch (status) {
        case 'aktif':
          // Kondisi C (Aktif): Izinkan masuk
          print("AuthService: Login successful for ${user['email']}");
          return user;
        case 'pending':
          // Kondisi A (Pending): Jangan izinkan masuk
          return {
            'error': 'pending',
            'message': 'Akun Anda sedang dalam proses verifikasi Manajer.',
          };
        case 'ditolak':
          // Kondisi B (Ditolak): Jangan izinkan masuk
          return {
            'error': 'ditolak',
            'message': 'Mohon maaf, pendaftaran Anda ditolak karena data tidak sesuai.',
          };
        default:
          // Fallback untuk sopir lama yang mungkin belum punya status
          if (status == null && user['role'] == 'sopir') {
             print("AuthService: Login successful for old user ${user['email']} with null status.");
             return user;
          }
           return {
            'error': 'unknown',
            'message': 'Status akun tidak diketahui. Hubungi administrator.',
          };
      }
    } catch (e) {
      print("Error Login: $e");
      return {'error': 'exception', 'message': 'Terjadi kesalahan: $e'};
    } finally {
      await db?.close();
    }
  }

  /// 2. Update Fungsi signUp (Pendaftaran)
  static Future<String> signUpSopir({
    required String email,
    required String password,
    required String nama,
    required String noHp,
    required String fotoSelfieBase64,
    required String fotoKtpBase64,
  }) async {
    Db? db;
    try {
      db = await Db.create(_mongoUrl);
      await db.open();
      var collection = db.collection(_collection);

      // Cek Duplikat Email
      var existingUser = await collection.findOne(where.eq('email', email));
      if (existingUser != null) {
        return "Email sudah dipakai. Silakan pilih yang lain.";
      }
      
      // Generate Hash Jejak Digital
      final String jejakHash = _createImageHash(fotoSelfieBase64, fotoKtpBase64);
      
      // Susun Dokumen Database
      await collection.insert({
        'nama': nama,
        'email': email,
        'password': hashPassword(password),
        'no_hp': noHp,
        'role': 'sopir',

        // --- KOLOM BARU SESUAI PERMINTAAN ---
        'status_akun': 'pending', // Default status
        'tgl_daftar': DateTime.now().toIso8601String(),

        // Data Privasi (Sementara)
        'foto_selfie_temp': fotoSelfieBase64,
        'foto_ktp_temp': fotoKtpBase64,

        // Data Jejak (Permanen)
        'foto_hash_jejak': jejakHash,
      });

      return "Sukses";
    } catch (e) {
      print("Error during signUpSopir: $e");
      return "Error: $e";
    } finally {
      await db?.close();
    }
  }

  /// 4. Fungsi untuk Memperbarui Profil Sopir
  static Future<String> updateProfilSopir({
    required String email, // Digunakan sebagai acuan/pencarian data mana yang diubah
    required String namaBaru,
    required String noHpBaru,
    String? passwordBaru, // Opsional: hanya diisi jika user ingin ganti password
    String? fotoProfilBase64, // Opsional: hanya diisi jika user upload foto baru
  }) async {
    Db? db;
    try {
      // Membuka koneksi ke database
      db = await Db.create(_mongoUrl);
      await db.open();
      var collection = db.collection(_collection);

      // Pastikan akun dengan email tersebut ada
      var user = await collection.findOne(where.eq('email', email));
      if (user == null) {
        return "Gagal: Akun tidak ditemukan.";
      }

      // Siapkan data dasar yang pasti akan diupdate (Nama dan No HP)
      var updateModifier = modify
          .set('nama', namaBaru)
          .set('no_hp', noHpBaru);

      // Jika ada input password baru, hash password tersebut lalu tambahkan ke updateModifier
      if (passwordBaru != null && passwordBaru.isNotEmpty) {
        updateModifier.set('password', hashPassword(passwordBaru));
      }

      // Jika ada foto profil baru, tambahkan ke updateModifier
      if (fotoProfilBase64 != null && fotoProfilBase64.isNotEmpty) {
        updateModifier.set('foto_profil', fotoProfilBase64);
      }

      // Eksekusi update ke MongoDB berdasarkan email
      await collection.update(where.eq('email', email), updateModifier);

      return "Sukses";
    } catch (e) {
      print("Error during updateProfilSopir: $e");
      return "Error: $e";
    } finally {
      // Pastikan koneksi database ditutup kembali
      await db?.close();
    }
  }
}
