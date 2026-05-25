import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/driver_page.dart'; // Import halaman driver
import 'package:sikendi/login_page.dart';
import 'package:sikendi/manager_page.dart'; // Import halaman manager
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Tambahkan ini untuk defaultTargetPlatform
import 'package:sikendi/manager_login_page.dart';
import 'package:sikendi/superadmin_page.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/driver_incoming_task_page.dart';
import 'package:sikendi/background_service.dart'; // Import background service
import 'package:flutter_background_service/flutter_background_service.dart';


// ==========================================================
// 1. FUNGSI UTAMA (Main Entry Point)
// ==========================================================

// Fungsi ini harus berada di top-level (di luar kelas) untuk menangani notifikasi
// saat aplikasi berada di background atau terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // VERIFIKASI PENERIMA: Jangan proses jika notifikasi bukan untuk user yang sedang login
  final targetEmail = message.data['targetEmail'];
  final user = await AuthService.getCurrentUser();
  
  if (targetEmail != null && user != null && user['email'] != targetEmail) {
    return;
  }

  if (message.data['deviceId'] != null && message.data['type'] == 'panggilan_tugas') {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Inisialisasi plugin (diperlukan untuk background isolate)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    // Saat menginisialisasi di background isolate, kita perlu menyediakan callback
    // untuk menangani tap notifikasi.
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Definisikan channel notifikasi (ID harus sama dengan yang di AndroidManifest.xml & service)
    // Gunakan ID BARU agar Android mereset aturan notifikasinya
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'channel_tugas_urgent_v2', // Naikkan versi channel agar perubahan suara diterapkan
      'Panggilan Tugas Urgent',
      description: 'Notifikasi penting layar penuh untuk tugas baru.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone_task'),
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Tampilkan notifikasi full-screen
    await flutterLocalNotificationsPlugin.show(
      id: 889, // ID notifikasi yang unik
      title: message.data['title'] ?? 'PANGGILAN TUGAS BARU!', // Ambil dari data
      body: message.data['body'] ?? 'Ketuk untuk melihat tugas', // Ambil dari data
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          priority: Priority.high,
          importance: Importance.max,
          fullScreenIntent: true, // Akan bekerja jika payload-nya Data-Only
          sound: const RawResourceAndroidNotificationSound('ringtone_task'), // Sesuai dengan file di res/raw/ringtone_task.mp3
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: jsonEncode(message.data), // Kirim data notifikasi untuk ditangani saat diketuk
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handler ini diperlukan oleh plugin 'flutter_local_notifications' saat
  // notifikasi di-tap dari background. Logika navigasi utama tetap
  // ditangani oleh 'onMessageOpenedApp' di main isolate saat aplikasi dibuka.
  // ignore: avoid_print
}

// GlobalKey untuk navigasi dari luar widget tree (diperlukan oleh FCM)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Pastikan semua widget Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi Firebase
  await Firebase.initializeApp();
  // Inisialisasi Background Service (Konfigurasi awal)
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner:
          false, // Menghilangkan banner "Debug" di pojok kanan atas
      title: 'SiKenDi App',
      navigatorKey: navigatorKey, // Set GlobalKey untuk navigasi
      // Aplikasi dimulai dari Halaman Awal (RoleSelectionPage)
      home: RoleSelectionPage(),
    ),
  );
}

