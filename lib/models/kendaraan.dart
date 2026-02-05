// lib/models/kendaraan.dart

import 'dart:convert';

List<Kendaraan> kendaraanFromJson(String str) =>
    List<Kendaraan>.from(json.decode(str).map((x) => Kendaraan.fromJson(x)));

String kendaraanToJson(List<Kendaraan> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Kendaraan {
  final String id;
  final String plat;
  final String model;
  final String deviceId;
  final String status;
  final String? peminjam;
  final DateTime? waktuAmbil;

  Kendaraan({
    required this.id,
    required this.plat,
    required this.model,
    required this.deviceId,
    required this.status,
    this.peminjam,
    this.waktuAmbil,
  });

  factory Kendaraan.fromJson(Map<String, dynamic> json) => Kendaraan(
    id: json["_id"],
    plat: json["plat"],
    model: json["model"],
    deviceId: json["device_id"],
    status: json["status"],
    peminjam: json["peminjam"],
    waktuAmbil: json["waktu_ambil"] == null
        ? null
        : DateTime.parse(json["waktu_ambil"]),
  );

  Map<String, dynamic> toJson() => {
    "_id": id,
    "plat": plat,
    "model": model,
    "device_id": deviceId,
    "status": status,
    "peminjam": peminjam,
    "waktu_ambil": waktuAmbil?.toIso8601String(),
  };
}
