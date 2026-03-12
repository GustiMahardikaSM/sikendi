import 'package:flutter/material.dart';

class ManagerPeringatanPage extends StatelessWidget {
  const ManagerPeringatanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peringatan & Notifikasi'),
        backgroundColor: Colors.blue[900], // Selaraskan warna AppBar
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100], // Selaraskan warna background
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32.0),
          margin: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_rounded, // Icon yang lebih relevan
                size: 64,
                color: Colors.blueAccent,
              ),
              SizedBox(height: 24),
              Text(
                'Pusat Peringatan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Fitur untuk menampilkan notifikasi dan peringatan penting sedang dalam tahap pengembangan.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5, // Jarak antar baris
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
