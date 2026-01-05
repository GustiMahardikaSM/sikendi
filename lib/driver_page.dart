import 'dart:async'; // Untuk mengatur waktu update otomatis (Timer)
import 'package:flutter/material.dart'; // Komponen UI (Tombol, Teks, Layout)
import 'package:flutter_map/flutter_map.dart'; // Peta
import 'package:latlong2/latlong.dart'; // Koordinat
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Database MongoDB

// ==========================================================
// KELAS UTAMA HALAMAN SOPIR
// ==========================================================
class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {

  // Variabel untuk mengatur Tab (Menu Bawah)

  int _selectedIndex = 0; 



  // Daftar Halaman yang akan ditampilkan sesuai Tab yang dipilih

  static final List<Widget> _pages = <Widget>[

    const DriverTrackingTab(),   // Halaman 0: Peta & Safety

    const DriverVehicleTab(),    // Halaman 1: Manajemen Tanggung Jawab

    const DriverScheduleTab(),   // Halaman 2: Jadwal Tugas

  ];



  // Fungsi saat tombol navigasi bawah ditekan

  void _onItemTapped(int index) {

    setState(() {

      _selectedIndex = index;

    });

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      // AppBar bagian atas

      appBar: AppBar(

        title: const Text("Dashboard Sopir SiKenDi"),

        backgroundColor: Colors.green[700], // Warna Hijau khas Sopir

        foregroundColor: Colors.white,

      ),

      

      // Menggunakan IndexedStack untuk menjaga state setiap tab

      body: IndexedStack(

        index: _selectedIndex,

        children: _pages,

      ),



      // Navigasi Bawah (Bottom Navigation Bar)

      bottomNavigationBar: BottomNavigationBar(

        items: const <BottomNavigationBarItem>[

          BottomNavigationBarItem(

            icon: Icon(Icons.map),

            label: 'Tracking',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.directions_car),

            label: 'Kendaraan',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.calendar_today),

            label: 'Jadwal',

          ),

        ],

        currentIndex: _selectedIndex,

        selectedItemColor: Colors.green[800],

        onTap: _onItemTapped,

      ),

    );

  }

}



// ==========================================================

// TAB 1: TRACKING & NOTIFIKASI SAFETY (OVERSPEED)

// ==========================================================

class DriverTrackingTab extends StatefulWidget {

  const DriverTrackingTab({super.key});



  @override

  State<DriverTrackingTab> createState() => _DriverTrackingTabState();

}



class _DriverTrackingTabState extends State<DriverTrackingTab> with AutomaticKeepAliveClientMixin {

  // --- KONFIGURASI DB ---

  final String _mongoUrl =

      "mongodb+srv://listaen:projekta1@cobamongo.4fwbqvt.mongodb.net/gps_1?retryWrites=true&w=majority";

  final String _collectionName = "gps_location";



  mongo.Db? _db;

  LatLng? _currentPosition;

  double _currentSpeed = 0.0;

  Timer? _timer;

  

  // Batas Kecepatan untuk Notifikasi (Contoh: 60 km/jam)

  final double _speedLimit = 60.0; 

  bool _isOverspeeding = false; // Status apakah sedang ngebut



  @override

