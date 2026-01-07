import 'package:mongo_dart/mongo_dart.dart';

class KegiatanSopir {
  final ObjectId id;
  final String email;
  final String judul;
  final DateTime waktu;
  final String status;

  KegiatanSopir({
    required this.id,
    required this.email,
    required this.judul,
    required this.waktu,
    required this.status,
  });

  factory KegiatanSopir.fromMap(Map<String, dynamic> map) {
    return KegiatanSopir(
      id: map['_id'],
      email: map['email'],
      judul: map['judul'],
      waktu: map['waktu'],
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'email': email,
      'judul': judul,
      'waktu': waktu,
      'status': status,
    };
  }
}
