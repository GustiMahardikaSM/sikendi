import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/chat_detail_page.dart';
import 'package:sikendi/chat_socket_service.dart';
import 'package:sikendi/models/chat_room.dart';
import 'package:sikendi/mongodb_service.dart';

class ChatRoomListPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const ChatRoomListPage({super.key, this.user});

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  bool _isSopir = false;
  bool _isLoading = true;
  List<ChatRoom> _rooms = [];
  void Function()? _unlisten;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = widget.user ?? await AuthService.getCurrentUser();
    final role = (user?['role'] ?? '').toString().toLowerCase();
    setState(() {
      _isSopir = role == 'sopir' || role == 'driver';
    });
    _unlisten = ChatSocketService.instance.addListener(_onSocketEvent);
    await _loadRooms();
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    if (event['type'] == 'chat_notification' || event['type'] == 'message') {
      _loadRooms();
    }
  }

  @override
  void dispose() {
    _unlisten?.call();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    if (mounted) setState(() => _isLoading = true);
    final rooms = await MongoDBService.getChatRooms();
    if (mounted) {
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    }
  }

  void _openRoom(ChatRoom room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(room: room, isSopir: _isSopir),
      ),
    );
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final myRooms = _rooms.where((r) => r.isOwner).toList();
    final otherRooms = _rooms.where((r) => !r.isOwner).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: _rooms.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      children: [
                        if (_isSopir)
                          ..._rooms.map((r) => _buildRoomTile(r))
                        else ...[
                          if (myRooms.isNotEmpty)
                            _buildSectionHeader('Tugas Saya'),
                          ...myRooms.map((r) => _buildRoomTile(r)),
                          if (otherRooms.isNotEmpty)
                            _buildSectionHeader('Tugas Lain'),
                          ...otherRooms.map((r) => _buildRoomTile(r, nimbrung: true)),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _isSopir
                        ? 'Anda sedang tidak menjalankan tugas'
                        : 'Belum ada tugas aktif',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSopir
                        ? 'Chat akan tersedia begitu Anda menerima tugas.'
                        : 'Chat akan muncul di sini saat ada sopir yang sedang bertugas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room, {bool nimbrung = false}) {
    final subtitleParts = <String>[];
    if (room.lastMessagePreview != null) {
      final prefix = room.lastMessageSenderRole == 'sopir' ? 'Sopir: ' : 'Manager: ';
      subtitleParts.add('$prefix${room.lastMessagePreview}');
    } else {
      subtitleParts.add('Belum ada pesan');
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.directions_car, color: Colors.white),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isSopir ? (room.managerName ?? 'Manager') : room.sopirNama,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (nimbrung)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('nimbrung', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
      subtitle: Text(
        '${room.plat} - ${room.model}\n${subtitleParts.join(' ')}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessageAt != null)
            Text(
              DateFormat('HH:mm').format(room.lastMessageAt!.toLocal()),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          const SizedBox(height: 6),
          if (room.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '${room.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () => _openRoom(room),
    );
  }
}