// ==========================================================
// 2. HALAMAN PEMILIHAN PERAN (UI MODERN)
// ==========================================================
class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isChecking = true;
  bool _isNavigating = false; // Flag untuk mencegah navigasi ganda

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _setupFCM();
  }

  Future<void> _checkAutoLogin() async {
    final user = await AuthService.getCurrentUser();
    
    if (user != null) {
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        _navigateToDashboard(user);
      }
    } else {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToDashboard(Map<String, dynamic> user) {
    if (!mounted) return;
    final role = user['role']?.toString().toLowerCase();
    
    if (role == 'superadmin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SuperAdminPage(user: user)),
      );
    } else if (role == 'manager') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ManagerPage(user: user)),
      );
    } else if (role == 'sopir') {
      _startSopirAutoFlow(user);
    } else {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _startSopirAutoFlow(Map<String, dynamic> user) async {
    try {
      final nama = user['nama'] ?? user['nama_lengkap'];
      if (nama != null) {
        final tugas = await MongoDBService.getTugasSekarang(nama);
        
        if (tugas != null && tugas['konfirmasi_sopir'] == 'pending') {
          // CEK APAKAH TUGAS SUDAH PERNAH DILIHAT DETAILNYA
          final taskId = tugas['_id'] ?? tugas['id'] ?? '';
          bool alreadySeen = await AuthService.isTaskSeen(taskId.toString());

          if (alreadySeen) {
          } else {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverIncomingTaskPage(
                    tugas: tugas,
                    user: user,
                    onDecision: () {},
                  ),
                ),
              );
              return;
            }
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DriverPage(user: user)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // Fungsi untuk setup listener dan izin FCM
  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // 1. Minta izin notifikasi FCM (wajib untuk iOS & Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 1b. Minta izin spesifik untuk Android 13+ melalui Local Notifications Plugin
    if (defaultTargetPlatform == TargetPlatform.android) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // 2. Inisialisasi Local Notifications untuk menangani tap di foreground/background
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleNotificationNavigation(data);
          } catch (e) {
          }
        }
      },
    );

    // 3. Listener untuk pesan FCM saat aplikasi di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      
      // VERIFIKASI PENERIMA
      final targetEmail = message.data['targetEmail'];
      final user = await AuthService.getCurrentUser();
      if (targetEmail != null && user != null && user['email'] != targetEmail) {
        return;
      }

      // Cek jika ini adalah notifikasi penugasan baru (data-only)
      if (message.data['deviceId'] != null && message.data['type'] == 'panggilan_tugas') {
        _handleNotificationNavigation(message.data);
      }
    });

    // 4. Listener untuk saat notifikasi diketuk (app dari background/terminated - FCM standard)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });

    // 5. Cek jika app dibuka dari notifikasi saat app dalam kondisi terminated (FCM)
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }

    // 6. Cek jika app dibuka dari NOTIFIKASI LOKAL saat terminated
    final NotificationAppLaunchDetails? notificationAppLaunchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
      if (payload != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          _handleNotificationNavigation(data);
        } catch (e) {
        }
      }
    }
  }

  // Fungsi untuk navigasi ke halaman tugas saat notifikasi diketuk
  void _handleNotificationNavigation(Map<String, dynamic> data) async {
    if (_isNavigating) {
      return;
    }

    final String? deviceId = data['deviceId'];
    final String? targetEmail = data['targetEmail'];

    if (deviceId != null && navigatorKey.currentContext != null) {
      _isNavigating = true;
      // Ambil data user yang sedang login untuk diteruskan ke halaman tugas
      final user = await AuthService.getCurrentUser();
      
      // VERIFIKASI PENERIMA (Lapis terakhir)
      if (user == null) {
        _isNavigating = false;
        return;
      }
      
      if (targetEmail != null && user['email'] != targetEmail) {
        _isNavigating = false;
        return;
      }

      // Ambil detail tugas lengkap dari server
      final tugas = await MongoDBService.getDetailKendaraan(deviceId);

      if (tugas != null) {
        // CEK APAKAH TUGAS SUDAH PERNAH DILIHAT
        final taskId = tugas['_id'] ?? tugas['id'] ?? '';
        bool alreadySeen = await AuthService.isTaskSeen(taskId.toString());

        if (alreadySeen) {
          _isNavigating = false;
          _navigateToDashboard(user);
          return;
        }

        // Gunakan navigatorKey untuk push halaman dari mana saja
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => DriverIncomingTaskPage(
              tugas: tugas,
              user: user,
              onDecision: () {}, // Callback bisa diisi jika perlu aksi setelah keputusan
            ),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF003366),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Definisikan warna utama agar konsisten
    const primaryColor = Color(0xFF003366); // Navy Blue
    const managerButtonColor = Color(0xFF005A9C); // Slightly Lighter Blue
    const driverButtonColor = Color(0xFF2E7D32); // Darker Green

    return Scaffold(
      body: Stack(
        children: [
          // --- Latar Belakang Gradien ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  Color(0xFF001F3F), // Darker Navy
                ],
              ),
            ),
          ),
          // Elemen dekoratif
          Positioned(
            top: -50,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // --- Konten Utama ---
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Header ---
                    const Icon(
                      Icons.directions_car_filled,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "SiKenDi",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const Text(
                      "SISTEM INFORMASI KENDARAAN DINAS\nUNIVERSITAS DIPONEGORO",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                        height: 1.5, // Menambah jarak antar baris
                      ),
                    ),
                    const SizedBox(height: 64),

                    // --- Pemisah ---
                    const Text(
                      "Masuk Sebagai",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Tombol Manager ---
                    _buildRoleButton(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      label: "MANAJER",
                      subtitle: "Monitoring Armada",
                      color: managerButtonColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManagerLoginPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- Tombol Sopir ---
                    _buildRoleButton(
                      context,
                      icon: Icons.drive_eta_rounded,
                      label: "SOPIR",
                      subtitle: "Aktifkan Tracking",
                      color: driverButtonColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk membuat tombol yang dapat digunakan kembali
  Widget _buildRoleButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
