// screens/friends_screen.dart
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:ecommerece_app/features/chat/services/favorites_service.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  final String searchQuery;
  const FriendsScreen({super.key, this.searchQuery = ''});
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with TickerProviderStateMixin {
  final FriendsService _friendsService = FriendsService();
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();
  final FirebaseUserRepo _userRepo = FirebaseUserRepo();
  final FavoritesService _favoritesService = FavoritesService();

  bool _isSyncing = false;
  bool editMode = false;
  Set<String> selectedChatIds = {};

  MyUser? _currentUser;
  bool _isLoadingUser = true;
  Map<String, String> _latestAliases = {};

  // ── Expansion state ──────────────────────────────────────────────────────
  bool _favoritesExpanded = true;
  bool _subscribedExpanded = true;
  bool _friendsExpanded = true;
  bool _brandsExpanded = true;

  // ── Active overlay (only one menu open at a time) ────────────────────────
  OverlayEntry? _activeMenuOverlay;

  // ── Computed search query ────────────────────────────────────────────────
  String get _effectiveQuery => widget.searchQuery;
  bool get _isSearchActive => _effectiveQuery.isNotEmpty;

  // ─── Favorites order stream ───────────────────────────────────────────────
  Stream<Map<String, int>> _getFavoritesOrderStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return <String, int>{};
          final raw = snap.data()?['favoritesOrder'];
          if (raw == null) return <String, int>{};
          return Map<String, int>.from(raw as Map);
        });
  }

  // ─── Hidden user IDs stream ───────────────────────────────────────────────
  Stream<Set<String>> _getHiddenIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hiddenFriends')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  // ─── Alias map stream ─────────────────────────────────────────────────────
  Stream<Map<String, String>> _getAliasesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('aliases')
        .snapshots()
        .map((snap) {
          final map = <String, String>{};
          for (final doc in snap.docs) {
            final alias = doc.data()['alias'] as String?;
            if (alias != null && alias.isNotEmpty) {
              map[doc.id] = alias;
            }
          }
          return map;
        });
  }

  // ─── Following IDs stream ─────────────────────────────────────────────────
  Stream<Set<String>> _getFollowingIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  void toggleEditMode() {
    setState(() {
      editMode = !editMode;
      if (!editMode) selectedChatIds.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _syncContactsOnEnter();
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

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userRepo.user.first;
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _syncContactsOnEnter() async {
    setState(() => _isSyncing = true);
    try {
      _contactService.syncAndAddFriendsFromContacts();
    } catch (e) {
      debugPrint('Contact sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ─── Multi-field user search ──────────────────────────────────────────────

  Future<List<MyUser>> _searchUsersByAny(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final fs = FirebaseFirestore.instance;
    final currentDoc = await fs.collection('users').doc(currentUid).get();
    final currentUser = MyUser.fromDocument(currentDoc.data()!);
    final friendIds = currentUser.friends;

    Future<List<MyUser>> runQuery(String field, String value) async {
      final snap =
          await fs
              .collection('users')
              .where(field, isGreaterThanOrEqualTo: value)
              .where(field, isLessThan: '${value}z')
              .limit(20)
              .get();
      return snap.docs
          .map((d) => MyUser.fromDocument(d.data()))
          .where((u) => u.userId != currentUid && !friendIds.contains(u.userId))
          .toList();
    }

    final results = await Future.wait([
      runQuery('name', q),
      runQuery('email', q.toLowerCase()),
      runQuery('phoneNumber', q),
    ]);

    final seen = <String>{};
    final merged = <MyUser>[];
    for (final list in results) {
      for (final user in list) {
        if (seen.add(user.userId)) merged.add(user);
      }
    }
    return merged;
  }

  // ─── Bio edit dialog ─────────────────────────────────────────────────────

  void _showBioEditDialog() {
    final bioController = TextEditingController(text: _currentUser?.bio ?? '');
    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 80),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '상태 메시지',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: bioController,
                    maxLength: 60,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: '소개를 입력하세요',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      counterStyle: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          '취소',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () async {
                          final newBio = bioController.text.trim();
                          Navigator.pop(dialogContext);
                          if (_currentUser == null) return;
                          final updatedUser = MyUser(
                            userId: _currentUser!.userId,
                            email: _currentUser!.email,
                            name: _currentUser!.name,
                            url: _currentUser!.url,
                            isSub: _currentUser!.isSub,
                            defaultAddressId: _currentUser!.defaultAddressId,
                            blocked: _currentUser!.blocked,
                            payerId: _currentUser!.payerId,
                            isOnline: _currentUser!.isOnline,
                            lastSeen: _currentUser!.lastSeen,
                            chatRooms: _currentUser!.chatRooms,
                            friends: _currentUser!.friends,
                            friendRequestsSent:
                                _currentUser!.friendRequestsSent,
                            friendRequestsReceived:
                                _currentUser!.friendRequestsReceived,
                            bio: newBio,
                            phoneNumber: _currentUser!.phoneNumber,
                          );
                          try {
                            await _userRepo.updateUser(updatedUser, '');
                            if (mounted)
                              setState(() => _currentUser = updatedUser);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('업데이트 실패: ${e.toString()}'),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          '변경',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  // ─── Change Name / Alias dialog ───────────────────────────────────────────

  void _showChangeNameDialog(MyUser friend, String? currentAlias) {
    final aliasController = TextEditingController(text: currentAlias ?? '');
    final uid = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '이름 변경',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Center(
                    child: Text(
                      '나에게만 보이는 별명을 설정합니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    '별명',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: aliasController,
                    maxLength: 30,
                    autofocus: true,
                    style: TextStyle(fontSize: 16, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: friend.name,
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
                  if (currentAlias != null && currentAlias.isNotEmpty) ...[
                    SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        if (uid == null) return;
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('aliases')
                              .doc(friend.userId)
                              .delete();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${friend.name}님의 이름을 원래대로 되돌렸습니다',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('오류: $e')));
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 13,
                            color: Colors.grey[400],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '원래 이름으로 되돌리기  (${friend.name})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 13),
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
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () async {
                            final newAlias = aliasController.text.trim();
                            Navigator.pop(dialogContext);
                            if (uid == null) return;
                            try {
                              if (newAlias.isEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('aliases')
                                    .doc(friend.userId)
                                    .delete();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${friend.name}님의 이름을 원래대로 되돌렸습니다',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('aliases')
                                    .doc(friend.userId)
                                    .set({'alias': newAlias});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${friend.name}님의 이름을 "$newAlias"(으)로 변경했습니다',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('오류: $e')),
                                );
                              }
                            }
                          },
                          child: Text(
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

  // ─── Hide friend ──────────────────────────────────────────────────────────

  Future<void> _hideFriend(MyUser friend) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('hiddenFriends')
          .doc(friend.userId)
          .set({'hiddenAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.name}님을 숨겼습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  // ─── Delete friend ────────────────────────────────────────────────────────

  Future<void> _deleteFriend(MyUser friend) async {
    final displayName =
        (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('aliases')
                    .doc(friend.userId)
                    .get())
                .data()?['alias']
            as String? ??
        friend.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '친구 삭제',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '$displayName님을 친구 목록에서 삭제하시겠습니까?\n대화 내용도 함께 삭제됩니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
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
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            '삭제',
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
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      await _friendsService.removeFriend(friend.userId);
      final chatRoomId = ([currentUid, friend.userId]..sort()).join('_');
      await _chatService.softDeleteChatForCurrentUser(chatRoomId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName님을 친구 목록에서 삭제했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  // ─── Block friend ─────────────────────────────────────────────────────────

  Future<void> _blockFriend(MyUser friend) async {
    final displayName = friend.name;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '차단',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '$displayName님을 차단하시겠습니까?\n차단하면 서로 메시지를 보낼 수 없습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
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
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            '차단',
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
    try {
      await _friendsService.blockFriend(friend.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName님을 차단했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('차단 실패: $e')));
      }
    }
  }

  // ─── Add friend dialog ────────────────────────────────────────────────────

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    List<MyUser> results = [];
    bool isSearching = false;
    String? feedbackMessage;
    bool feedbackIsError = false;

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              Future<void> runSearch(String query) async {
                if (query.trim().isEmpty) {
                  setDialogState(() {
                    results = [];
                    isSearching = false;
                  });
                  return;
                }
                setDialogState(() => isSearching = true);
                final found = await _searchUsersByAny(query.trim());
                setDialogState(() {
                  results = found;
                  isSearching = false;
                });
              }

              Future<void> addFriend(MyUser user) async {
                setDialogState(() => feedbackMessage = null);
                final success = await _friendsService.addFriend(user.name);
                setDialogState(() {
                  if (success) {
                    feedbackMessage = '${user.name}님과 친구가 되었습니다!';
                    feedbackIsError = false;
                    results.removeWhere((u) => u.userId == user.userId);
                  } else {
                    feedbackMessage = '친구 추가에 실패했습니다.';
                    feedbackIsError = true;
                  }
                });
              }

              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 60,
                  bottom: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '친구 추가',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[300],
                            ),
                            child: TextField(
                              controller: controller,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: '이름, 전화번호, 이메일',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                suffixIcon:
                                    isSearching
                                        ? Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.black,
                                                ),
                                          ),
                                        )
                                        : Icon(
                                          Icons.search,
                                          size: 22,
                                          color: Colors.black,
                                        ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: runSearch,
                            ),
                          ),
                          if (feedbackMessage != null) ...[
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  feedbackIsError
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  size: 14,
                                  color:
                                      feedbackIsError
                                          ? Colors.red
                                          : Colors.green[700],
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    feedbackMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          feedbackIsError
                                              ? Colors.red
                                              : Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 260),
                          child:
                              results.isNotEmpty
                                  ? Column(
                                    children: List.generate(results.length, (
                                      index,
                                    ) {
                                      final user = results[index];
                                      return Column(
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: () => addFriend(user),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 4,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 22,
                                                    backgroundImage:
                                                        user.url.isNotEmpty
                                                            ? NetworkImage(
                                                              user.url,
                                                            )
                                                            : null,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    child:
                                                        user.url.isEmpty
                                                            ? Icon(
                                                              Icons.person,
                                                              size: 22,
                                                              color:
                                                                  Colors.grey,
                                                            )
                                                            : null,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          user.name,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        if (user.bio != null &&
                                                            user
                                                                .bio!
                                                                .isNotEmpty)
                                                          Text(
                                                            user.bio!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.person_add_outlined,
                                                    size: 20,
                                                    color: Colors.grey[400],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (index < results.length - 1)
                                            Divider(
                                              height: 1,
                                              color: Colors.grey[100],
                                            ),
                                        ],
                                      );
                                    }),
                                  )
                                  : SizedBox(
                                    height: 260,
                                    child: Center(
                                      child: Text(
                                        controller.text.isNotEmpty &&
                                                !isSearching
                                            ? '검색 결과가 없습니다'
                                            : '이름, 전화번호 또는 이메일로\n친구를 검색해보세요',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            '닫기',
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // ─── Create group dialog ──────────────────────────────────────────────────

  Future<void> _showCreateGroupDialog({
    required Map<String, String> aliases,
  }) async {
    final nameController = TextEditingController();
    final searchCtrl = TextEditingController();
    List<String> selectedUserIds = [];
    String? groupImagePath;
    String groupSearch = '';
    final friends = await _friendsService.getFriendsStream().first;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredFriends =
                  groupSearch.isEmpty
                      ? friends
                      : friends.where((u) {
                        final q = groupSearch.toLowerCase();
                        final alias = aliases[u.userId]?.toLowerCase() ?? '';
                        return u.name.toLowerCase().contains(q) ||
                            alias.contains(q);
                      }).toList();

              final selectedFriends =
                  friends
                      .where((u) => selectedUserIds.contains(u.userId))
                      .toList();

              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 60,
                  bottom: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 12),
                      child: Text(
                        '채팅방 만들기',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Group image picker ──
                            GestureDetector(
                              onTap: () async {
                                groupImagePath =
                                    await uploadImageToFirebaseStorageHome();
                                setDialogState(() {});
                              },
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[200],
                                backgroundImage:
                                    groupImagePath != null
                                        ? NetworkImage(groupImagePath!)
                                        : null,
                                child:
                                    groupImagePath == null
                                        ? Icon(
                                          Icons.image_outlined,
                                          size: 32,
                                          color: Colors.grey[400],
                                        )
                                        : null,
                              ),
                            ),
                            SizedBox(height: 10),

                            // ── Group name field ──
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: TextField(
                                controller: nameController,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: '채팅방 이름',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black),
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // ── Selected friends horizontal chips ──
                            if (selectedFriends.isNotEmpty) ...[
                              SizedBox(
                                height: 90,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const ClampingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: selectedFriends.length,
                                  itemBuilder: (context, idx) {
                                    final user = selectedFriends[idx];
                                    final displayName =
                                        aliases[user.userId] ?? user.name;
                                    final hasAlias =
                                        aliases.containsKey(user.userId) &&
                                        aliases[user.userId]!.isNotEmpty;

                                    return Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: SizedBox(
                                        width: 54,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundImage:
                                                      user.url.isNotEmpty
                                                          ? NetworkImage(
                                                            user.url,
                                                          )
                                                          : null,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  child:
                                                      user.url.isEmpty
                                                          ? Text(
                                                            user.name.isNotEmpty
                                                                ? user.name[0]
                                                                : '?',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          )
                                                          : null,
                                                ),
                                                Positioned(
                                                  top: -4,
                                                  right: -4,
                                                  child: GestureDetector(
                                                    onTap:
                                                        () => setDialogState(
                                                          () => selectedUserIds
                                                              .remove(
                                                                user.userId,
                                                              ),
                                                        ),
                                                    child: Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.black,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 10,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              displayName,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (hasAlias)
                                              Text(
                                                user.name,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[400],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 8),
                            ],

                            // ── Search field ──
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextField(
                                  controller: searchCtrl,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '이름 또는 별명으로 검색',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.search,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged:
                                      (val) => setDialogState(
                                        () => groupSearch = val,
                                      ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),

                            Padding(
                              padding: EdgeInsets.only(left: 16, bottom: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '친구',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            // ── Friends list ──
                            if (filteredFriends.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    groupSearch.isNotEmpty
                                        ? '검색 결과가 없습니다'
                                        : '친구가 없습니다',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children:
                                    filteredFriends.map((user) {
                                      final isSelected = selectedUserIds
                                          .contains(user.userId);
                                      final displayName =
                                          aliases[user.userId] ?? user.name;
                                      final hasAlias =
                                          aliases.containsKey(user.userId) &&
                                          aliases[user.userId]!.isNotEmpty;

                                      return InkWell(
                                        onTap:
                                            () => setDialogState(() {
                                              if (isSelected) {
                                                selectedUserIds.remove(
                                                  user.userId,
                                                );
                                              } else {
                                                selectedUserIds.add(
                                                  user.userId,
                                                );
                                              }
                                            }),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? Colors.black
                                                            : Colors
                                                                .transparent,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 22,
                                                  backgroundImage:
                                                      user.url.isNotEmpty
                                                          ? NetworkImage(
                                                            user.url,
                                                          )
                                                          : null,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  child:
                                                      user.url.isEmpty
                                                          ? Text(
                                                            user.name.isNotEmpty
                                                                ? user.name[0]
                                                                : '?',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          )
                                                          : null,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    groupSearch.isNotEmpty
                                                        ? _buildHighlightedName(
                                                          displayName,
                                                          groupSearch,
                                                        )
                                                        : Text(
                                                          displayName,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                    if (hasAlias)
                                                      Text(
                                                        user.name,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[400],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      isSelected
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? Colors.black
                                                            : Colors.grey[400]!,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child:
                                                    isSelected
                                                        ? Icon(
                                                          Icons.check,
                                                          size: 13,
                                                          color: Colors.white,
                                                        )
                                                        : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom buttons ──
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[100]!, width: 1),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  selectedUserIds.isEmpty
                                      ? Colors.grey[300]
                                      : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                            ),
                            onPressed:
                                selectedUserIds.isEmpty
                                    ? null
                                    : () async {
                                      Navigator.pop(ctx);
                                      await _chatService.createGroupChatRoom(
                                        name: nameController.text,
                                        participantIds: selectedUserIds,
                                        groupImage: groupImagePath,
                                      );
                                    },
                            child: Text(
                              '생성',
                              style: TextStyle(
                                color:
                                    selectedUserIds.isEmpty
                                        ? Colors.grey[500]
                                        : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // ─── Current user card ────────────────────────────────────────────────────

  Widget _buildCurrentUserCard() {
    if (_isLoadingUser) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_currentUser == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showBioEditDialog,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      _currentUser!.url.isNotEmpty
                          ? NetworkImage(_currentUser!.url)
                          : null,
                  backgroundColor: Colors.grey[200],
                  child:
                      _currentUser!.url.isEmpty
                          ? Icon(Icons.person, color: Colors.grey, size: 28)
                          : null,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser!.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        (_currentUser!.bio != null &&
                                _currentUser!.bio!.isNotEmpty)
                            ? _currentUser!.bio!
                            : '상태 메시지',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (_currentUser!.bio != null &&
                                      _currentUser!.bio!.isNotEmpty)
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: '채팅방 만들기',
                onTap: () => _showCreateGroupDialog(aliases: _latestAliases),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.person_add_outlined,
                label: '친구 추가',
                onTap: _showAddFriendDialog,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String label,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              '$label $count',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search results view ──────────────────────────────────────────────────

  Widget _buildSearchResults(
    List<MyUser> allFriends,
    List<MyUser> allBrands,
    List<String> favoriteIds,
    Map<String, String> aliases,
  ) {
    final query = _effectiveQuery.toLowerCase();
    final matchingFriends =
        allFriends
            .where(
              (u) =>
                  u.name.toLowerCase().contains(query) ||
                  (aliases[u.userId]?.toLowerCase().contains(query) ?? false),
            )
            .toList();
    final matchingBrands =
        allBrands.where((u) => u.name.toLowerCase().contains(query)).toList();

    if (matchingFriends.isEmpty && matchingBrands.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
              SizedBox(height: 12),
              Text(
                '검색 결과가 없습니다',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (matchingFriends.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              '친구 ${matchingFriends.length}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...matchingFriends.map(
            (f) => _buildFriendItem(
              friend: f,
              favoriteIds: favoriteIds,
              aliases: aliases,
            ),
          ),
        ],
        if (matchingBrands.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              '브랜드 ${matchingBrands.length}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...matchingBrands.map(
            (b) => _buildFriendItem(
              friend: b,
              isBrand: true,
              favoriteIds: favoriteIds,
              aliases: aliases,
            ),
          ),
        ],
        SizedBox(height: 40),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: StreamBuilder<Map<String, int>>(
        stream: _getFavoritesOrderStream(),
        builder: (context, orderSnapshot) {
          final favoritesOrder = orderSnapshot.data ?? {};

          return StreamBuilder<List<String>>(
            stream: _favoritesService.getFavoriteIdsStream(),
            builder: (context, favSnapshot) {
              final favoriteIds = favSnapshot.data ?? [];

              return StreamBuilder<Set<String>>(
                stream: _getFollowingIdsStream(),
                builder: (context, followingSnapshot) {
                  final followingIds = followingSnapshot.data ?? {};

                  return StreamBuilder<Set<String>>(
                    stream: _getHiddenIdsStream(),
                    builder: (context, hiddenSnapshot) {
                      final hiddenIds = hiddenSnapshot.data ?? {};

                      return StreamBuilder<Map<String, String>>(
                        stream: _getAliasesStream(),
                        builder: (context, aliasSnapshot) {
                          final aliases = aliasSnapshot.data ?? {};
                          _latestAliases = aliases;

                          return StreamBuilder<List<MyUser>>(
                            stream: _friendsService.getFriendsStream(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || _isSyncing) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final allUsers = snapshot.data ?? [];
                              final allFriends =
                                  allUsers
                                      .where(
                                        (u) =>
                                            u.type == 'user' &&
                                            !hiddenIds.contains(u.userId),
                                      )
                                      .toList();

                              final favorites =
                                  allFriends
                                      .where(
                                        (u) => favoriteIds.contains(u.userId),
                                      )
                                      .toList()
                                    ..sort((a, b) {
                                      final aO =
                                          favoritesOrder[a.userId] ?? 999999;
                                      final bO =
                                          favoritesOrder[b.userId] ?? 999999;
                                      return aO.compareTo(bO);
                                    });

                              final subscribed =
                                  allFriends
                                      .where(
                                        (u) => followingIds.contains(u.userId),
                                      )
                                      .toList();

                              final friends = allFriends;

                              return StreamBuilder(
                                stream: _friendsService.getBrandsStream(),
                                builder: (context, brandSnapshot) {
                                  final allBrands =
                                      (brandSnapshot.data ?? [])
                                          as List<MyUser>;
                                  final brands =
                                      allBrands
                                          .where(
                                            (b) =>
                                                !hiddenIds.contains(b.userId),
                                          )
                                          .toList();

                                  if (_isSearchActive) {
                                    return _buildSearchResults(
                                      allFriends,
                                      brands,
                                      favoriteIds,
                                      aliases,
                                    );
                                  }

                                  return ListView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    children: [
                                      _buildCurrentUserCard(),

                                      // ── 즐겨찾기 ──────────────────────────
                                      _buildSectionHeader(
                                        label: '즐겨찾기',
                                        count: favorites.length,
                                        expanded: _favoritesExpanded,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _favoritesExpanded =
                                                      !_favoritesExpanded,
                                            ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        crossFadeState:
                                            _favoritesExpanded
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild:
                                            favorites.isEmpty
                                                ? Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 12,
                                                    left: 4,
                                                  ),
                                                  child: Text(
                                                    '즐겨찾기한 친구가 없습니다',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                )
                                                : Column(
                                                  children:
                                                      favorites
                                                          .map(
                                                            (
                                                              f,
                                                            ) => _buildFriendItem(
                                                              friend: f,
                                                              favoriteIds:
                                                                  favoriteIds,
                                                              aliases: aliases,
                                                            ),
                                                          )
                                                          .toList(),
                                                ),
                                        secondChild: const SizedBox.shrink(),
                                      ),

                                      // ── 내가 구독한 친구 ──────────────────
                                      _buildSectionHeader(
                                        label: '내가 구독한 친구',
                                        count: subscribed.length,
                                        expanded: _subscribedExpanded,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _subscribedExpanded =
                                                      !_subscribedExpanded,
                                            ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        crossFadeState:
                                            _subscribedExpanded
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild:
                                            subscribed.isEmpty
                                                ? Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 12,
                                                    left: 4,
                                                  ),
                                                  child: Text(
                                                    '구독한 친구가 없습니다',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                )
                                                : Column(
                                                  children:
                                                      subscribed
                                                          .map(
                                                            (
                                                              f,
                                                            ) => _buildFriendItem(
                                                              friend: f,
                                                              favoriteIds:
                                                                  favoriteIds,
                                                              aliases: aliases,
                                                            ),
                                                          )
                                                          .toList(),
                                                ),
                                        secondChild: const SizedBox.shrink(),
                                      ),

                                      // ── 친구 ──────────────────────────────
                                      _buildSectionHeader(
                                        label: '친구',
                                        count: friends.length,
                                        expanded: _friendsExpanded,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _friendsExpanded =
                                                      !_friendsExpanded,
                                            ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        crossFadeState:
                                            _friendsExpanded
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild: Column(
                                          children:
                                              friends
                                                  .map(
                                                    (
                                                      friend,
                                                    ) => _buildFriendItem(
                                                      friend: friend,
                                                      showCheckbox: editMode,
                                                      favoriteIds: favoriteIds,
                                                      aliases: aliases,
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                        secondChild: const SizedBox.shrink(),
                                      ),

                                      // ── 브랜드 ────────────────────────────
                                      _buildSectionHeader(
                                        label: '브랜드',
                                        count: brands.length,
                                        expanded: _brandsExpanded,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _brandsExpanded =
                                                      !_brandsExpanded,
                                            ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        crossFadeState:
                                            _brandsExpanded
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild: Column(
                                          children:
                                              brands
                                                  .map(
                                                    (b) => _buildFriendItem(
                                                      friend: b,
                                                      isBrand: true,
                                                      showCheckbox: editMode,
                                                      favoriteIds: favoriteIds,
                                                      aliases: aliases,
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                        secondChild: const SizedBox.shrink(),
                                      ),

                                      SizedBox(height: 40),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── Friend item ──────────────────────────────────────────────────────────

  Widget _buildFriendItem({
    required MyUser friend,
    required List<String> favoriteIds,
    required Map<String, String> aliases,
    bool showCheckbox = false,
    bool isBrand = false,
  }) {
    // Each call gets its own LayerLink — safe because _buildFriendItem
    // is only ever called from build(), so the link lives as long as
    // the widget subtree does.
    final LayerLink layerLink = LayerLink();

    final bool isFav = favoriteIds.contains(friend.userId);
    final String displayName = aliases[friend.userId] ?? friend.name;
    final bool hasAlias =
        aliases.containsKey(friend.userId) &&
        aliases[friend.userId]!.isNotEmpty;

    void showFriendMenu() {
      if (isBrand) return;

      // Dismiss any menu that's already open
      _dismissActiveMenu();

      _activeMenuOverlay = OverlayEntry(
        builder: (overlayContext) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          const double popupWidth = 220;
          const double popupHeight = 380;

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

              // ── Popup anchored to the list item ──────────────────────────
              CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                // Nudge right 55, up 60 — same intent as original left/top math
                offset: const Offset(55, -60),
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
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            if (hasAlias) ...[
                              const SizedBox(height: 2),
                              Text(
                                friend.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Divider(
                              color: Colors.grey[200],
                              thickness: 1,
                              height: 1,
                            ),
                            _buildMenuOption(
                              label: isFav ? '즐겨찾기 해제' : '즐겨찾기 추가',
                              labelColor:
                                  isFav ? Colors.amber[800] : Colors.black,
                              onTap: () async {
                                _dismissActiveMenu();
                                if (isFav) {
                                  await _favoritesService.removeFavorite(
                                    friend.userId,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$displayName님을 즐겨찾기에서 제거했습니다',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  await _favoritesService.addFavorite(
                                    friend.userId,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$displayName님을 즐겨찾기에 추가했습니다',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            _buildMenuOption(
                              label: '이름 변경',
                              onTap: () {
                                _dismissActiveMenu();
                                _showChangeNameDialog(
                                  friend,
                                  aliases[friend.userId],
                                );
                              },
                            ),
                            _buildMenuOption(
                              label: '숨김',
                              onTap: () {
                                _dismissActiveMenu();
                                _hideFriend(friend);
                              },
                            ),
                            _buildMenuOption(
                              label: '삭제',
                              labelColor: Colors.red[600],
                              onTap: () {
                                _dismissActiveMenu();
                                _deleteFriend(friend);
                              },
                            ),
                            _buildMenuOption(
                              label: '차단',
                              labelColor: Colors.red[800],
                              onTap: () {
                                _dismissActiveMenu();
                                _blockFriend(friend);
                              },
                              isLast: true,
                            ),
                            const SizedBox(height: 12),
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

    // CompositedTransformTarget replaces the old `key: itemKey` Container.
    // Everything inside is byte-for-byte identical to the original.
    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () async {
            try {
              final chatRoomId = await _chatService.createDirectChatRoom(
                friend.userId,
                isBrand,
              );
              if (chatRoomId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChatScreen(
                          chatRoomId: chatRoomId,
                          chatRoomName: displayName,
                        ),
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          onLongPress: showFriendMenu,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(friend.url),
                  ),
                  if (isFav)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isSearchActive
                        ? _buildHighlightedName(displayName, _effectiveQuery)
                        : Row(
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            if (hasAlias) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${friend.name})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                    if (friend.bio != null && friend.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        friend.bio ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showCheckbox)
                StatefulBuilder(
                  builder: (context, checkboxState) {
                    return Checkbox(
                      value: selectedChatIds.contains(friend.userId),
                      onChanged:
                          (checked) => checkboxState(() {
                            if (checked ?? false)
                              selectedChatIds.add(friend.userId);
                            else
                              selectedChatIds.remove(friend.userId);
                          }),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Highlighted name text (for search) ──────────────────────────────────

  Widget _buildHighlightedName(String name, String query) {
    final lowerName = name.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerName.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
        children: [
          if (matchIndex > 0) TextSpan(text: name.substring(0, matchIndex)),
          TextSpan(
            text: name.substring(matchIndex, matchIndex + query.length),
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (matchIndex + query.length < name.length)
            TextSpan(text: name.substring(matchIndex + query.length)),
        ],
      ),
    );
  }

  // ─── Menu option ──────────────────────────────────────────────────────────

  Widget _buildMenuOption({
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: labelColor ?? Colors.black,
                ),
              ),
            ),
          ),
          if (!isLast)
            Divider(color: Colors.grey[200], thickness: 1, height: 1),
        ],
      ),
    );
  }
}

// ─── _ClampedMenu ─────────────────────────────────────────────────────────────
//
// Wraps the popup and, after the first frame, applies a translation to
// keep it fully within the screen bounds — replicating the original
// left/top clamping logic but done post-layout (the only correct way on web).

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

      // Right edge
      if (pos.dx + widget.popupWidth > widget.screenWidth - 12) {
        dx = (widget.screenWidth - 12) - (pos.dx + widget.popupWidth);
      }
      // Left edge
      if (pos.dx + dx < 8) dx = 8 - pos.dx;

      // Bottom edge
      if (pos.dy + widget.popupHeight > widget.screenHeight - 20) {
        dy = (widget.screenHeight - 20) - (pos.dy + widget.popupHeight);
      }
      // Top edge
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
