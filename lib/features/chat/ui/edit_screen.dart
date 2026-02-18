// features/chat/ui/edit_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/models/chat_room_model.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/services/favorites_service.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class EditScreen extends StatefulWidget {
  /// 0 = 연락처, 1 = 1:1채팅, 2 = 그룹채팅
  final int initialTab;

  const EditScreen({super.key, this.initialTab = 0});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late int _selectedTab;
  final List<String> _tabs = ['연락처', '1:1채팅', '그룹채팅'];

  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Pills ─────────────────────────────────────────────────────────────────
  Widget _buildPill(int index) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          _tabs[index],
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsManager.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pills row ────────────────────────────────────────────────────
            Container(
              color: ColorsManager.primary,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < _tabs.length; i++) ...[
                            _buildPill(i),
                            if (i < _tabs.length - 1) SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────────
            Container(
              color: ColorsManager.primary,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 14, color: Colors.black),
                  decoration: InputDecoration(
                    hintText:
                        _selectedTab == 0
                            ? '이름(초성), 전화번호 검색'
                            : _selectedTab == 1
                            ? '1:1채팅 검색'
                            : '그룹채팅 검색',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                    suffixIcon:
                        _query.isNotEmpty
                            ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            )
                            : null,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onChanged:
                      (val) =>
                          setState(() => _query = val.toLowerCase().trim()),
                ),
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────────
            Container(color: Colors.grey[300], height: 1),

            // ── Tab content ──────────────────────────────────────────────────
            Expanded(
              child: ColoredBox(
                color: ColorsManager.primary,
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _ContactsEditTab(query: _query),
                    _DirectChatsEditTab(query: _query),
                    _GroupChatsEditTab(query: _query),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 0 — 연락처 edit  (with alias support)
// ═══════════════════════════════════════════════════════════════════════════

class _ContactsEditTab extends StatefulWidget {
  final String query;
  const _ContactsEditTab({required this.query});

  @override
  State<_ContactsEditTab> createState() => _ContactsEditTabState();
}

class _ContactsEditTabState extends State<_ContactsEditTab> {
  final FriendsService _friendsService = FriendsService();
  final FavoritesService _favoritesService = FavoritesService();

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<String>> get _favoriteIdsStream =>
      _favoritesService.getFavoriteIdsStream();

  /// userId → alias string (only entries where alias is non-empty)
  Stream<Map<String, String>> get _aliasesStream {
    if (uid.isEmpty) return Stream.value({});
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

  Stream<Set<String>> get _hiddenIdsStream {
    if (uid.isEmpty) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hiddenFriends')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Stream<List<String>> get _blockedIdsStream {
    if (uid.isEmpty) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => List<String>.from(d.data()?['blocked'] ?? []));
  }

  Stream<Map<String, int>> get _favoriteOrderStream {
    if (uid.isEmpty) return Stream.value({});
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

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _removeFavorite(String userId) async {
    await _favoritesService.removeFavorite(userId);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'favoritesOrder.$userId': FieldValue.delete(),
    });
  }

  Future<void> _unhide(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hiddenFriends')
        .doc(userId)
        .delete();
  }

  Future<void> _hide(MyUser friend) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hiddenFriends')
        .doc(friend.userId)
        .set({'hiddenAt': FieldValue.serverTimestamp()});
  }

  Future<void> _unblock(String blockedUserId) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'blocked': FieldValue.arrayRemove([blockedUserId]),
    });
  }

  Future<void> _reorderFavorites(List<MyUser> newOrder) async {
    final orderMap = <String, int>{};
    for (int i = 0; i < newOrder.length; i++) {
      orderMap[newOrder[i].userId] = i;
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'favoritesOrder': orderMap,
    });
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// A standard friend row that respects aliases.
  /// [aliases] is optional — pass it for friends; omit for blocked users
  /// who are no longer in the friends list.
  Widget _friendRow({
    required MyUser user,
    required Widget trailing,
    Map<String, String> aliases = const {},
  }) {
    final displayName = aliases[user.userId] ?? user.name;
    final hasAlias =
        aliases.containsKey(user.userId) && aliases[user.userId]!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                user.url.isNotEmpty ? NetworkImage(user.url) : null,
            backgroundColor: Colors.grey[200],
            child:
                user.url.isEmpty
                    ? Icon(Icons.person, size: 20, color: Colors.grey)
                    : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                if (hasAlias)
                  Text(
                    user.name,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: color ?? Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;

    // Outermost stream: aliases (used for display + search)
    return StreamBuilder<Map<String, String>>(
      stream: _aliasesStream,
      builder: (ctx, aliasSnap) {
        final aliases = aliasSnap.data ?? {};

        return StreamBuilder<List<String>>(
          stream: _favoriteIdsStream,
          builder: (ctx, favSnap) {
            final favIds = favSnap.data ?? [];

            return StreamBuilder<Map<String, int>>(
              stream: _favoriteOrderStream,
              builder: (ctx, orderSnap) {
                final orderMap = orderSnap.data ?? {};

                return StreamBuilder<Set<String>>(
                  stream: _hiddenIdsStream,
                  builder: (ctx, hiddenSnap) {
                    final hiddenIds = hiddenSnap.data ?? {};

                    return StreamBuilder<List<String>>(
                      stream: _blockedIdsStream,
                      builder: (ctx, blockedSnap) {
                        final blockedIds = blockedSnap.data ?? [];

                        return StreamBuilder<List<MyUser>>(
                          stream: _friendsService.getFriendsStream(),
                          builder: (ctx, friendsSnap) {
                            if (!friendsSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allFriends =
                                friendsSnap.data!
                                    .where((u) => u.type == 'user')
                                    .toList();

                            // Search matches real name OR alias
                            final filtered =
                                q.isEmpty
                                    ? allFriends
                                    : allFriends.where((u) {
                                      final alias =
                                          aliases[u.userId]?.toLowerCase() ??
                                          '';
                                      return u.name.toLowerCase().contains(q) ||
                                          alias.contains(q);
                                    }).toList();

                            final favorites =
                                filtered
                                    .where(
                                      (u) =>
                                          favIds.contains(u.userId) &&
                                          !hiddenIds.contains(u.userId),
                                    )
                                    .toList()
                                  ..sort((a, b) {
                                    final aO = orderMap[a.userId] ?? 999999;
                                    final bO = orderMap[b.userId] ?? 999999;
                                    return aO.compareTo(bO);
                                  });

                            final friends =
                                filtered
                                    .where(
                                      (u) =>
                                          !favIds.contains(u.userId) &&
                                          !hiddenIds.contains(u.userId),
                                    )
                                    .toList();

                            final hiddenUsers =
                                filtered
                                    .where((u) => hiddenIds.contains(u.userId))
                                    .toList();

                            return FutureBuilder<List<MyUser>>(
                              future: _fetchBlockedUsers(blockedIds),
                              builder: (ctx, blockedUsersSnap) {
                                final blockedUsers =
                                    blockedUsersSnap.data ?? [];

                                return ListView(
                                  children: [
                                    // ── 즐겨찾기 (REORDERABLE) ──────────────
                                    if (favorites.isNotEmpty) ...[
                                      _sectionHeader('즐겨찾기'),
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        itemCount: favorites.length,
                                        proxyDecorator:
                                            (child, index, animation) =>
                                                Material(
                                                  color: ColorsManager.primary,
                                                  child: child,
                                                ),
                                        onReorder: (oldIdx, newIdx) {
                                          final reordered = List<MyUser>.from(
                                            favorites,
                                          );
                                          if (newIdx > oldIdx) newIdx--;
                                          final item = reordered.removeAt(
                                            oldIdx,
                                          );
                                          reordered.insert(newIdx, item);
                                          _reorderFavorites(reordered);
                                        },
                                        itemBuilder: (ctx, index) {
                                          final u = favorites[index];
                                          final displayName =
                                              aliases[u.userId] ?? u.name;
                                          final hasAlias =
                                              aliases.containsKey(u.userId) &&
                                              aliases[u.userId]!.isNotEmpty;

                                          return Container(
                                            key: ValueKey(u.userId),
                                            color: ColorsManager.primary,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 22,
                                                    backgroundImage:
                                                        u.url.isNotEmpty
                                                            ? NetworkImage(
                                                              u.url,
                                                            )
                                                            : null,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    child:
                                                        u.url.isEmpty
                                                            ? Icon(
                                                              Icons.person,
                                                              size: 20,
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
                                                          displayName,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        if (hasAlias)
                                                          Text(
                                                            u.name,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors
                                                                      .grey[400],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  _pillButton(
                                                    '해제',
                                                    () => _removeFavorite(
                                                      u.userId,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: Icon(
                                                      Icons.drag_handle,
                                                      color: Colors.grey[400],
                                                      size: 20,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],

                                    // ── 친구 ───────────────────────────────
                                    if (friends.isNotEmpty) ...[
                                      _sectionHeader('친구'),
                                      ...friends.map(
                                        (u) => _friendRow(
                                          user: u,
                                          aliases: aliases,
                                          trailing: _pillButton(
                                            '숨김',
                                            () => _hide(u),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // ── 숨긴 친구 ───────────────────────────
                                    if (hiddenUsers.isNotEmpty) ...[
                                      _sectionHeader('숨긴 친구'),
                                      ...hiddenUsers.map(
                                        (u) => _friendRow(
                                          user: u,
                                          aliases: aliases,
                                          trailing: _pillButton(
                                            '해제',
                                            () => _unhide(u.userId),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // ── 차단된 친구 ─────────────────────────
                                    // Blocked users are shown with real names
                                    // (no alias — they may no longer be friends)
                                    if (blockedUsers.isNotEmpty) ...[
                                      _sectionHeader('차단된 친구'),
                                      ...blockedUsers.map(
                                        (u) => _friendRow(
                                          user: u,
                                          trailing: _pillButton(
                                            '해제',
                                            () => _unblock(u.userId),
                                            color: Colors.red[400],
                                          ),
                                        ),
                                      ),
                                    ],

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
    );
  }

  Future<List<MyUser>> _fetchBlockedUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
          if (doc.exists) return MyUser.fromDocument(doc.data()!);
        } catch (_) {}
        return null;
      }),
    );
    return results.whereType<MyUser>().toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — 1:1채팅 edit  (with alias support)
// ═══════════════════════════════════════════════════════════════════════════

class _DirectChatsEditTab extends StatefulWidget {
  final String query;
  const _DirectChatsEditTab({required this.query});

  @override
  State<_DirectChatsEditTab> createState() => _DirectChatsEditTabState();
}

class _DirectChatsEditTabState extends State<_DirectChatsEditTab> {
  final ChatService _chatService = ChatService();

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Live alias map — kept up to date via a Firestore listener
  Map<String, String> _aliases = {};

  // Selection persists regardless of search query
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _subscribeAliases();
  }

  // Listen to aliases subcollection so the list updates in real time
  // without needing a full rebuild chain.
  void _subscribeAliases() {
    if (uid.isEmpty) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('aliases')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final map = <String, String>{};
          for (final doc in snap.docs) {
            final alias = doc.data()['alias'] as String?;
            if (alias != null && alias.isNotEmpty) map[doc.id] = alias;
          }
          setState(() => _aliases = map);
        });
  }

  Future<MyUser?> _getOtherUser(ChatRoomModel chat) async {
    final otherId = chat.participants.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    if (otherId.isEmpty) return null;
    try {
      final collection = chat.type == 'seller' ? 'deliveryManagers' : 'users';
      final doc =
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(otherId)
              .get();
      if (!doc.exists) return null;
      return chat.type == 'seller'
          ? MyUser.fromSellerDocument(doc.data()!)
          : MyUser.fromDocument(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _leaveSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await _showConfirmDialog(
      '${_selected.length}개의 채팅방을 나가시겠습니까?',
    );
    if (confirm != true) return;
    for (final id in _selected) {
      await _chatService.softDeleteChatForCurrentUser(id);
    }
    setState(() => _selected.clear());
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
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
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black),
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
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatRoomModel>>(
            stream: _chatService.getChatRoomsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allChats =
                  snapshot.data!
                      .where(
                        (c) =>
                            (c.type == 'direct' ||
                                c.type == 'seller' ||
                                c.type == 'admin' ||
                                c.type == '' ||
                                c.type == null) &&
                            !c.deletedBy.contains(uid) &&
                            c.lastMessage != null &&
                            c.lastMessage!.isNotEmpty,
                      )
                      .toList();

              if (allChats.isEmpty) {
                return Center(
                  child: Text(
                    '채팅이 없습니다',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                );
              }

              return ListView.builder(
                itemCount: allChats.length,
                itemBuilder: (ctx, i) {
                  final chat = allChats[i];
                  final isSelected = _selected.contains(chat.id);

                  return FutureBuilder<MyUser?>(
                    future: _getOtherUser(chat),
                    builder: (ctx, userSnap) {
                      // Resolve the other participant's ID for alias lookup
                      final otherId = chat.participants.firstWhere(
                        (id) => id != uid,
                        orElse: () => '',
                      );

                      final realName =
                          userSnap.data?.name ?? chat.name ?? '알 수 없음';
                      final avatarUrl = userSnap.data?.url ?? '';

                      // Use alias if one exists for this participant
                      final displayName = _aliases[otherId] ?? realName;
                      final hasAlias =
                          _aliases.containsKey(otherId) &&
                          _aliases[otherId]!.isNotEmpty;

                      // Search: match alias OR real name OR last message
                      if (q.isNotEmpty &&
                          !displayName.toLowerCase().contains(q) &&
                          !realName.toLowerCase().contains(q) &&
                          !(chat.lastMessage ?? '').toLowerCase().contains(q)) {
                        return const SizedBox.shrink();
                      }

                      return InkWell(
                        onTap:
                            () => setState(() {
                              if (isSelected)
                                _selected.remove(chat.id);
                              else
                                _selected.add(chat.id);
                            }),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // ── Select circle ──
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
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
                              SizedBox(width: 12),

                              // ── Avatar ──
                              CircleAvatar(
                                radius: 22,
                                backgroundImage:
                                    avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                backgroundColor: Colors.grey[200],
                                child:
                                    avatarUrl.isEmpty
                                        ? Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.grey,
                                        )
                                        : null,
                              ),
                              SizedBox(width: 12),

                              // ── Name (alias + real name subtitle) ──
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                    // Show real name as grey subtitle when alias is active
                                    if (hasAlias)
                                      Text(
                                        realName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[400],
                                        ),
                                      )
                                    else if (chat.lastMessage?.isNotEmpty ==
                                        true)
                                      Text(
                                        chat.lastMessage!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    // Show last message below real-name subtitle
                                    if (hasAlias &&
                                        chat.lastMessage?.isNotEmpty == true)
                                      Text(
                                        chat.lastMessage!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              // ── Unread dot ──
                              if ((chat.unreadCount[uid] ?? 0) > 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: EdgeInsets.only(right: 4),
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        _BottomBar(
          onDeselectAll: () => setState(() => _selected.clear()),
          onLeave: _leaveSelected,
          hasSelection: _selected.isNotEmpty,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — 그룹채팅 edit  (unchanged — group chats have no aliases)
// ═══════════════════════════════════════════════════════════════════════════

class _GroupChatsEditTab extends StatefulWidget {
  final String query;
  const _GroupChatsEditTab({required this.query});

  @override
  State<_GroupChatsEditTab> createState() => _GroupChatsEditTabState();
}

class _GroupChatsEditTabState extends State<_GroupChatsEditTab> {
  final ChatService _chatService = ChatService();
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final Set<String> _selected = {};

  Stream<Map<String, int>> get _groupOrderStream {
    if (uid.isEmpty) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return <String, int>{};
          final raw = snap.data()?['groupChatsOrder'];
          if (raw == null) return <String, int>{};
          return Map<String, int>.from(raw as Map);
        });
  }

  Future<void> _reorderGroups(List<ChatRoomModel> newOrder) async {
    final orderMap = <String, int>{};
    for (int i = 0; i < newOrder.length; i++) {
      orderMap[newOrder[i].id] = i;
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'groupChatsOrder': orderMap,
    });
  }

  Future<void> _leaveSelected() async {
    if (_selected.isEmpty) return;
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
                    '${_selected.length}개의 그룹채팅방을\n나가시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black),
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
    for (final id in _selected) {
      await _chatService.removeParticipantFromGroup(id, uid);
    }
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<Map<String, int>>(
            stream: _groupOrderStream,
            builder: (ctx, orderSnap) {
              final orderMap = orderSnap.data ?? {};
              return StreamBuilder<List<ChatRoomModel>>(
                stream: _chatService.getChatRoomsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allGroups =
                      snapshot.data!.where((c) => c.type == 'group').toList();

                  allGroups.sort((a, b) {
                    final aO = orderMap[a.id] ?? 999999;
                    final bO = orderMap[b.id] ?? 999999;
                    return aO.compareTo(bO);
                  });

                  final visibleGroups =
                      q.isEmpty
                          ? allGroups
                          : allGroups
                              .where(
                                (c) =>
                                    c.name.toLowerCase().contains(q) ||
                                    (c.lastMessage ?? '')
                                        .toLowerCase()
                                        .contains(q),
                              )
                              .toList();

                  if (visibleGroups.isEmpty) {
                    return Center(
                      child: Text(
                        q.isNotEmpty ? '검색 결과가 없습니다' : '그룹채팅이 없습니다',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    );
                  }

                  final bool canReorder = q.isEmpty;

                  return ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: visibleGroups.length,
                    proxyDecorator:
                        (child, index, animation) => Material(
                          color: ColorsManager.primary,
                          child: child,
                        ),
                    onReorder:
                        canReorder
                            ? (oldIdx, newIdx) {
                              final reordered = List<ChatRoomModel>.from(
                                allGroups,
                              );
                              if (newIdx > oldIdx) newIdx--;
                              final item = reordered.removeAt(oldIdx);
                              reordered.insert(newIdx, item);
                              _reorderGroups(reordered);
                            }
                            : (_, __) {},
                    itemBuilder: (ctx, i) {
                      final chat = visibleGroups[i];
                      final isSelected = _selected.contains(chat.id);

                      return Container(
                        key: ValueKey(chat.id),
                        color: ColorsManager.primary,
                        child: InkWell(
                          onTap:
                              () => setState(() {
                                if (isSelected)
                                  _selected.remove(chat.id);
                                else
                                  _selected.add(chat.id);
                              }),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
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
                                SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage:
                                      (chat.groupImage != null &&
                                              chat.groupImage!.isNotEmpty)
                                          ? NetworkImage(chat.groupImage!)
                                          : null,
                                  backgroundColor: Colors.grey[200],
                                  child:
                                      (chat.groupImage == null ||
                                              chat.groupImage!.isEmpty)
                                          ? Icon(
                                            Icons.group,
                                            size: 20,
                                            color: Colors.grey,
                                          )
                                          : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chat.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (chat.lastMessage?.isNotEmpty == true)
                                        Text(
                                          chat.lastMessage!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (canReorder)
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  )
                                else
                                  SizedBox(width: 24),
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
          ),
        ),
        _BottomBar(
          onDeselectAll: () => setState(() => _selected.clear()),
          onLeave: _leaveSelected,
          hasSelection: _selected.isNotEmpty,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared bottom bar
// ═══════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final VoidCallback onDeselectAll;
  final VoidCallback onLeave;
  final bool hasSelection;

  const _BottomBar({
    required this.onDeselectAll,
    required this.onLeave,
    required this.hasSelection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: hasSelection ? Colors.black : Colors.grey[100],
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onDeselectAll,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: Text(
                    '선택해제',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: hasSelection ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: hasSelection ? Colors.white24 : Colors.grey[300],
            ),
            Expanded(
              child: InkWell(
                onTap: hasSelection ? onLeave : null,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: Text(
                    '나가기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasSelection ? Colors.white : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
