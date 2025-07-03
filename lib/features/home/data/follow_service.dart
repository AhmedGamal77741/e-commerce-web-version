import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a follower
  Future<void> followUser(String userId, String followerId) async {
    final batch = _firestore.batch();

    // Add to user's followers subcollection
    final followerRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(followerId);

    batch.set(followerRef, {
      'userId': followerId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Add to follower's following subcollection
    final followingRef = _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(userId);

    batch.set(followingRef, {
      'userId': userId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Update follower count for the user being followed
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {'followerCount': FieldValue.increment(1)});

    // Update following count for the user doing the following
    final followerUserRef = _firestore.collection('users').doc(followerId);
    batch.update(followerUserRef, {'followingCount': FieldValue.increment(1)});

    await batch.commit();
  }

  // In FriendsService class
  Future<bool> toggleFollow(String targetUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      final batch = _firestore.batch();

      // Check current follow status
      final followingDoc =
          await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .doc(targetUserId)
              .get();

      final isFollowing = followingDoc.exists;

      final followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);

      if (isFollowing) {
        // Unfollow
        batch.delete(followingRef);
        batch.delete(followerRef);

        // Remove from friends lists
        batch.update(_firestore.collection('users').doc(currentUserId), {
          'friends': FieldValue.arrayRemove([targetUserId]),
        });
        batch.update(_firestore.collection('users').doc(targetUserId), {
          'friends': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Follow
        batch.set(followingRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'userId': targetUserId,
        });
        batch.set(followerRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'userId': currentUserId,
        });

        // Check for mutual follow
        final mutualFollowCheck =
            await _firestore
                .collection('users')
                .doc(currentUserId)
                .collection('followers')
                .doc(targetUserId)
                .get();

        if (mutualFollowCheck.exists) {
          // Create friendship
          batch.update(_firestore.collection('users').doc(currentUserId), {
            'friends': FieldValue.arrayUnion([targetUserId]),
          });
          batch.update(_firestore.collection('users').doc(targetUserId), {
            'friends': FieldValue.arrayUnion([currentUserId]),
          });

          // Get user data for notification
          final currentUserDoc =
              await _firestore.collection('users').doc(currentUserId).get();
          final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

          // Create friendship notification
          final notificationRef = _firestore.collection('activities').doc();
          batch.set(notificationRef, {
            'id': notificationRef.id,
            'type': 'new_friend',
            'userId': targetUserId,
            'friendId': currentUserId,
            'friendName': currentUser.name,
            'friendProfileImage': currentUser.url,
            'message': 'You and ${currentUser.name} are now friends!',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error toggling follow: $e');
      return false;
    }
  }

  // Remove a follower
  Future<void> unfollowUser(String userId, String followerId) async {
    final batch = _firestore.batch();

    // Remove from user's followers subcollection
    final followerRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(followerId);

    batch.delete(followerRef);

    // Remove from follower's following subcollection
    final followingRef = _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(userId);

    batch.delete(followingRef);

    // Update follower count for the user being unfollowed
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {'followerCount': FieldValue.increment(-1)});

    // Update following count for the user doing the unfollowing
    final followerUserRef = _firestore.collection('users').doc(followerId);
    batch.update(followerUserRef, {'followingCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  // Get followers ordered by when they followed (newest first)
  Stream<List<String>> getFollowersStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('followedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get following ordered by when you followed them (newest first)
  Stream<List<String>> getFollowingStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('followedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get follower count (from user document - faster)
  Future<int> getFollowerCount(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['followerCount'] ?? 0;
  }

  // Get following count (from user document - faster)
  Future<int> getFollowingCount(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['followingCount'] ?? 0;
  }

  // Check if user is following another user
  Future<bool> isFollowing(String userId, String targetUserId) async {
    final doc =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('following')
            .doc(targetUserId)
            .get();

    return doc.exists;
  }

  // Get followers with pagination
  Future<List<String>> getFollowersPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('followedAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Get following with pagination
  Future<List<String>> getFollowingPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('followedAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }
}
