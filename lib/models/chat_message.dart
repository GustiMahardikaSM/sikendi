class ChatMessage {
  final String id;
  final String roomId;
  final String senderRole;
  final String senderId;
  final String senderNama;
  final String? senderEmail;
  final String? text;
  final String? fotoUrl;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderRole,
    required this.senderId,
    required this.senderNama,
    this.senderEmail,
    this.text,
    this.fotoUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'].toString(),
        roomId: j['room_id'],
        senderRole: j['sender_role'],
        senderId: j['sender_id'].toString(),
        senderNama: j['sender_nama'] ?? '-',
        senderEmail: j['sender_email'],
        text: j['text'],
        fotoUrl: j['foto_url'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}
