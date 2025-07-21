// services/friends_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  /// Returns a list of blocked friends for the current user as a List<Map<String, String>>
  Future<List<Map<String, String>>> getBlockedFriends() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return [];
      final user = MyUser.fromDocument(userDoc.data()!);
      if (user.blocked == null || user.blocked!.isEmpty) return [];
      final blockedIds = user.blocked!;
      if (blockedIds.isEmpty) return [];
      final blockedQuery =
          await _firestore
              .collection('users')
              .where('userId', whereIn: blockedIds)
              .get();
      return blockedQuery.docs
          .map(
            (doc) => {
              'userId': (doc['userId'] ?? '').toString(),
              'name': (doc['name'] ?? '').toString(),
              'url': (doc['url'] ?? '').toString(),
            },
          )
          .toList();
    } catch (e) {
      print('Error fetching blocked friends: $e');
      return [];
    }
  }

  /// Unblocks a friend by userId for the current user
  Future<bool> unblockFriend(String userId) async {
    try {
      // Remove from user's blocked list
      await _firestore.collection('users').doc(currentUserId).update({
        'blocked': FieldValue.arrayRemove([userId]),
      });
      // Remove from blocks collection if exists
      final blocksQuery =
          await _firestore
              .collection('blocks')
              .where('blockedBy', isEqualTo: currentUserId)
              .where('blockedUserId', isEqualTo: userId)
              .get();
      for (final doc in blocksQuery.docs) {
        await doc.reference.delete();
      }
      print('User unblocked successfully!');
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<bool> addFriend(String friendName) async {
    try {
      // Prevent adding yourself as a friend by name
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

      if (currentUser.name == friendName) {
        throw Exception('Cannot add yourself as a friend');
      }

      // Search for user by name
      final userQuery =
          await _firestore
              .collection('users')
              .where('name', isEqualTo: friendName)
              .limit(1)
              .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final friendDoc = userQuery.docs.first;
      final friendId = friendDoc['userId'];

      // Check if already friends
      if (currentUser.friends.contains(friendId)) {
        throw Exception('Already friends with this user');
      }

      // Use batch to ensure atomicity
      final batch = _firestore.batch();

      // Add to current user's friends list
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'friends': FieldValue.arrayUnion([friendId]),
      });

      // Add to friend's friends list
      batch.update(_firestore.collection('users').doc(friendId), {
        'friends': FieldValue.arrayUnion([currentUserId]),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error adding friend: $e');
      return false;
    }
  }

  Future<bool> blockFriend(String friendName) async {
    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

      if (currentUser.name == friendName) {
        throw Exception('Cannot block yourself');
      }

      // Search for user by name
      final userQuery =
          await _firestore
              .collection('users')
              .where('name', isEqualTo: friendName)
              .limit(1)
              .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final friendDoc = userQuery.docs.first;
      final friendId = friendDoc['userId'];
      // Check if already blocked
      if (currentUser.blocked!.contains(friendId)) {
        throw Exception('Already blocked this user');
      }

      await currentUserDoc.reference.update({
        'blocked': FieldValue.arrayUnion([friendId]),
      });

      final blocksCollection = FirebaseFirestore.instance.collection('blocks');

      final newBlockRef = blocksCollection.doc();
      await newBlockRef.set({
        'blockedUserId': friendId,
        'blockedBy': currentUser.userId,
        'blockId': newBlockRef.id,
      });
      print('User blocked successfully!');
      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendId) async {
    try {
      final batch = _firestore.batch();

      // Remove from each other's friends list
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'friends': FieldValue.arrayRemove([friendId]),
      });

      batch.update(_firestore.collection('users').doc(friendId), {
        'friends': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  // Get friends stream
  Stream<List<MyUser>> getFriendsStream() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .asyncMap((userDoc) async {
          if (!userDoc.exists) return <MyUser>[];

          final user = MyUser.fromDocument(userDoc.data()!);
          if (user.friends.isEmpty) return <MyUser>[];

          final friendsQuery =
              await _firestore
                  .collection('users')
                  .where('userId', whereIn: user.friends)
                  .get();

          // Filter out blocked users in Dart
          return friendsQuery.docs
              .map((doc) => MyUser.fromDocument(doc.data()))
              .where(
                (friend) => !(user.blocked?.contains(friend.userId) ?? false),
              )
              .toList();
        });
  }

  Stream<List<MyUser>> getBrandsStream() {
    return _firestore.collection('users').snapshots().asyncMap((userDoc) async {
      final friendsQuery =
          await _firestore
              .collection('users')
              .where('type', isEqualTo: 'brand')
              .get();

      // Filter out blocked users in Dart
      return friendsQuery.docs
          .map((doc) => MyUser.fromDocument(doc.data()))
          .toList();
    });
  }

  // Get friends count
  Stream<int> getFriendsCountStream() {
    return _firestore.collection('users').doc(currentUserId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return 0;
      final user = MyUser.fromDocument(snapshot.data()!);
      return user.friends.length;
    });
  }

  // Search users (excluding current user and existing friends)
  Future<List<MyUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Get current user's friends list
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

      // Search by name (case-insensitive)
      final usersQuery =
          await _firestore
              .collection('users')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThan: query + 'z')
              .limit(20)
              .get();

      // You could also search by email or username
      // final emailQuery = await _firestore
      //     .collection('users')
      //     .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
      //     .where('email', isLessThan: query.toLowerCase() + 'z')
      //     .limit(20)
      //     .get();

      return usersQuery.docs
          .map((doc) => MyUser.fromDocument(doc.data()))
          .where(
            (user) =>
                user.userId != currentUserId &&
                !currentUser.friends.contains(user.userId),
          )
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Check if users are friends
  Future<bool> areFriends(String userId) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final user = MyUser.fromDocument(userDoc.data()!);
      return user.friends.contains(userId);
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  // Get mutual friends
  Future<List<MyUser>> getMutualFriends(String userId) async {
    try {
      // Get current user's friends
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

      // Get other user's friends
      final otherUserDoc =
          await _firestore.collection('users').doc(userId).get();
      final otherUser = MyUser.fromDocument(otherUserDoc.data()!);

      // Find mutual friends
      final mutualFriendIds =
          currentUser.friends
              .where((friendId) => otherUser.friends.contains(friendId))
              .toList();

      if (mutualFriendIds.isEmpty) return [];

      // Get mutual friends data
      final mutualFriendsQuery =
          await _firestore
              .collection('users')
              .where('id', whereIn: mutualFriendIds)
              .get();

      return mutualFriendsQuery.docs
          .map((doc) => MyUser.fromDocument(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting mutual friends: $e');
      return [];
    }
  }

  // Bulk add friends (useful for importing contacts)
  Future<Map<String, bool>> bulkAddFriends(List<String> friendIds) async {
    Map<String, bool> results = {};

    for (String friendId in friendIds) {
      try {
        final success = await addFriend(friendId);
        results[friendId] = success;
      } catch (e) {
        results[friendId] = false;
      }
    }

    return results;
  }
}
