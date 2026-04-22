import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sikendi/mongodb_service.dart';
import 'package:sikendi/auth_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sikendi_silent_service', // ID Baru untuk mereset cache Android
    'Layanan Penugasan Sopir',
    description: 'Menjaga agar notifikasi penugasan masuk',
    importance: Importance.min,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'SiKenDi Aktif',
      initialNotificationContent: 'Menunggu penugasan...',
      foregroundServiceNotificationId: 888,
      notificationChannelId:
          'sikendi_silent_service', // Harus sama dengan di atas
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
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

  // Polling logic has been removed and replaced by a real-time FCM handler in main.dart
  debugPrint("Background service is running without polling for tasks.");
}