  void initState() {

    super.initState();

    _connectToMongo();

    // Update data setiap 2 detik

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {

      _fetchData();

    });

  }



  @override

  void dispose() {

    _timer?.cancel();

    _db?.close();

    super.dispose();

  }



  Future<void> _connectToMongo() async {

    try {

      _db = await mongo.Db.create(_mongoUrl);

      await _db!.open();

      _fetchData();

    } catch (e) {

      debugPrint("Error DB: $e");

    }

  }



  Future<void> _fetchData() async {

    if (_db == null || !_db!.isConnected) return;

    try {

      var collection = _db!.collection(_collectionName);

      // Ambil 1 data terbaru saja untuk efisiensi

      final data = await collection

          .find(mongo.where.sortBy('server_received_at', descending: true).limit(1))

          .toList();



      if (data.isNotEmpty) {

        var doc = data.first;

        if (doc['gps_location'] != null) {

          double lat = (doc['gps_location']['lat'] as num).toDouble();

          double lng = (doc['gps_location']['lng'] as num).toDouble();

          double speed = (doc['speed'] as num? ?? 0).toDouble();



          if (mounted) {

            setState(() {

              _currentPosition = LatLng(lat, lng);

              _currentSpeed = speed;



              // --- LOGIKA NOTIFIKASI OVERSPEED ---

              if (_currentSpeed > _speedLimit) {

                if (!_isOverspeeding) {

                  _isOverspeeding = true;

                  // Tampilkan SnackBar (Pesan Pop-up bawah) jika ngebut

                  ScaffoldMessenger.of(context).showSnackBar(

                    SnackBar(

                      backgroundColor: Colors.red,

                      duration: const Duration(seconds: 1),

                      content: Row(

                        children: const [

                          Icon(Icons.warning, color: Colors.white),

                          SizedBox(width: 10),

                          Text("BAHAYA! Anda melewati batas kecepatan!", style: TextStyle(fontWeight: FontWeight.bold)),

                        ],

                      ),

                    ),

                  );

                }

              } else {

                _isOverspeeding = false;

              }

            });

          }

        }

      }

    } catch (e) {

      debugPrint("Error Fetch: $e");

    }

  }



  @override

  Widget build(BuildContext context) {

    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Stack(

      children: [

        // 1. PETA

        _currentPosition == null

            ? const Center(child: CircularProgressIndicator())

            : FlutterMap(

                options: MapOptions(

                  initialCenter: _currentPosition!,

                  initialZoom: 16.0,

                ),

                children: [

                  TileLayer(

                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                    userAgentPackageName: 'com.sikendi.driver',

                  ),

                  MarkerLayer(

                    markers: [

                      Marker(

                        point: _currentPosition!,

                        width: 80,

                        height: 80,

                        child: const Icon(Icons.directions_car, color: Colors.green, size: 40),

                      ),

                    ],

                  ),

                ],

              ),

        

        // 2. PANEL INDIKATOR KECEPATAN (Overlay di atas peta)

        Positioned(

          top: 20,

          right: 20,

          child: Container(

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(

              // Jika ngebut warna Merah, jika aman warna Putih

              color: _isOverspeeding ? Colors.red : Colors.white, 

              borderRadius: BorderRadius.circular(10),

              boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],

            ),

            child: Column(

              children: [

                const Text("Kecepatan", style: TextStyle(fontSize: 12)),

                Text(

                  "${_currentSpeed.toStringAsFixed(1)} km/h",

                  style: TextStyle(

                    fontSize: 24, 

                    fontWeight: FontWeight.bold,

                    // Ubah warna teks jadi putih jika background merah

                    color: _isOverspeeding ? Colors.white : Colors.black,

                  ),

                ),

              ],

            ),

          ),

        ),

      ],

    );

  }



  @override

  bool get wantKeepAlive => true;

}



// ==========================================================

// TAB 2: MANAJEMEN TANGGUNG JAWAB KENDARAAN

// ==========================================================

class DriverVehicleTab extends StatefulWidget {

  const DriverVehicleTab({super.key});



  @override

  State<DriverVehicleTab> createState() => _DriverVehicleTabState();

}



class _DriverVehicleTabState extends State<DriverVehicleTab> with AutomaticKeepAliveClientMixin {

  // Simulasi Data Kendaraan Dinas Undip

  final List<Map<String, String>> _availableCars = [

    {"plat": "H 1234 XY", "model": "Toyota Avanza", "status": "Tersedia"},

    {"plat": "H 5678 AB", "model": "Toyota Innova", "status": "Tersedia"},

    {"plat": "H 9999 CD", "model": "Mitsubishi Pajero", "status": "Dipakai"},

  ];



  // Variabel untuk menyimpan mobil yang sedang dipilih (Check-in)

  Map<String, String>? _selectedCar; 



  @override

