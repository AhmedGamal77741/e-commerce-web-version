import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_room_model.dart';
import '../services/chat_service.dart';

class GroupChatsScreen extends StatefulWidget {
  @override
  State<GroupChatsScreen> createState() => _GroupChatsScreenState();
}

class _GroupChatsScreenState extends State<GroupChatsScreen> {
  final ChatService chatService = ChatService();
  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  // ── Active overlay (only one menu open at a time) ────────────────────────
  OverlayEntry? _activeMenuOverlay;

  // ─── Group chats order stream ─────────────────────────────────────────────
  Stream<Map<String, int>> get _groupOrderStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return <String, int>{};
          final data = snap.data();
          final raw = data?['groupChatsOrder'];
          if (raw == null) return <String, int>{};
          return Map<String, int>.from(raw as Map);
        });
  }

  @override
  void dispose() {
    _dismissActiveMenu();
    super.dispose();
  }

  void _dismissActiveMenu() {
    _activeMenuOverlay?.remove();
    _activeMenuOverlay = null;
  }

  // ─── KakaoTalk-style long-press popup ─────────────────────────────────────
  void _showGroupMenu({
    required LayerLink layerLink,
    required Size tileSize,
    required ChatRoomModel chat,
  }) {
    _dismissActiveMenu();

    const double popupWidth = 220;
    const double popupHeight = 210;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Same math as original: right-aligned to tile, vertically centred + nudge down
    final double followerDx = tileSize.width - popupWidth - 8;
    final double followerDy = (tileSize.height / 2) - (popupHeight / 2) + 80;

    _activeMenuOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // ── Transparent dismiss barrier ──────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissActiveMenu,
                child: const SizedBox.expand(),
              ),
            ),

            // ── Popup anchored to the tile ────────────────────────────────
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: Offset(followerDx, followerDy),
              child: Align(
                alignment: Alignment.topLeft,
                child: _ClampedMenu(
                  popupWidth: popupWidth,
                  popupHeight: popupHeight,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: popupWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              chat.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            color: Colors.grey[200],
                            thickness: 1,
                            height: 1,
                          ),
                          _buildMenuOption(
                            label: '사진 변경',
                            onTap: () async {
                              _dismissActiveMenu();
                              await _changeGroupImage(chat);
                            },
                          ),
                          Divider(
                            color: Colors.grey[200],
                            thickness: 1,
                            height: 1,
                          ),
                          _buildMenuOption(
                            label: '이름 변경',
                            onTap: () {
                              _dismissActiveMenu();
                              _showRenameDialog(chat);
                            },
                          ),
                          Divider(
                            color: Colors.grey[200],
                            thickness: 1,
                            height: 1,
                          ),
                          _buildMenuOption(
                            label: '나가기',
                            isLast: true,
                            onTap: () {
                              _dismissActiveMenu();
                              _confirmLeaveGroup(chat);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_activeMenuOverlay!);
  }

  Widget _buildMenuOption({
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          isLast
              ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
              : BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: labelColor ?? Colors.black,
          ),
        ),
      ),
    );
  }

  // ─── Confirm leave group dialog ───────────────────────────────────────────
  Future<void> _confirmLeaveGroup(ChatRoomModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '채팅방 나가기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"${chat.name}" 채팅방에서 나가시겠습니까?\n나가면 대화 내용이 삭제됩니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            '나가기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirm != true) return;
    await chatService.removeParticipantFromGroup(chat.id, currentUserId);
  }

  // ─── Change group image ───────────────────────────────────────────────────
  Future<void> _changeGroupImage(ChatRoomModel chat) async {
    try {
      final newImageUrl = await uploadImageToFirebaseStorageHome();
      if (newImageUrl == null || newImageUrl.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chat.id)
          .update({'groupImage': newImageUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('그룹 사진을 변경했습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 변경 실패: $e')));
      }
    }
  }

  // ─── Rename group dialog ──────────────────────────────────────────────────
  void _showRenameDialog(ChatRoomModel chat) {
    final nameController = TextEditingController(text: chat.name);

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 80,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '이름 변경',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '채팅방 이름을 변경합니다',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    maxLength: 40,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: '채팅방 이름',
                      hintStyle: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 1.5),
                      ),
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () async {
                            final newName = nameController.text.trim();
                            Navigator.pop(dialogContext);
                            if (newName.isEmpty || newName == chat.name) return;
                            try {
                              await FirebaseFirestore.instance
                                  .collection('chatRooms')
                                  .doc(chat.id)
                                  .update({'name': newName});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '채팅방 이름을 "$newName"(으)로 변경했습니다',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('이름 변경 실패: $e')),
                                );
                              }
                            }
                          },
                          child: const Text(
                            '변경',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _groupOrderStream,
      builder: (context, orderSnapshot) {
        final orderMap = orderSnapshot.data ?? {};

        return StreamBuilder<List<ChatRoomModel>>(
          stream: chatService.getChatRoomsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupChats =
                snapshot.data!.where((chat) => chat.type == 'group').toList();

            groupChats.sort((a, b) {
              final aOrder = orderMap[a.id] ?? 999999;
              final bOrder = orderMap[b.id] ?? 999999;
              return aOrder.compareTo(bOrder);
            });

            if (groupChats.isEmpty) {
              return const Center(child: Text('그룹채팅 없음.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupChats.length,
              itemBuilder: (context, index) {
                final chat = groupChats[index];
                final int unread = chat.unreadCount[currentUserId] ?? 0;

                // LayerLink per tile — replaces the old GlobalKey approach
                final LayerLink layerLink = LayerLink();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final tileSize = Size(constraints.maxWidth, 72);

                    return CompositedTransformTarget(
                      link: layerLink,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ChatScreen(
                                      chatRoomId: chat.id,
                                      chatRoomName: chat.name,
                                    ),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showGroupMenu(
                              layerLink: layerLink,
                              tileSize: tileSize,
                              chat: chat,
                            );
                          },
                          child: Row(
                            children: [
                              // ── Avatar ──
                              CircleAvatar(
                                radius: 25,
                                backgroundImage:
                                    (chat.groupImage != null &&
                                            chat.groupImage!.isNotEmpty)
                                        ? NetworkImage(chat.groupImage!)
                                            as ImageProvider
                                        : const AssetImage('assets/009.png'),
                              ),
                              const SizedBox(width: 12),

                              // ── Name + last message ──
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chat.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    _GroupLastMessage(
                                      chat: chat,
                                      currentUserId: currentUserId,
                                    ),
                                  ],
                                ),
                              ),

                              // ── Unread badge ──
                              if (unread > 0)
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── _ClampedMenu ─────────────────────────────────────────────────────────────

class _ClampedMenu extends StatefulWidget {
  const _ClampedMenu({
    required this.child,
    required this.popupWidth,
    required this.popupHeight,
    required this.screenWidth,
    required this.screenHeight,
  });

  final Widget child;
  final double popupWidth;
  final double popupHeight;
  final double screenWidth;
  final double screenHeight;

  @override
  State<_ClampedMenu> createState() => _ClampedMenuState();
}

class _ClampedMenuState extends State<_ClampedMenu> {
  double _dx = 0;
  double _dy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final pos = box.localToGlobal(Offset.zero);

      double dx = 0;
      double dy = 0;

      if (pos.dx + widget.popupWidth > widget.screenWidth - 8) {
        dx = (widget.screenWidth - 8) - (pos.dx + widget.popupWidth);
      }
      if (pos.dx + dx < 8) dx = 8 - pos.dx;
      if (pos.dy + widget.popupHeight > widget.screenHeight - 20) {
        dy = (widget.screenHeight - 20) - (pos.dy + widget.popupHeight);
      }
      if (pos.dy + dy < 8) dy = 8 - pos.dy;

      if (dx != 0 || dy != 0) {
        setState(() {
          _dx = dx;
          _dy = dy;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: Offset(_dx, _dy), child: widget.child);
  }
}

// ─── Last message preview widget ─────────────────────────────────────────────

class _GroupLastMessage extends StatelessWidget {
  final ChatRoomModel chat;
  final String currentUserId;

  const _GroupLastMessage({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final content = chat.lastMessage ?? '';
    final senderId = chat.lastMessageSenderId ?? '';
    final senderName = chat.lastMessageSenderName ?? '';

    if (content.isEmpty && senderId.isEmpty) {
      if (chat.participants.isEmpty) return const SizedBox.shrink();
      return Text(
        '${chat.participants.length}명',
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      );
    }

    final bool isMe = senderId == currentUserId;
    final String nameLabel = isMe ? '나' : senderName;
    final bool isPhoto = content == '[사진]' || content == '[image]';

    return Row(
      children: [
        if (nameLabel.isNotEmpty)
          Text(
            '$nameLabel: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        if (isPhoto)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text(
                '사진',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          )
        else
          Expanded(child: _FadingText(text: content)),
      ],
    );
  }
}

// ─── Fading text for long messages ───────────────────────────────────────────

class _FadingText extends StatelessWidget {
  final String text;
  const _FadingText({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback:
          (bounds) => LinearGradient(
            stops: const [0.0, 0.72, 1.0],
            colors: [
              Colors.grey.shade400,
              Colors.grey.shade400,
              Colors.grey.shade400.withOpacity(0.0),
            ],
          ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
