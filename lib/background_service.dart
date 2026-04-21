import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/auth_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'Layanan Penugasan Sopir',
    description: 'Menjaga agar notifikasi penugasan masuk',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, // Auto start on boot or app start
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Layanan Sopir SiKenDi Aktif',
      initialNotificationContent: 'Menunggu penugasan...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Hanya Android yang butuh set status notification
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Setup local notifications to handle tap
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  String? currentPendingTaskId;

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final namaSopir = await AuthService.storage.read(key: 'nama_sopir');
    
    if (namaSopir != null && namaSopir.isNotEmpty) {
      final tugas = await MongoDBService.getTugasSekarang(namaSopir);
      
      if (tugas != null && tugas['konfirmasi_sopir'] == 'pending') {
        final taskId = tugas['deviceId']?.toString() ?? '';
        
        if (taskId != currentPendingTaskId) {
          currentPendingTaskId = taskId;
          
          flutterLocalNotificationsPlugin.show(
            id: 889,
            title: 'PANGGILAN PENUGASAN BARU!',
            body: 'Ketuk untuk melihat tugas: ${tugas['tugas'] ?? '-'}',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'Layanan Penugasan Sopir',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
                playSound: true,
              ),
            ),
          );
        }
      } else {
        // Jika tugas tidak ada atau sudah diterima/ditolak, hapus pending state
        currentPendingTaskId = null;
      }
    }
  });
}
