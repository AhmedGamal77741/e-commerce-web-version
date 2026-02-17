// screens/chat_screen.dart
import 'dart:io';
import 'package:ecommerece_app/core/cache/user_cache.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/features/chat/models/chat_room_model.dart';
import 'package:ecommerece_app/features/chat/models/story_model.dart';
import 'package:ecommerece_app/features/chat/services/story_service.dart';
import 'package:ecommerece_app/features/chat/ui/story_player_screen.dart';
import 'package:ecommerece_app/features/chat/widgets/chat_post_share.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

// ── Design tokens (matching screenshot) ──────────────────────────────────────
const _kBgColor = Color(0xFFF2F2F2); // overall background
const _kBubbleColor = Color(0xFFEEEEEE); // all bubbles same colour
const _kInputBg = Color(0xFFE8E8E8); // input field background
const _kSendActive = Color(0xFF1A1A1A); // send button when active
const _kSendInactive = Color(0xFFCCCCCC); // send button when empty

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String chatRoomName;
  final bool isDeleted;
  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    required this.chatRoomName,
    this.isDeleted = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  XFile? _pickedImage;
  bool _isBlocked = false;
  bool _blocked = false;
  bool _loadingBlockState = true;
  MessageModel? _replyToMessage;

  // ── Group members state ───────────────────────────────────────────────────
  ChatRoomModel? _chatRoom;
  List<String> _memberNames = [];
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _checkBlockState();
    _loadChatRoom();
  }

  void _markMessagesAsRead() =>
      _chatService.markMessagesAsRead(widget.chatRoomId);

  Future<void> _loadChatRoom() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();
    if (!doc.exists || !mounted) return;
    final room = ChatRoomModel.fromMap(doc.data()!);
    if (room.type == 'group') {
      final names = await _fetchMemberNames(room.participants);
      if (mounted)
        setState(() {
          _chatRoom = room;
          _isGroup = true;
          _memberNames = names;
        });
    } else {
      if (mounted) setState(() => _isGroup = false);
    }
  }

  Future<List<String>> _fetchMemberNames(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) async {
        if (id == currentUserId) return '나';
        try {
          final doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
          return doc.data()?['name'] as String? ?? '알 수 없음';
        } catch (_) {
          return '알 수 없음';
        }
      }),
    );
    final sorted = [...results];
    final mi = sorted.indexOf('나');
    if (mi > 0) {
      sorted.removeAt(mi);
      sorted.insert(0, '나');
    }
    return sorted;
  }

  String get _membersSubtitle {
    if (_memberNames.isEmpty) return '';
    if (_memberNames.length <= 2) return _memberNames.join(', ');
    return '${_memberNames.take(2).join(', ')} 외 ${_memberNames.length - 2}명';
  }

  void _showMembersDialog() {
    if (_chatRoom == null) return;
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 80,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      const Text(
                        '멤버',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_chatRoom!.participants.length}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[100], height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchMemberDetails(_chatRoom!.participants),
                    builder: (context, snap) {
                      if (!snap.hasData)
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: snap.data!.length,
                        separatorBuilder:
                            (_, __) =>
                                Divider(color: Colors.grey[100], height: 1),
                        itemBuilder: (_, i) {
                          final m = snap.data![i];
                          final isMe = m['id'] == currentUserId;
                          final url = m['url'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      url.isNotEmpty ? NetworkImage(url) : null,
                                  backgroundColor: Colors.grey[200],
                                  child:
                                      url.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            size: 20,
                                            color: Colors.grey,
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isMe ? '${m['name']} (나)' : m['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          isMe
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(color: Colors.grey[100], height: 1),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMemberDetails(
    List<String> ids,
  ) async {
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
          if (doc.exists)
            return {
              'id': id,
              'name': doc.data()!['name'] ?? '알 수 없음',
              'url': doc.data()!['url'] ?? '',
            };
        } catch (_) {}
        return {'id': id, 'name': '알 수 없음', 'url': ''};
      }),
    );
    results.sort(
      (a, b) =>
          a['id'] == currentUserId
              ? -1
              : b['id'] == currentUserId
              ? 1
              : 0,
    );
    return results;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _checkBlockState() async {
    final chatRoomDoc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();
    final chatRoom = ChatRoomModel.fromMap(chatRoomDoc.data()!);
    if (chatRoom.type != 'direct') {
      setState(() {
        _blocked = false;
        _isBlocked = false;
        _loadingBlockState = false;
      });
      return;
    }
    final otherUserId = chatRoom.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) {
      setState(() {
        _blocked = false;
        _isBlocked = false;
        _loadingBlockState = false;
      });
      return;
    }
    final currentDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
    final otherDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
    setState(() {
      _blocked = List<String>.from(
        currentDoc.data()?['blocked'] ?? [],
      ).contains(otherUserId);
      _isBlocked = List<String>.from(
        otherDoc.data()?['blocked'] ?? [],
      ).contains(currentUserId);
      _loadingBlockState = false;
    });
  }

  Future<void> _unblockUser(String otherUserId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({
          'blocked': FieldValue.arrayRemove([otherUserId]),
        });
    setState(() => _blocked = false);
  }

  Future<void> _sendImageMessage() async {
    if (_pickedImage == null) return;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
    final ref = FirebaseStorage.instance.ref().child('chat_images/$fileName');
    UploadTask task;
    if (kIsWeb) {
      final bytes = await _pickedImage!.readAsBytes();
      task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      task = ref.putFile(File(_pickedImage!.path));
    }
    final url = await (await task).ref.getDownloadURL();
    await _chatService.sendMessage(
      chatRoomId: widget.chatRoomId,
      content: _messageController.text.trim(),
      imageUrl: url,
      replyToMessageId: _replyToMessage?.id,
    );
    _messageController.clear();
    await _chatService.resetDeletedBy(widget.chatRoomId);
    setState(() {
      _pickedImage = null;
      _replyToMessage = null;
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    await _chatService.sendMessage(
      chatRoomId: widget.chatRoomId,
      content: content,
      replyToMessageId: _replyToMessage?.id,
    );
    _messageController.clear();
    await _chatService.resetDeletedBy(widget.chatRoomId);
    setState(() => _replyToMessage = null);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        forceMaterialTransparency: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _isGroup ? _showMembersDialog : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.chatRoomName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isGroup && _membersSubtitle.isNotEmpty)
                Text(
                  _membersSubtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
      body:
          _loadingBlockState
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // ── Message list ──────────────────────────────────────────
                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      stream: _chatService.getMessagesStream(widget.chatRoomId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        final messages = snapshot.data ?? [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              '아직 메시지가 없습니다',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        if (_pickedImage != null) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child:
                                      kIsWeb
                                          ? Image.network(
                                            _pickedImage!.path,
                                            fit: BoxFit.cover,
                                          )
                                          : Image.file(
                                            File(_pickedImage!.path),
                                            fit: BoxFit.cover,
                                          ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        () =>
                                            setState(() => _pickedImage = null),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            if (message.deletedBy.contains(currentUserId))
                              return const SizedBox.shrink();
                            final isMe = message.senderId == currentUserId;
                            final showDate =
                                index == messages.length - 1 ||
                                !_isSameDay(
                                  messages[index].timestamp,
                                  messages[index + 1].timestamp,
                                );
                            return Column(
                              children: [
                                if (showDate)
                                  _DateSeparator(date: message.timestamp),
                                MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  onReply:
                                      () => setState(
                                        () => _replyToMessage = message,
                                      ),
                                  interactable:
                                      !(_blocked || _isBlocked) &&
                                      !widget.isDeleted,
                                  isDeleted: widget.isDeleted,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // ── Reply preview strip ───────────────────────────────────
                  if (_replyToMessage != null)
                    Container(
                      color: const Color(0xFFE2E2E2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyToMessage!.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  _replyToMessage!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _replyToMessage = null),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Input bar ─────────────────────────────────────────────
                  if (!widget.isDeleted)
                    (_blocked || _isBlocked)
                        ? _BlockedBar(
                          blocked: _blocked,
                          isBlocked: _isBlocked,
                          chatRoomId: widget.chatRoomId,
                          currentUserId: currentUserId,
                          onUnblock: _unblockUser,
                          onCheckState: _checkBlockState,
                        )
                        : _InputBar(
                          controller: _messageController,
                          pickedImage: _pickedImage,
                          onPickImage: _pickImage,
                          onSend: () async {
                            if (_pickedImage != null) {
                              showLoadingDialog(context);
                              await _sendImageMessage();
                              if (mounted) Navigator.pop(context);
                            } else {
                              await _sendMessage();
                            }
                          },
                          onChanged: () => setState(() {}),
                        ),
                ],
              ),
    );
  }
}

// ─── Date separator ───────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '오늘';
    if (d == today.subtract(const Duration(days: 1))) return '어제';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label(),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final XFile? pickedImage;
  final VoidCallback onPickImage;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  const _InputBar({
    required this.controller,
    required this.pickedImage,
    required this.onPickImage,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasContent = controller.text.isNotEmpty || pickedImage != null;

    return SafeArea(
      top: false,
      child: Container(
        color: _kBgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Unified pill: + icon blended into the text field ───────────
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // + button inside pill
                    GestureDetector(
                      onTap: onPickImage,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    // Text field, fills remaining space
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onChanged: (_) => onChanged(),
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: '메시지 입력',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(
                            right: 12,
                            top: 10,
                            bottom: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Send button — only shown when there is content ─────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child:
                  hasContent
                      ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: onSend,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: _kSendActive,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blocked bar ──────────────────────────────────────────────────────────────

class _BlockedBar extends StatelessWidget {
  final bool blocked;
  final bool isBlocked;
  final String chatRoomId;
  final String currentUserId;
  final Future<void> Function(String) onUnblock;
  final VoidCallback onCheckState;

  const _BlockedBar({
    required this.blocked,
    required this.isBlocked,
    required this.chatRoomId,
    required this.currentUserId,
    required this.onUnblock,
    required this.onCheckState,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              blocked && isBlocked
                  ? '이 사용자를 차단했고 상대방도 나를 차단했습니다.'
                  : blocked
                  ? '이 사용자를 차단했습니다.'
                  : '상대방이 나를 차단했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            if (blocked) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () async {
                  final doc =
                      await FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(chatRoomId)
                          .get();
                  final other = List<String>.from(
                    doc['participants'],
                  ).firstWhere((id) => id != currentUserId);
                  await onUnblock(other);
                  onCheckState();
                },
                child: const Text('차단 해제'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback onReply;
  final bool interactable;
  final bool isDeleted;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.onReply,
    required this.interactable,
    required this.isDeleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: interactable ? () => _toggleLove(context) : null,
      onLongPress: interactable ? () => _showMessageOptions(context) : null,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 6,
          left: isMe ? 52 : 0,
          right: isMe ? 0 : 52,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Avatar (other users only)
            if (!isMe) ...[
              _Avatar(senderId: message.senderId, isDeleted: isDeleted),
              const SizedBox(width: 6),
            ],

            // Column: name + reply + bubble + timestamp
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        isDeleted ? '삭제된 사용자' : message.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Bubble row with love indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Love indicator left side (my messages)
                      if (isMe && message.lovedBy.isNotEmpty)
                        _LoveIndicator(
                          count: message.lovedBy.length,
                          lovedByMe: message.lovedBy.contains(
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                          onTap:
                              interactable ? () => _toggleLove(context) : null,
                        ),

                      // The bubble
                      Flexible(child: _BubbleContent(message: message)),

                      // Love indicator right side (others' messages)
                      if (!isMe && message.lovedBy.isNotEmpty)
                        _LoveIndicator(
                          count: message.lovedBy.length,
                          lovedByMe: message.lovedBy.contains(
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                          onTap:
                              interactable ? () => _toggleLove(context) : null,
                        ),
                    ],
                  ),

                  // Timestamp
                  Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLove(BuildContext context) => ChatService().toggleLoveReaction(
    messageId: message.id,
    chatRoomId: message.chatRoomId,
  );

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('답장'),
                onTap: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('복사'),
                onTap: () => Navigator.pop(context),
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('삭제', style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context),
                ),
              const SizedBox(height: 8),
            ],
          ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Bubble content ───────────────────────────────────────────────────────────

class _BubbleContent extends StatelessWidget {
  final MessageModel message;
  const _BubbleContent({required this.message});

  @override
  Widget build(BuildContext context) {
    // Reply preview inline
    Widget? replyWidget;
    if (message.replyToMessageId != null &&
        message.replyToMessageId!.isNotEmpty) {
      replyWidget = _ReplyPreview(
        messageId: message.replyToMessageId!,
        chatRoomId: message.chatRoomId,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        color: _kBubbleColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyWidget != null) ...[replyWidget, const SizedBox(height: 6)],
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          if (message.postData != null) ...[
            if (message.content.isNotEmpty) const SizedBox(height: 6),
            ChatPostShareWidget(
              imageUrl: message.postData!['imgUrl'],
              authorName: message.postData!['authorName'],
              postTitle: message.postData!['text'],
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => Comments(postId: message.postData!['postId']),
                    ),
                  ),
            ),
          ],
          if (message.productData != null) ...[
            if (message.content.isNotEmpty) const SizedBox(height: 6),
            ChatPostShareWidget(
              imageUrl: message.productData!.imgUrl!,
              authorName: message.productData!.pricePoints[0].toString(),
              postTitle: message.productData!.productName,
              onTap: () {},
            ),
          ],
          if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
            if (message.content.isNotEmpty) const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () async {
                  if (!message.isStory) return;
                  final story = await StoryService().getStoryById(
                    message.storyId!,
                  );
                  if (story == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => StoryPlayerScreen(
                            group: UserStoryGroup(
                              authorId: story.authorId,
                              authorName: story.authorName,
                              authorImage: story.authorImage,
                              stories: [story],
                            ),
                          ),
                    ),
                  );
                },
                child: Image.network(message.imageUrl!, fit: BoxFit.cover),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String senderId;
  final bool isDeleted;
  const _Avatar({required this.senderId, required this.isDeleted});

  @override
  Widget build(BuildContext context) {
    if (isDeleted) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        backgroundImage: const AssetImage('assets/avatar.png'),
      );
    }
    return FutureBuilder(
      future: UserCache.getUser(senderId),
      builder: (_, snap) {
        if (!snap.hasData)
          return CircleAvatar(radius: 16, backgroundColor: Colors.grey[200]);
        final data = snap.data!.data() as Map<String, dynamic>?;
        final url = data?['url'] as String? ?? '';
        return CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
          child:
              url.isEmpty
                  ? const Icon(Icons.person, size: 16, color: Colors.grey)
                  : null,
        );
      },
    );
  }
}

// ─── Reply preview (inside bubble) ───────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final String messageId;
  final String chatRoomId;
  const _ReplyPreview({required this.messageId, required this.chatRoomId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('chatRooms')
              .doc(chatRoomId)
              .collection('messages')
              .doc(messageId)
              .get(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: 26,
                color: Colors.grey[500],
                margin: const EdgeInsets.only(right: 6),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['senderName'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      data['content'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Love indicator ───────────────────────────────────────────────────────────

class _LoveIndicator extends StatelessWidget {
  final int count;
  final bool lovedByMe;
  final VoidCallback? onTap;
  const _LoveIndicator({
    required this.count,
    required this.lovedByMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(
              AssetImage(
                lovedByMe
                    ? "assets/icon=like,status=off (1).png"
                    : "assets/icon=like,status=off.png",
              ),
              size: 16,
              color: lovedByMe ? const Color(0xFF280404) : Colors.grey[500],
            ),
            const SizedBox(width: 2),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
