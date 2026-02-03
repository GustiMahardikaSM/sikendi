import 'package:flutter/material.dart';

class ManagerJadwalPage extends StatelessWidget {
  const ManagerJadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Seluruh Sopir'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Tampilan Manajer untuk Jadwal',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Fitur ini sedang dalam pengembangan.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
