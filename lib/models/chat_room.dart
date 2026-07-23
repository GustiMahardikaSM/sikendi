class ChatRoom {
  final String roomId;
  final String deviceId;
  final String plat;
  final String model;
  final String sopirNama;
  final String? managerName;
  final String? managerEmail;
  final bool isOwner;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderRole;

  ChatRoom({
    required this.roomId,
    required this.deviceId,
    required this.plat,
    required this.model,
    required this.sopirNama,
    this.managerName,
    this.managerEmail,
    required this.isOwner,
    required this.unreadCount,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderRole,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> j) => ChatRoom(
        roomId: j['room_id'],
        deviceId: j['device_id'] ?? '-',
        plat: j['plat'] ?? '-',
        model: j['model'] ?? '-',
        sopirNama: j['sopir_nama'] ?? '-',
        managerName: j['manager_name'],
        managerEmail: j['manager_email'],
        isOwner: j['is_owner'] ?? false,
        unreadCount: j['unread_count'] ?? 0,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.tryParse(j['last_message_at'])
            : null,
        lastMessagePreview: j['last_message_preview'],
        lastMessageSenderRole: j['last_message_sender_role'],
      );
}
