import 'dart:io';

import 'package:ecommerece_app/features/chat/models/story_model.dart';
import 'package:ecommerece_app/features/chat/ui/story_player_screen.dart';
import 'package:ecommerece_app/features/chat/ui/upload_story_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

Widget buildStoryCircle({
  required String label,
  String? imagePath,
  bool isMe = false,
  bool myStory = false,
  bool hasUnread = true,
  UserStoryGroup? myStories,
  UserStoryGroup? group,
  required BuildContext context,
}) {
  Future<void> handleAddNewStory(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null && context.mounted) {
      final tempImage = await image.readAsBytes();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadStoryScreen(initialImage: tempImage),
        ),
      );
    }
  }

  final currentUser = FirebaseAuth.instance.currentUser!;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (myStories != null && isMe) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StoryPlayerScreen(group: myStories!),
                    ),
                  );
                } else if (isMe && myStories == null) {
                  handleAddNewStory(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryPlayerScreen(group: group!),
                    ),
                  );
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image:
                      (!myStory && hasUnread)
                          ? DecorationImage(
                            image: AssetImage(
                              'assets/Story_background_transparent.png',
                            ),
                            fit: BoxFit.cover,
                          )
                          : null,
                  color: Colors.transparent,
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        isMe
                            ? currentUser.photoURL != null
                                ? NetworkImage(currentUser.photoURL.toString())
                                : null
                            : NetworkImage(group!.authorImage),
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ),
            // The Plus Icon for "My Story"
            if (isMe)
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => handleAddNewStory(context),
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: Colors.white),
                      image: DecorationImage(
                        image: AssetImage('assets/story_plus.png'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Text(
          (isMe) ? currentUser.displayName.toString() : label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}
