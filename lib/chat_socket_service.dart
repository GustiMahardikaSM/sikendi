import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sikendi/api_config.dart';
import 'package:sikendi/auth_service.dart';

typedef ChatEventListener = void Function(Map<String, dynamic> event);

class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Set<ChatEventListener> _listeners = {};
  final Set<String> _subscribedRooms = {};
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  bool _manuallyClosed = true;

  Future<void> connect() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    _manuallyClosed = false;
    _reconnectTimer?.cancel();

    // ApiConfig.baseUrl = "https://api.sikendi.sbs/api" -> origin tanpa "/api"
    final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final wsOrigin = origin
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsOrigin/ws/chat?token=$token');

    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _reconnectAttempt = 0;

      for (final roomId in _subscribedRooms) {
        _send({'type': 'subscribe', 'roomId': roomId});
      }

      _subscription = channel.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            for (final listener in List<ChatEventListener>.from(_listeners)) {
              listener(data);
            }
          } catch (e) {
            debugPrint('[ChatSocket] Gagal parse event: $e');
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[ChatSocket] Gagal konek: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    if (_manuallyClosed) return;
    final delayMs = (1000 * (1 << _reconnectAttempt)).clamp(1000, 15000);
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), connect);
  }

  void disconnect() {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscribedRooms.clear();
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      // Koneksi belum siap — akan disubscribe ulang saat reconnect berhasil.
    }
  }

  void subscribe(String roomId) {
    _subscribedRooms.add(roomId);
    _send({'type': 'subscribe', 'roomId': roomId});
  }

  void unsubscribe(String roomId) {
    _subscribedRooms.remove(roomId);
    _send({'type': 'unsubscribe', 'roomId': roomId});
  }

  /// Mendaftarkan listener event chat. Mengembalikan fungsi untuk berhenti mendengarkan.
  void Function() addListener(ChatEventListener listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}