  Widget build(BuildContext context) {

    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Padding(

      padding: const EdgeInsets.all(16.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text("Status Tanggung Jawab", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),



          // --- LOGIKA TAMPILAN KARTU TANGGUNG JAWAB ---

          // Jika belum ada mobil dipilih -> Tampilkan pesan "Belum ada"

          if (_selectedCar == null) 

            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.grey[200],

                borderRadius: BorderRadius.circular(10),

              ),

              child: Column(

                children: const [

                  Icon(Icons.no_crash, size: 50, color: Colors.grey),

                  Text("Anda belum memilih kendaraan."),

                  Text("Silakan pilih kendaraan di bawah untuk Check-in."),

                ],

              ),

            )

          // Jika SUDAH ada mobil dipilih -> Tampilkan KARTU TANGGUNG JAWAB

          else 

            Card(

              elevation: 4,

              color: Colors.blue[50],

              child: Padding(

                padding: const EdgeInsets.all(16.0),

                child: Column(

                  children: [

                    const Text("KENDARAAN AKTIF", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),

                    const Divider(),

                    ListTile(

                      leading: const Icon(Icons.directions_car, size: 40, color: Colors.blue),

                      title: Text(_selectedCar!['model']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

                      subtitle: Text(_selectedCar!['plat']!),

                    ),

                    const SizedBox(height: 10),

                    // TOMBOL CHECK-OUT (Hapus Tanggung Jawab)

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton.icon(

                        icon: const Icon(Icons.exit_to_app),

                        label: const Text("LEPAS TANGGUNG JAWAB (Check-out)"),

                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

                        onPressed: () {

                          setState(() {

                            _selectedCar = null; // Kosongkan variabel

                          });

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text("Berhasil Check-out kendaraan.")),

                          );

                        },

                      ),

                    )

                  ],

                ),

              ),

            ),



          const SizedBox(height: 20),

          const Text("Daftar Kendaraan Tersedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),



          // --- LIST KENDARAAN UNTUK DIPILIH (CHECK-IN) ---

          Expanded(

            child: ListView.builder(

              itemCount: _availableCars.length,

              itemBuilder: (context, index) {

                var car = _availableCars[index];

                bool isAvailable = car['status'] == "Tersedia";



                return Card(

                  child: ListTile(

                    leading: Icon(Icons.car_rental, color: isAvailable ? Colors.green : Colors.grey),

                    title: Text(car['model']!),

                    subtitle: Text("${car['plat']} • ${car['status']}"),

                    // Tombol Check-in hanya aktif jika mobil tersedia & sopir belum punya mobil

                    trailing: ElevatedButton(

                      onPressed: (isAvailable && _selectedCar == null) 

                          ? () {

                              setState(() {

                                _selectedCar = car; // Simpan mobil ke variabel

                              });

                              ScaffoldMessenger.of(context).showSnackBar(

                                SnackBar(content: Text("Berhasil Check-in: ${car['model']}")),

                              );

                            } 

                          : null, // Matikan tombol jika tidak tersedia

                      child: const Text("Pilih"),

                    ),

                  ),

                );

              },

            ),

          ),

        ],

      ),

    );

  }



  @override

  bool get wantKeepAlive => true;

}



// ==========================================================

// TAB 3: INFORMASI JADWAL PENUGASAN

// ==========================================================

class DriverScheduleTab extends StatefulWidget {

  const DriverScheduleTab({super.key});



  @override

  State<DriverScheduleTab> createState() => _DriverScheduleTabState();

}



class _DriverScheduleTabState extends State<DriverScheduleTab> with AutomaticKeepAliveClientMixin {

  // Simulasi Data Jadwal dari SOP (Gambar 4 Proposal)

  final List<Map<String, String>> _schedules = [

    {

      "tanggal": "29 Des 2025",

      "waktu": "08:00 WIB",

      "tugas": "Antar Wakil Rektor II ke Rektorat",

      "status": "Selesai"

    },

    {

      "tanggal": "30 Des 2025",

      "waktu": "09:30 WIB",

      "tugas": "Jemput Tamu Fakultas Teknik di Bandara",

      "status": "Akan Datang"

    },

    {

      "tanggal": "31 Des 2025",

      "waktu": "13:00 WIB",

      "tugas": "Operasional Logistik KBAUK",

      "status": "Menunggu Persetujuan"

    },

  ];



