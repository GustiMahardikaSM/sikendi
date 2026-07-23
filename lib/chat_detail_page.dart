import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sikendi/auth_service.dart';
import 'package:sikendi/chat_socket_service.dart';
import 'package:sikendi/models/chat_message.dart';
import 'package:sikendi/models/chat_room.dart';
import 'package:sikendi/mongodb_service.dart';

class ChatDetailPage extends StatefulWidget {
  final ChatRoom room;
  final bool isSopir;

  const ChatDetailPage({super.key, required this.room, required this.isSopir});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};

  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;
  void Function()? _unlisten;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUser = await AuthService.getCurrentUser();
    _unlisten = ChatSocketService.instance.addListener(_onSocketEvent);
    ChatSocketService.instance.subscribe(widget.room.roomId);
    await _loadMessages();
    MongoDBService.markChatRoomRead(widget.room.roomId);
  }

  @override
  void dispose() {
    ChatSocketService.instance.unsubscribe(widget.room.roomId);
    _unlisten?.call();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    if (event['type'] != 'message') return;
    if (event['roomId'] != widget.room.roomId) return;
    final msg = ChatMessage.fromJson(event['message']);
    _appendMessage(msg);
  }

  void _appendMessage(ChatMessage msg) {
    if (_messageIds.contains(msg.id)) return;
    _messageIds.add(msg.id);
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final result = await MongoDBService.getChatMessages(widget.room.roomId);
    if (!mounted) return;
    if (result['success'] == true) {
      final msgs = result['messages'] as List<ChatMessage>;
      setState(() {
        _messages.clear();
        _messageIds.clear();
        for (final m in msgs) {
          _messages.add(m);
          _messageIds.add(m.id);
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _isLoading = false;
        _loadError = result['message'] ?? 'Gagal memuat pesan';
      });
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    setState(() => _isSending = true);

    final result = await MongoDBService.sendChatMessage(widget.room.roomId, text: text);
    if (mounted) {
      setState(() => _isSending = false);
      if (result['success'] == true) {
        _appendMessage(result['message'] as ChatMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Gagal mengirim pesan')),
        );
      }
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final fotoBase64 = base64Encode(bytes);
      final result = await MongoDBService.sendChatMessage(widget.room.roomId, fotoBase64: fotoBase64);
      if (mounted) {
        if (result['success'] == true) {
          _appendMessage(result['message'] as ChatMessage);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Gagal mengirim foto')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSopir ? (widget.room.managerName ?? 'Manager') : widget.room.sopirNama),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildWarningBanner(),
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chat ini akan selalu dicatat sebagai log di laporan, jadi jangan kirimkan chat/informasi bersifat pribadi. Hanya boleh yang bersifat official saja.',
              style: TextStyle(fontSize: 11, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('Belum ada pesan. Mulai percakapan.'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  bool _isMine(ChatMessage msg) {
    final myId = _currentUser?['id']?.toString();
    return myId != null && myId == msg.senderId;
  }

  Widget _buildBubble(ChatMessage msg) {
    final mine = _isMine(msg);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? Colors.blue[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderNama,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: mine ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            if (msg.fotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  msg.fotoUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 200,
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => const SizedBox(
                    width: 200,
                    height: 100,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            if (msg.text != null && msg.text!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: msg.fotoUrl != null ? 6 : 0),
                child: Text(
                  msg.text!,
                  style: TextStyle(color: mine ? Colors.white : Colors.black87),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: _isSending ? null : _showAttachmentSheet,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 4),
            _isSending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: Colors.blue[900]),
                    onPressed: _sendText,
                  ),
          ],
        ),
      ),
    );
  }
}
