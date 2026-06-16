import 'dart:io';
import 'dart:typed_data';
import 'package:ecommerece_app/core/helpers/image_picker_helper.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<MyUser> getUser(String userId) async {
  try {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return MyUser.fromDocument(doc.data()!);
    }
    return MyUser.empty;
  } catch (e) {
    print('Error fetching user: $e');
    throw e;
  }
}

Future<void> addComment(String postId, String text) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // Get user data
  final userDoc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

  final userData = userDoc.data() ?? {};

  // Create comment
  final commentRef =
      FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc();

  // Update comment count in post
  final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

  // Use a batch to ensure both operations succeed or fail together
  final batch = FirebaseFirestore.instance.batch();

  batch.set(commentRef, {
    'userId': currentUser.uid,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
    'likes': 0,
    'userImage': userData['url'] ?? currentUser.photoURL,
    'userName': userData['name'] ?? currentUser.displayName,
  });

  batch.update(postRef, {'comments': FieldValue.increment(1)});

  await batch.commit();
}

Future<void> markPostNotInterested({required String postId}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    // Add the current user's ID to the notInterestedBy array
    // If the user ID is already in the array, it won't be added again
    await postRef.update({
      'notInterestedBy': FieldValue.arrayUnion([currentUser.uid]),
    });

    print('Post marked as not interested successfully!');
  } catch (e) {
    print('Error marking post as not interested: $e');
    throw e; // Re-throw to handle in UI
  }
}

Future<void> blockUser({required String userIdToBlock}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    // Reference to the current user's document
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid);

    final blocksCollection = FirebaseFirestore.instance.collection('blocks');

    final newBlockRef = blocksCollection.doc();

    await userRef.update({
      'blocked': FieldValue.arrayUnion([userIdToBlock]),
    });

    await newBlockRef.set({
      'blockedUserId': userIdToBlock,
      'blockedBy': currentUser.uid,
      'blockId': newBlockRef.id,
      /*       'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'resolved': false,  */
    });
    print('User blocked successfully!');
  } catch (e) {
    print('Error blocking user: $e');
    throw e; // Re-throw to handle in UI
  }
}

Future<void> reportUser({
  required String reportedUserId,
  required String postId,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final reportsCollection = FirebaseFirestore.instance.collection('reports');

    final newReportRef = reportsCollection.doc();

    await newReportRef.set({
      'reportedUserId': reportedUserId,
      'reportingUserId': currentUser.uid,
      'reportId': newReportRef.id,
      'postId': postId,
      /*       'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'resolved': false,  */
    });

    print('User reported successfully!');
  } catch (e) {
    print('Error reporting user: $e');
    throw e; // Re-throw to handle in UI
  }
}

Future<void> uploadPost({
  required String text,
  required List<String> imgUrls,
  String? categoryId,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final postsCollection = FirebaseFirestore.instance.collection('posts');

    final newPostRef = postsCollection.doc();

    final batch = FirebaseFirestore.instance.batch();

    batch.set(newPostRef, {
      'userId': currentUser.uid,
      'postId': newPostRef.id,
      'text': text,
      'imgUrl': imgUrls.isNotEmpty ? imgUrls[0] : null,
      'imgUrls': imgUrls,
      'categoryId': categoryId,
      'likes': 0,
      'comments': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': [],
      'notInterestedBy': [],
    });

    batch.update(
      FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
      {'lastPostCreatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
    print('Post uploaded successfully!');
  } catch (e) {
    print('Error uploading post: $e');
    throw e; // Re-throw to handle in UI
  }
}

/// Upload new images to Firebase Storage
Future<List<String>> _uploadNewImages(List<XFile> files) async {
  if (files.isEmpty) return [];

  final List<String> uploadedUrls = [];

  for (final file in files) {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser!.uid}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(fileName);

      final Uint8List rawBytes = await file.readAsBytes();

      // Compress on mobile, upload raw on web
      Uint8List uploadBytes;
      if (kIsWeb) {
        uploadBytes = rawBytes;
      } else {
        try {
          final Uint8List? compressed =
              await FlutterImageCompress.compressWithList(
                rawBytes,
                minWidth: 1080,
                minHeight: 1080,
                quality: 82,
                format: CompressFormat.jpeg,
              );
          uploadBytes = compressed ?? rawBytes;
        } catch (e) {
          print('Compression failed, uploading raw bytes: $e');
          uploadBytes = rawBytes;
        }
      }

      final UploadTask uploadTask = storageRef.putData(
        uploadBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      uploadedUrls.add(downloadUrl);
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  return uploadedUrls;
}

/// Update a post with new text and images
Future<void> updatePost({
  required String postId,
  required String text,
  required List<String> networkImgUrls, // Existing URLs to keep
  required List<XFile> newImages, // New images to upload
  String? categoryId,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    // Upload new images first
    final List<String> uploadedUrls = await _uploadNewImages(newImages);

    // Combine network URLs with newly uploaded URLs
    final List<String> allImgUrls = [...networkImgUrls, ...uploadedUrls];

    // Update the post in Firestore
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'text': text,
      'imgUrls': allImgUrls,
      'imgUrl':
          allImgUrls.isNotEmpty
              ? allImgUrls[0]
              : null, // Keep for backward compatibility
      'categoryId': categoryId,
    });

    print('Post updated successfully!');
  } catch (e) {
    print('Error updating post: $e');
    throw e;
  }
}

Future<String> uploadImageToFirebaseStorageHome() async {
  try {
    // 1. Pick image from gallery
    final XFile? image = await ImagePickerHelper.pickImage();

    if (image == null) return "";

    // 2. Prepare storage reference with unique filename
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}${FirebaseAuth.instance.currentUser!.uid}.jpg';
    final Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('uploads')
        .child(fileName);

    // 3. Read image bytes (works for both mobile and web)
    final bytes = await image.readAsBytes();

    // 4. Upload to Firebase Storage
    final UploadTask uploadTask = storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'), // Set MIME type
    );

    // 5. Get download URL when upload completes
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  } catch (e) {
    print('Error uploading image: $e');
    throw Exception('Failed to upload image: $e');
  }
}

