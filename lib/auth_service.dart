import 'dart:convert'; // Untuk UTF8 encoding
import 'package:crypto/crypto.dart'; // Untuk Hashing SHA-256
import 'package:mongo_dart/mongo_dart.dart';

class AuthService {
  // Ganti URL ini. Perhatikan bagian '/demo_akun' di akhir URL
  static const String _mongoUrl =
      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/demo_akun?retryWrites=true&w=majority";
  
  static const String _collection = "sopir";

  // Fungsi Helper: Mengubah Password Biasa menjadi Hash (SHA-256)
  static String hashPassword(String password) {
    var bytes = utf8.encode(password); // Ubah ke bytes
    var digest = sha256.convert(bytes); // Hash menggunakan SHA-256
    return digest.toString();
  }

  // 1. FUNGSI LOGIN
  static Future<Map<String, dynamic>?> loginSopir(String email, String password) async {
    Db? db;
    try {
      db = await Db.create(_mongoUrl);
      await db.open();
      
      var collection = db.collection(_collection);

      // Cari user berdasarkan email
      var user = await collection.findOne(where.eq('email', email));

      if (user == null) {
        print("AuthService: User not found");
        return null; // User tidak ditemukan
      }

      // Cek Password: Bandingkan Hash database dengan Hash inputan user
      String inputHash = hashPassword(password);
      
      if (user['password'] == inputHash) {
        print("AuthService: Login successful for ${user['email']}");
        return user; // Login Sukses, kembalikan data user
      } else {
        print("AuthService: Incorrect password for ${user['email']}");
        return null; // Password salah
      }

    } catch (e) {
      print("Error Login: $e");
      return null;
    } finally {
      await db?.close(); // Tutup koneksi
    }
  }

  // 2. FUNGSI SIGN UP (DAFTAR)
  static Future<String> signUpSopir(String email, String password, String nama, String noHp) async {
    Db? db;
    try {
      db = await Db.create(_mongoUrl);
      await db.open();
      
      var collection = db.collection(_collection);

      // Cek apakah email sudah ada?
      var existingUser = await collection.findOne(where.eq('email', email));
      if (existingUser != null) {
        return "Email sudah dipakai. Silakan pilih yang lain.";
      }

      // Simpan data baru dengan Password yang di-Hash
      await collection.insert({
        'email': email,
        'password': hashPassword(password), // PENTING: Password dienkripsi
        'nama_lengkap': nama,
        'no_hp': noHp,
        'created_at': DateTime.now().toIso8601String(),
        'role': 'Sopir'
      });

      return "Sukses";

    } catch (e) {
      return "Error: $e";
    } finally {
      await db?.close();
    }
  }
}