  void _addSchedule() {

    // Controller untuk input field

    final TextEditingController tugasController = TextEditingController();

    DateTime? selectedDate;

    TimeOfDay? selectedTime;



    showDialog(

      context: context,

      builder: (BuildContext context) {

        return StatefulBuilder(

          builder: (BuildContext context, StateSetter setState) {

            return AlertDialog(

              title: const Text("Tambah Jadwal Baru"),

              content: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  TextField(

                    controller: tugasController,

                    decoration: const InputDecoration(labelText: "Tugas"),

                  ),

                  const SizedBox(height: 16),

                  Row(

                    children: [

                      Expanded(

                        child: ElevatedButton.icon(

                          onPressed: () async {

                            final DateTime? picked = await showDatePicker(

                              context: context,

                              initialDate: selectedDate ?? DateTime.now(),

                              firstDate: DateTime(2000),

                              lastDate: DateTime(2101),

                            );

                            if (picked != null && picked != selectedDate) {

                              setState(() {

                                selectedDate = picked;

                              });

                            }

                          },

                          icon: const Icon(Icons.calendar_today),

                          label: Text(selectedDate == null

                              ? "Pilih Tanggal"

                              : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),

                        ),

                      ),

                      const SizedBox(width: 16),

                      Expanded(

                        child: ElevatedButton.icon(

                          onPressed: () async {

                            final TimeOfDay? picked = await showTimePicker(

                              context: context,

                              initialTime: selectedTime ?? TimeOfDay.now(),

                            );

                            if (picked != null && picked != selectedTime) {

                              setState(() {

                                selectedTime = picked;

                              });

                            }

                          },

                          icon: const Icon(Icons.access_time),

                          label: Text(selectedTime == null

                              ? "Pilih Waktu"

                              : selectedTime!.format(context)),

                        ),

                      ),

                    ],

                  ),

                ],

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.of(context).pop(),

                  child: const Text("Batal"),

                ),

                ElevatedButton(

                  onPressed: () {

                    if (tugasController.text.isNotEmpty &&

                        selectedDate != null &&

                        selectedTime != null) {

                      final String formattedDate =

                          "${selectedDate!.day} ${_getBulan(selectedDate!.month)} ${selectedDate!.year}";

                      final String formattedTime =

                          selectedTime!.format(context);



                      _schedules.add({

                        "tugas": tugasController.text,

                        "tanggal": formattedDate,

                        "waktu": formattedTime,

                        "status":

                            "Akan Datang", // Status default untuk jadwal baru

                      });

                      // This setState is for the main page, not the dialog

                      this.setState(() {});

                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(

                        const SnackBar(

                            content:

                                Text("Jadwal baru berhasil ditambahkan.")),

                      );

                    }

                  },

                  child: const Text("Simpan"),

                ),

              ],

            );

          },

        );

      },

    );

  }



  String _getBulan(int month) {

    switch (month) {

      case 1:

        return "Jan";

      case 2:

        return "Feb";

      case 3:

        return "Mar";

      case 4:

        return "Apr";

      case 5:

        return "Mei";

      case 6:

        return "Jun";

      case 7:

        return "Jul";

      case 8:

        return "Agu";

      case 9:

        return "Sep";

      case 10:

        return "Okt";

      case 11:

        return "Nov";

      case 12:

        return "Des";

      default:

        return "";

    }

  }



  void _deleteSchedule(int index) {

    setState(() {

      _schedules.removeAt(index);

    });

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(content: Text("Jadwal berhasil dihapus.")),

    );

  }



  @override

  Widget build(BuildContext context) {

    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(

      body: ListView.builder(

        padding: const EdgeInsets.all(10),

        itemCount: _schedules.length,

        itemBuilder: (context, index) {

          var item = _schedules[index];

          return Card(

            elevation: 3,

            margin: const EdgeInsets.symmetric(vertical: 8),

            child: ListTile(

              leading: CircleAvatar(

                backgroundColor: item['status'] == "Selesai"

                    ? Colors.green

                    : Colors.orange,

                child: const Icon(Icons.schedule, color: Colors.white),

              ),

              title: Text(item['tugas']!,

                  style: const TextStyle(fontWeight: FontWeight.bold)),

              subtitle: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const SizedBox(height: 5),

                  Text("${item['tanggal']} • ${item['waktu']}"),

                  Text("Status: ${item['status']}",

                      style: TextStyle(

                          color: Colors.blue[800],

                          fontWeight: FontWeight.bold)),

                ],

              ),

              trailing: IconButton(

                icon: const Icon(Icons.delete, color: Colors.red),

                onPressed: () => _deleteSchedule(index),

              ),

            ),

          );

        },

      ),

      floatingActionButton: FloatingActionButton(

        onPressed: _addSchedule,

        tooltip: 'Tambah Jadwal',

        child: const Icon(Icons.add),

        backgroundColor: Colors.green,

      ),

    );

  }



  @override

  bool get wantKeepAlive => true;

}