Future<List<String>> uploadMultipleImagesToFirebaseHome() async {
  try {
    final List<XFile> images = await ImagePickerHelper.pickMultiImage();
    if (images.isEmpty) return [];

    List<String> downloadUrls = await Future.wait(
      images.map((image) async {
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String uid =
            FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        final int index = images.indexOf(image);
        final String fileName = '${timestamp}_${index}_$uid.jpg';

        final Uint8List rawBytes = await image.readAsBytes();

        // flutter_image_compress uses native code — not supported on web.
        // On mobile (Android/iOS) we compress; on web we upload raw bytes.
        Uint8List uploadBytes;
        if (kIsWeb) {
          // Web: no compression available, upload as-is
          uploadBytes = rawBytes;
        } else {
          // Mobile: compress to max 1080px on longest side, quality 82
          // Visually lossless but typically 60-80% smaller file size
          try {
            final Uint8List? compressed =
                await FlutterImageCompress.compressWithList(
                  rawBytes,
                  minWidth: 1080,
                  minHeight: 1080,
                  quality: 82,
                  format: CompressFormat.jpeg,
                );
            // Fall back to raw bytes if compression somehow returns null
            uploadBytes = compressed ?? rawBytes;
          } catch (e) {
            print('Compression failed, uploading raw bytes: $e');
            uploadBytes = rawBytes;
          }
        }

        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('uploads')
            .child(fileName);

        final UploadTask uploadTask = storageRef.putData(
          uploadBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      }),
    );

    return downloadUrls;
  } catch (e) {
    print('Error uploading multiple images: $e');
    throw Exception('Failed to upload images: $e');
  }
}

Future<void> migrateLastPostCreatedAt() async {
  try {
    print('Starting migration: lastPostCreatedAt...');
    final postsSnapshot =
        await FirebaseFirestore.instance.collection('posts').get();

    // Map to keep track of the latest post timestamp for each user
    final Map<String, DateTime> latestPosts = {};

    for (var doc in postsSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      final createdAtRaw = data['createdAt'];

      if (userId == null || createdAtRaw == null) continue;

      DateTime? postDate;
      if (createdAtRaw is Timestamp) {
        postDate = createdAtRaw.toDate();
      } else if (createdAtRaw is int) {
        postDate = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
      }

      if (postDate != null) {
        final currentLatest = latestPosts[userId];
        if (currentLatest == null || postDate.isAfter(currentLatest)) {
          latestPosts[userId] = postDate;
        }
      }
    }

    print(
      'Found latest posts for ${latestPosts.length} users. Updating profiles...',
    );

    // Update each user's profile if their post timestamp is newer than their current one
    int updatedCount = 0;
    for (var entry in latestPosts.entries) {
      final userId = entry.key;
      final latestPostDate = entry.value;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final currentLastPostRaw = userData?['lastPostCreatedAt'];
        DateTime? currentLastPost;

        if (currentLastPostRaw is Timestamp) {
          currentLastPost = currentLastPostRaw.toDate();
        } else if (currentLastPostRaw is int) {
          currentLastPost = DateTime.fromMillisecondsSinceEpoch(
            currentLastPostRaw,
          );
        }

        if (currentLastPost == null ||
            latestPostDate.isAfter(currentLastPost)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'lastPostCreatedAt': Timestamp.fromDate(latestPostDate),
              });
          updatedCount++;
        }
      }
    }

    print('Migration complete! Updated $updatedCount users.');
  } catch (e) {
    print('Error during lastPostCreatedAt migration: $e');
    rethrow;
  }
}
