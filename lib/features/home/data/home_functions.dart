import 'dart:convert';
import 'dart:io';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
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

Future<void> uploadPost({required String text, required String imgUrl}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final postsCollection = FirebaseFirestore.instance.collection('posts');

    // Create a new document with auto-generated ID
    final newPostRef = postsCollection.doc();

    await newPostRef.set({
      'userId': currentUser.uid,
      'postId': newPostRef.id,
      'text': text,
      'imgUrl': imgUrl,
      'likes': 0,
      'comments': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': [],
      'notInterestedBy': [],
    });

    print('Post uploaded successfully!');
  } catch (e) {
    print('Error uploading post: $e');
    throw e; // Re-throw to handle in UI
  }
}

Future<String> uploadImageToFirebaseStorage() async {
  try {
    // 1. Pick image from gallery
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
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
