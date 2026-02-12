import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/models/comment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostsProvider extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _posts = {};
  final Map<String, List<Comment>> _comments = {};
  final Map<String, MyUser> _users = {};
  final Set<String> _changedPostIds = {};
  final Set<String> _loadingCommentPosts = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isListening = false;

  // Getters
  Map<String, Map<String, dynamic>> get posts => _posts;
  List<String> get postIds => _posts.keys.toList();
  Map<String, dynamic>? getPost(String postId) => _posts[postId];
  List<Comment> getComments(String postId) {
    final comments = _comments[postId] ?? [];
    // Only include comments with a valid server timestamp (not pending local writes)
    return comments.where((c) {
      if (c.createdAt is Timestamp) {
        final ts = c.createdAt as Timestamp;
        // Firestore server timestamps have seconds > 0; local writes are usually 0
        return ts.seconds > 0;
      }
      return false;
    }).toList();
  }

  bool isLoadingComments(String postId) =>
      _loadingCommentPosts.contains(postId);
  MyUser? getUser(String userId) => _users[userId];
  bool hasPostChanged(String postId) => _changedPostIds.contains(postId);
  bool _resetting = false;

  void resetListening() {
    // Avoid multiple resets at once
    if (_resetting) return;

    _resetting = true;
    _isListening = false;
    _posts.clear();
    _changedPostIds.clear();

    // Schedule notification for the next frame instead of immediate notification
    Future.microtask(() {
      notifyListeners();
      _resetting = false;
    });
  }

  void startListening() {
    // Check if we're already listening, but allow restart after user changes
    final currentUser = FirebaseAuth.instance.currentUser;

    // If we're already listening but either:
    // 1. User logged out (currentUser is null)
    // 2. Different user logged in
    // Then we should reset the listening state
    if (_isListening) {
      if (currentUser == null) {
        resetListening(); // Clear everything if user logged out
        return; // Don't try to load posts without a user
      }
      return; // Otherwise, we're already listening for the current user
    }

    // Don't start listening if no user is logged in
    if (currentUser == null) {
      print("No user logged in, not loading posts yet");
      return;
    }

    // Start listening now
    _isListening = true;
    final currentUserId = currentUser.uid;

    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get()
        .then(
          (userDoc) {
            if (!userDoc.exists) {
              print("User document doesn't exist for ID: $currentUserId");
              return;
            }

            // Extract blocked user IDs
            List<String> blockedUsers = List<String>.from(
              userDoc.data()?['blocked'] ?? [],
            );

            // Listen to posts collection
            _firestore
                .collection('posts')
                .orderBy('createdAt', descending: true)
                .snapshots()
                .listen(
                  (snapshot) {
                    for (var change in snapshot.docChanges) {
                      final postData = change.doc.data()!;
                      final String postUserId = postData['userId'];
                      final String postId = change.doc.id;

                      // Skip posts from blocked users
                      if (blockedUsers.contains(postUserId)) {
                        continue;
                      }

                      List<dynamic> notInterestedBy = List<dynamic>.from(
                        postData['notInterestedBy'] ?? [],
                      );
                      if (notInterestedBy.contains(currentUserId)) {
                        continue;
                      }

                      _posts[postId] = change.doc.data()!;
                      _changedPostIds.add(postId);

                      // If we're already loading comments for this post, refresh them
                      if (_comments.containsKey(postId)) {
                        loadComments(postId);
                      }
                    }
                    notifyListeners();
                    _changedPostIds.clear();
                  },
                  onError: (e) {
                    print("Error listening to posts: $e");
                    _isListening = false; // Reset listening state on error
                  },
                  onDone: () {
                    print("Posts stream closed");
                    _isListening =
                        false; // Reset listening state when stream closes
                  },
                );
          },
          onError: (e) {
            print("Error getting user document: $e");
            _isListening = false; // Reset listening state on error
          },
        );
  }

  // Load comments for a specific post
  Future<void> loadComments(String postId) async {
    if (_loadingCommentPosts.contains(postId)) return;

    _loadingCommentPosts.add(postId);
    notifyListeners();

    try {
      final commentsSnapshot =
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .orderBy('createdAt', descending: true)
              .get();

      final comments =
          commentsSnapshot.docs
              .map((doc) => Comment.fromFirestore(doc))
              .toList();

      _comments[postId] = comments;

      // Preload user data for comment authors
      final userIds =
          comments.map((comment) => comment.userId).toSet().toList();

      for (final userId in userIds) {
        if (!_users.containsKey(userId)) {
          try {
            await loadUser(userId);
          } catch (e) {
            print('Error loading user $userId: $e');
          }
        }
      }
    } catch (e) {
      print('Error loading comments for post $postId: $e');
    } finally {
      _loadingCommentPosts.remove(postId);
      notifyListeners();
    }
  }

  Future<void> addToNotInterested(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId);

      // Use FieldValue.arrayUnion to add the user ID to the array
      // without duplicates
      await postRef.update({
        'notInterestedBy': FieldValue.arrayUnion([currentUser!.uid]),
      });

      print('Added ${currentUser.uid} to notInterestedBy for post $postId');
      notifyListeners();
    } catch (e) {
      print('Error adding to notInterestedBy: $e');
      throw e; // Re-throw if you want to handle the error in the calling code
    }
  }

  // Listen to comments for a specific post in real-time
  void listenToComments(String postId) {
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final comments =
              snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();

          _comments[postId] = comments;

          // Preload user data for new comment authors
          for (final comment in comments) {
            if (!_users.containsKey(comment.userId)) {
              loadUser(comment.userId);
            }
          }

          notifyListeners();
        });
  }

  // Add a comment to a post
  // Add a comment to a post
  Future<void> addComment(String postId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get current user data
    MyUser? userData = _users[currentUser.uid];

    if (userData == null) {
      try {
        userData = await loadUser(currentUser.uid);
      } catch (e) {
        print('Error loading user data: $e');
      }
    }

    // Create a batch for atomic operations
    final batch = _firestore.batch();

    // Create comment document reference
    final commentRef =
        _firestore.collection('posts').doc(postId).collection('comments').doc();

    // Set comment data
    batch.set(commentRef, {
      'userId': currentUser.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'userImage': userData?.url ?? currentUser.photoURL,
      'userName': userData?.name ?? currentUser.displayName,
      'likedBy': [],
    });

    // Update post comment count
    final postRef = _firestore.collection('posts').doc(postId);
    batch.update(postRef, {'comments': FieldValue.increment(1)});

    // Commit the batch
    try {
      await batch.commit();
      // Let the Firestore listeners handle the UI updates automatically
    } catch (e) {
      print('Error adding comment: $e');
      throw e;
    }
  }

  // Toggle like on a post
  Future<void> togglePostLike(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get the current post data
    final post = _posts[postId];
    if (post == null) return;

    // Check if already liked
    List<String> likedBy = List<String>.from(post['likedBy'] ?? []);
    bool isLiked = likedBy.contains(currentUser.uid);

    // Update locally first (optimistic)
    if (isLiked) {
      likedBy.remove(currentUser.uid);
      post['likes'] = (post['likes'] ?? 1) - 1;
    } else {
      likedBy.add(currentUser.uid);
      post['likes'] = (post['likes'] ?? 0) + 1;
    }
    post['likedBy'] = likedBy;

    // Mark this post as changed
    _changedPostIds.add(postId);

    // Notify UI to update
    notifyListeners();
    _changedPostIds.clear();

    // Update in Firestore
    try {
      await _firestore.collection('posts').doc(postId).update({
        'likedBy':
            isLiked
                ? FieldValue.arrayRemove([currentUser.uid])
                : FieldValue.arrayUnion([currentUser.uid]),
        'likes': isLiked ? FieldValue.increment(-1) : FieldValue.increment(1),
      });
    } catch (e) {
      // If update fails, revert the local change
      print('Error updating like: $e');
      if (isLiked) {
        likedBy.add(currentUser.uid);
        post['likes'] = (post['likes'] ?? 0) + 1;
      } else {
        likedBy.remove(currentUser.uid);
        post['likes'] = (post['likes'] ?? 1) - 1;
      }
      post['likedBy'] = likedBy;

      _changedPostIds.add(postId);
      notifyListeners();
      _changedPostIds.clear();
    }
  }

  Future<void> toggleCommentLike(String postId, String commentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Find the comment in our local state
    if (!_comments.containsKey(postId)) return;

    final commentIndex = _comments[postId]!.indexWhere(
      (c) => c.id == commentId,
    );
    if (commentIndex == -1) return;

    final comment = _comments[postId]![commentIndex];

    // Check if already liked
    List<String> likedBy = List<String>.from(comment.likedBy ?? []);
    bool isLiked = likedBy.contains(currentUser.uid);

    // Create a new comment object with updated like data (immutable approach)
    final updatedComment = Comment(
      id: comment.id,
      userId: comment.userId,
      text: comment.text,
      createdAt: comment.createdAt,
      likes: isLiked ? (comment.likes - 1) : (comment.likes + 1),
      userImage: comment.userImage,
      userName: comment.userName,
      likedBy:
          isLiked
              ? likedBy.where((id) => id != currentUser.uid).toList()
              : [...likedBy, currentUser.uid],
    );

    // Update the comment in our local state
    final updatedComments = List<Comment>.from(_comments[postId]!);
    updatedComments[commentIndex] = updatedComment;
    _comments[postId] = updatedComments;

    // Notify UI to update
    notifyListeners();

    // Update in Firestore
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
            'likedBy':
                isLiked
                    ? FieldValue.arrayRemove([currentUser.uid])
                    : FieldValue.arrayUnion([currentUser.uid]),
            'likes':
                isLiked ? FieldValue.increment(-1) : FieldValue.increment(1),
          });
    } catch (e) {
      // If update fails, revert the local change
      print('Error updating comment like: $e');

      // Revert to the original comment
      final revertedComments = List<Comment>.from(_comments[postId]!);
      revertedComments[commentIndex] = comment;
      _comments[postId] = revertedComments;

      notifyListeners();
    }
  }

  // Load a user if not already loaded
  Future<MyUser> loadUser(String userId) async {
    if (_users.containsKey(userId)) {
      return _users[userId]!;
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    final user = MyUser.fromDocument(userData);

    _users[userId] = user;
    notifyListeners();
    return user;
  }

  // Preload users for all posts
  Future<void> preloadUsers() async {
    final userIds =
        _posts.values.map((post) => post['userId'] as String).toSet().toList();

    for (final userId in userIds) {
      if (!_users.containsKey(userId)) {
        try {
          await loadUser(userId);
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }
    }
  }
}
