import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/chat/models/story_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> uploadStory(
    Uint8List imageFile,
    String name,
    String profileImg,
  ) async {
    try {
      print("DEBUG: Starting upload process...");
      final String uid = _auth.currentUser!.uid;
      final String storyId = _firestore.collection('stories').doc().id;

      // 1. Upload to Storage
      print("DEBUG: Uploading to Storage path: stories/$uid/$storyId");
      Reference ref = _storage.ref().child('stories/$uid/$storyId');

      // TaskSnapshot is required to ensure we wait for completion
      TaskSnapshot snapshot = await ref.putData(imageFile);
      print("DEBUG: Storage upload complete. State: ${snapshot.state}");

      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("DEBUG: Download URL obtained: $downloadUrl");

      // 2. Write to Firestore
      final newStory = StoryModel(
        storyId: storyId,
        authorId: uid,
        authorName: name,
        authorImage: profileImg,
        imageUrl: downloadUrl,
        createdAt: DateTime.now(),
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch,
        viewers: [],
      );

      print("DEBUG: Writing metadata to Firestore...");
      await _firestore
          .collection('stories')
          .doc(storyId)
          .set(newStory.toFirestore());
      print("DEBUG: Firestore write successful!");
    } catch (e, stacktrace) {
      print("DEBUG: UPLOAD FAILED!");
      print("DEBUG: Error: $e");
      print("DEBUG: Stacktrace: $stacktrace");
      rethrow; // This sends the error back to your UI's try-catch block
    }
  }

  Future<void> deleteStory(String storyId, String imageUrl) async {
    try {
      print("DEBUG: Starting delete process for $storyId...");

      // 1. Delete the image from Firebase Storage
      // We create a reference from the URL to find the exact file
      Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.delete();
      print("DEBUG: Storage file deleted successfully.");

      // 2. Delete the document from Firestore
      await _firestore.collection('stories').doc(storyId).delete();
      print("DEBUG: Firestore document deleted successfully.");
    } catch (e) {
      print("DEBUG: DELETE FAILED! Error: $e");
      rethrow;
    }
  }

  // Get a single story once
  Future<StoryModel?> getStoryById(String storyId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('stories').doc(storyId).get();

      if (doc.exists && doc.data() != null) {
        final story = StoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
        );

        /*         if (story.expiresAt > DateTime.now().millisecondsSinceEpoch) {
          return story;
        } */
        return story;
        /*         print("DEBUG: Story found but it has expired.");
 */
      }
      return null;
    } catch (e) {
      print("DEBUG: Error fetching story: $e");
      return null;
    }
  }

  /*  
  Stream<StoryModel?> getStoryStream(String storyId) {
    return _firestore.collection('stories').doc(storyId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return StoryModel.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  } */

  Stream<List<StoryModel>> getFriendsStories(List<String> followingIds) {
    if (followingIds.isEmpty) return Stream.value([]);

    return _firestore
        .collection('stories')
        .where('authorId', whereIn: followingIds)
        .where(
          'expiresAt',
          isGreaterThan: DateTime.now().millisecondsSinceEpoch,
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => StoryModel.fromFirestore(doc.data()))
                  .toList(),
        );
  }

  List<UserStoryGroup> groupStories(List<StoryModel> allStories) {
    final Map<String, List<StoryModel>> map = {};

    for (var story in allStories) {
      map.putIfAbsent(story.authorId, () => []).add(story);
    }

    return map.entries.map((entry) {
      final firstStory = entry.value.first;
      return UserStoryGroup(
        authorId: entry.key,
        authorName: firstStory.authorName,
        authorImage: firstStory.authorImage,
        stories:
            entry.value..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );
    }).toList();
  }
}
