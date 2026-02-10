import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Requests extends StatefulWidget {
  const Requests({super.key});

  @override
  State<Requests> createState() => _RequestsState();
}

class _RequestsState extends State<Requests> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  late Future<Map<String, Map<String, dynamic>>> _recommendationsFuture;
  bool _recommendationsInitialized = false;
  final ContactService _contactService = ContactService();
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    // Initialize recommendations future once on load
    _initializeRecommendations();
  }

  Future<void> _initializeRecommendations() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get initial following list
      final followingSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      // Compute recommendations ONCE and cache the Future (includes both recommendations and contacts)
      _recommendationsFuture = _buildFriendRecommendationsWithContacts(
        currentUser.uid,
        followingIds,
      );
      _recommendationsInitialized = true;

      // Trigger rebuild
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing recommendations: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Please sign in'));
    }

    return Column(
      children: [
        // Search field - sticky at the top
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '검색',
              prefixIcon: const Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentUserData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final isCurrentUserPrivate =
                    currentUserData['isPrivate'] ?? false;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===================== Section 1: 친구요청 (Only if PRIVATE) =====================
                    if (isCurrentUserPrivate)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text(
                          '친구요청',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    // Requests list - adapts to content, max 5 items with internal scroll
                    if (isCurrentUserPrivate)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 220),
                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .collection('followRequests')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final requests = snapshot.data?.docs ?? [];

                            if (requests.isEmpty) {
                              return Center(
                                child: Text(
                                  searchQuery.isNotEmpty
                                      ? '일치하는 요청이 없습니다'
                                      : '받은 요청이 없습니다',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            // Build map of requesting user IDs
                            final requestingUserIds =
                                requests.map((doc) => doc.id).toList();

                            // Stream all requesting users at once
                            return StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .where(
                                        FieldPath.documentId,
                                        whereIn: requestingUserIds,
                                      )
                                      .snapshots(),
                              builder: (context, usersSnapshot) {
                                if (!usersSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                // Build user map for quick lookup
                                final usersMap = <String, MyUser>{};
                                for (var doc in usersSnapshot.data!.docs) {
                                  final user = MyUser.fromDocument(
                                    doc.data() as Map<String, dynamic>,
                                  );
                                  usersMap[doc.id] = user;
                                }

                                // Filter by search query
                                final filteredRequests =
                                    requests.where((requestDoc) {
                                      final user = usersMap[requestDoc.id];
                                      if (user == null) return false;
                                      if (searchQuery.isEmpty) return true;
                                      return user.name.toLowerCase().contains(
                                        searchQuery,
                                      );
                                    }).toList();

                                return filteredRequests.isEmpty
                                    ? Center(
                                      child: Text(
                                        searchQuery.isNotEmpty
                                            ? '일치하는 요청이 없습니다'
                                            : '받은 요청이 없습니다',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: filteredRequests.length,
                                      itemBuilder: (context, index) {
                                        final requestDoc =
                                            filteredRequests[index];
                                        final requestingUserId = requestDoc.id;
                                        final requestingUser =
                                            usersMap[requestingUserId];

                                        if (requestingUser == null) {
                                          return const SizedBox.shrink();
                                        }

                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                // User avatar
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  child: Image.network(
                                                    requestingUser.url,
                                                    width: 48,
                                                    height: 48,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                // User info
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        requestingUser.name,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      if (requestingUser.bio !=
                                                              null &&
                                                          requestingUser
                                                              .bio!
                                                              .isNotEmpty)
                                                        Text(
                                                          requestingUser.bio!,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                // Accept button
                                                GestureDetector(
                                                  onTap: () async {
                                                    await _acceptFollowRequest(
                                                      context,
                                                      requestingUserId,
                                                      currentUser.uid,
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          ColorsManager
                                                              .primaryblack,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '수락',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                // Decline button
                                                GestureDetector(
                                                  onTap: () async {
                                                    await _declineFollowRequest(
                                                      context,
                                                      requestingUserId,
                                                      currentUser.uid,
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[300]!,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '거절',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
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

                    // ===================== Section 2: 친구추천 (Always shown) =====================
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        '친구추천(친구의 친구)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // Friend recommendations - adapts to content, max 5 items with internal scroll
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 220),
                      child:
                          _recommendationsInitialized
                              ? FutureBuilder<
                                Map<String, Map<String, dynamic>>
                              >(
                                future: _recommendationsFuture,
                                builder: (context, recommendationsSnapshot) {
                                  if (recommendationsSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  if (recommendationsSnapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Error: ${recommendationsSnapshot.error}',
                                      ),
                                    );
                                  }

                                  final recommendations =
                                      recommendationsSnapshot.data ?? {};

                                  // Filter by search query
                                  final filteredRecommendations =
                                      <String, Map<String, dynamic>>{};
                                  for (final entry in recommendations.entries) {
                                    final user = entry.value['user'] as MyUser;
                                    if (searchQuery.isEmpty) {
                                      filteredRecommendations[entry.key] =
                                          entry.value;
                                    } else if (user.name.toLowerCase().contains(
                                      searchQuery,
                                    )) {
                                      filteredRecommendations[entry.key] =
                                          entry.value;
                                    }
                                  }

                                  if (filteredRecommendations.isEmpty) {
                                    return Center(
                                      child: Text(
                                        searchQuery.isNotEmpty
                                            ? '일치하는 추천이 없습니다'
                                            : '추천할 친구가 없습니다',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: filteredRecommendations.length,
                                    itemBuilder: (context, index) {
                                      final userId =
                                          filteredRecommendations.keys
                                              .toList()[index];
                                      final data =
                                          filteredRecommendations[userId]!;
                                      final user = data['user'] as MyUser;
                                      final mutualCount = data['count'] as int;
                                      final isContact =
                                          data['isContact'] as bool? ?? false;
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              // User avatar
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                child: Image.network(
                                                  user.url,
                                                  width: 48,
                                                  height: 48,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              // User info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user.name,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      isContact
                                                          ? '연락처에서'
                                                          : '$mutualCount명의 친구를 팔로우 중',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // Follow button
                                              StreamBuilder<DocumentSnapshot>(
                                                stream:
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(currentUser.uid)
                                                        .collection('following')
                                                        .doc(userId)
                                                        .snapshots(),
                                                builder: (context, snapshot) {
                                                  final isFollowing =
                                                      snapshot.hasData &&
                                                      snapshot.data!.exists;

                                                  if (isFollowing) {
                                                    return ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.grey[300],
                                                        foregroundColor:
                                                            Colors.black,
                                                        minimumSize: Size(
                                                          70,
                                                          32,
                                                        ),
                                                        textStyle: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () async {
                                                        FollowService()
                                                            .toggleFollow(
                                                              userId,
                                                            );
                                                      },
                                                      child: Text('구독 취소'),
                                                    );
                                                  }

                                                  final isPrivate =
                                                      user.isPrivate;

                                                  if (isPrivate) {
                                                    return StreamBuilder<
                                                      DocumentSnapshot
                                                    >(
                                                      stream:
                                                          FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(userId)
                                                              .collection(
                                                                'followRequests',
                                                              )
                                                              .doc(
                                                                currentUser.uid,
                                                              )
                                                              .snapshots(),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        final hasRequest =
                                                            snapshot.hasData &&
                                                            snapshot
                                                                .data!
                                                                .exists;

                                                        return ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                hasRequest
                                                                    ? Colors
                                                                        .grey[300]
                                                                    : ColorsManager
                                                                        .primaryblack,
                                                            foregroundColor:
                                                                hasRequest
                                                                    ? Colors
                                                                        .black
                                                                    : Colors
                                                                        .white,
                                                            minimumSize: Size(
                                                              70,
                                                              32,
                                                            ),
                                                            textStyle:
                                                                TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                          ),
                                                          onPressed: () async {
                                                            if (hasRequest) {
                                                              await _cancelFollowRequest(
                                                                userId,
                                                                currentUser.uid,
                                                              );
                                                            } else {
                                                              await _sendFollowRequest(
                                                                userId,
                                                                currentUser.uid,
                                                              );
                                                            }
                                                          },
                                                          child: Text(
                                                            hasRequest
                                                                ? '요청 중'
                                                                : '요청',
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  }

                                                  return ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          ColorsManager
                                                              .primaryblack,
                                                      foregroundColor:
                                                          Colors.white,
                                                      minimumSize: Size(70, 32),
                                                      textStyle: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      FollowService()
                                                          .toggleFollow(userId);
                                                    },
                                                    child: Text('구독'),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )
                              : const Center(
                                child: CircularProgressIndicator(),
                              ),
                    ),

                    // ===================== Section 3: 차단친구 보기 (Always shown) =====================
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        '차단친구 보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // Blocked friends list
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 220),
                      child: StreamBuilder<DocumentSnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .snapshots(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final blockedList = List<String>.from(
                            userSnapshot.data!.get('blocked') ?? [],
                          );

                          if (blockedList.isEmpty) {
                            return Center(
                              child: Text(
                                '차단된 친구가 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          // Stream blocked user data
                          return StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .where(
                                      FieldPath.documentId,
                                      whereIn: blockedList,
                                    )
                                    .snapshots(),
                            builder: (context, blockedSnapshot) {
                              if (!blockedSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final blockedUsers = blockedSnapshot.data!.docs;

                              // Filter by search query
                              final filteredBlockedUsers =
                                  blockedUsers.where((doc) {
                                    final blockedUser = MyUser.fromDocument(
                                      doc.data() as Map<String, dynamic>,
                                    );
                                    if (searchQuery.isEmpty) return true;
                                    return blockedUser.name
                                        .toLowerCase()
                                        .contains(searchQuery);
                                  }).toList();

                              if (filteredBlockedUsers.isEmpty) {
                                return Center(
                                  child: Text(
                                    searchQuery.isNotEmpty
                                        ? '일치하는 차단된 친구가 없습니다'
                                        : '차단된 친구가 없습니다',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: filteredBlockedUsers.length,
                                itemBuilder: (context, index) {
                                  final blockedUser = MyUser.fromDocument(
                                    filteredBlockedUsers[index].data()
                                        as Map<String, dynamic>,
                                  );

                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // User avatar
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: Image.network(
                                              blockedUser.url,
                                              width: 48,
                                              height: 48,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          // User info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  blockedUser.name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (blockedUser.bio != null &&
                                                    blockedUser.bio!.isNotEmpty)
                                                  Text(
                                                    blockedUser.bio!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          // Unblock button
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  ColorsManager.primaryblack,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size(70, 32),
                                              textStyle: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () async {
                                              await _unblockUser(
                                                blockedUser.userId,
                                                currentUser.uid,
                                              );
                                            },
                                            child: Text('차단해제'),
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
                    SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _acceptFollowRequest(
    BuildContext context,
    String requestingUserId,
    String currentUserId,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Add to followers subcollection
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .doc(requestingUserId);

      batch.set(followerRef, {
        'userId': requestingUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add to requesting user's following subcollection
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(requestingUserId)
          .collection('following')
          .doc(currentUserId);

      batch.set(followingRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Delete the follow request
      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followRequests')
          .doc(requestingUserId);

      batch.delete(requestRef);

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('팔로우 요청을 수락했습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _declineFollowRequest(
    BuildContext context,
    String requestingUserId,
    String currentUserId,
  ) async {
    try {
      // Delete the follow request
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followRequests')
          .doc(requestingUserId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('팔로우 요청을 거절했습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>> _buildFriendRecommendations(
    String currentUserId,
    List<String> followingIds,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final recommendations = <String, int>{};

    try {
      // Get current user's followers to exclude them
      final currentFollowersSnapshot =
          await firestore
              .collection('users')
              .doc(currentUserId)
              .collection('followers')
              .get();
      final currentFollowers =
          currentFollowersSnapshot.docs.map((doc) => doc.id).toSet();

      // For each person the current user follows, get their following list
      for (final followingId in followingIds) {
        try {
          final theirFollowingSnapshot =
              await firestore
                  .collection('users')
                  .doc(followingId)
                  .collection('following')
                  .get();

          for (final doc in theirFollowingSnapshot.docs) {
            final userId = doc.id;
            // Skip current user
            if (userId == currentUserId) continue;
            // Skip people already following or followers
            if (currentFollowers.contains(userId)) continue;
            // Skip people current user already follows
            if (followingIds.contains(userId)) continue;

            // Count occurrences
            recommendations[userId] = (recommendations[userId] ?? 0) + 1;
          }
        } catch (e) {
          // Continue if one person's following list fails
          continue;
        }
      }

      // Sort by count (highest first) and limit to top recommendations
      final sortedRecs =
          recommendations.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // Fetch user data for top recommendations
      final result = <String, Map<String, dynamic>>{};
      for (final entry in sortedRecs.take(20)) {
        try {
          final userDoc =
              await firestore.collection('users').doc(entry.key).get();

          if (userDoc.exists) {
            final user = MyUser.fromDocument(
              userDoc.data() as Map<String, dynamic>,
            );
            result[entry.key] = {'user': user, 'count': entry.value};
          }
        } catch (e) {
          // Skip if user data fails to load
          continue;
        }
      }

      return result;
    } catch (e) {
      print('Error building recommendations: $e');
      return {};
    }
  }

  Future<void> _sendFollowRequest(
    String targetUserId,
    String currentUserId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('followRequests')
          .doc(currentUserId)
          .set({'createdAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _cancelFollowRequest(
    String targetUserId,
    String currentUserId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('followRequests')
          .doc(currentUserId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _unblockUser(String blockedUserId, String currentUserId) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);

      // Get current blocked list
      final currentUser = await userDoc.get();
      final blockedList = List<String>.from(currentUser.get('blocked') ?? []);

      // Remove from blocked list
      blockedList.remove(blockedUserId);

      // Update the document
      await userDoc.update({'blocked': blockedList});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차단이 해제되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>>
  _buildFriendRecommendationsWithContacts(
    String currentUserId,
    List<String> followingIds,
  ) async {
    try {
      // Get friend recommendations first
      final recommendations = await _buildFriendRecommendations(
        currentUserId,
        followingIds,
      );

      // Get contact matches
      final contactMatches = await _getContactMatches(
        currentUserId,
        followingIds,
      );

      // Merge contacts with recommendations (contacts won't override recommendations)
      for (final entry in contactMatches.entries) {
        if (!recommendations.containsKey(entry.key)) {
          recommendations[entry.key] = entry.value;
        }
      }

      return recommendations;
    } catch (e) {
      print('Error building recommendations with contacts: $e');
      return {};
    }
  }

  Future<Map<String, Map<String, dynamic>>> _getContactMatches(
    String currentUserId,
    List<String> followingIds,
  ) async {
    try {
      // Get phone contacts
      final contacts = await _contactService.getPhoneContacts();
      final phoneNumbers = _contactService.extractPhoneNumbers(contacts);

      // Find users matching phone numbers
      final matchingUsers = await _contactService.findUsersByPhoneNumbers(
        phoneNumbers,
      );

      // Get current user's followers to exclude them
      final currentFollowersSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('followers')
              .get();
      final currentFollowers =
          currentFollowersSnapshot.docs.map((doc) => doc.id).toSet();

      // Filter and build result
      final result = <String, Map<String, dynamic>>{};
      for (final user in matchingUsers) {
        // Skip self
        if (user.userId == currentUserId) continue;
        // Skip if already following
        if (followingIds.contains(user.userId)) continue;
        // Skip if already a follower
        if (currentFollowers.contains(user.userId)) continue;

        result[user.userId] = {'user': user, 'count': 0, 'isContact': true};
      }

      return result;
    } catch (e) {
      print('Error getting contact matches: $e');
      return {};
    }
  }
}
