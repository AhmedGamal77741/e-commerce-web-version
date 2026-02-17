import 'dart:io';

import 'package:ecommerece_app/features/chat/models/story_model.dart';
import 'package:ecommerece_app/features/chat/ui/story_player_screen.dart';
import 'package:ecommerece_app/features/chat/ui/upload_story_screen.dart';
import 'package:ecommerece_app/features/chat/widgets/story_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

Widget buildStoryBar(
  UserStoryGroup? myStories,
  List<UserStoryGroup> friendsGroups,
) {
  return Container(
    height: 120.h,
    padding: EdgeInsets.symmetric(vertical: 10.h),
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: friendsGroups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return buildStoryCircle(
            label: '내 스토리',
            isMe: true,
            myStory: myStories == null,
            context: context,
            myStories: myStories,
          );
        }

        final group = friendsGroups[index - 1];

        return buildStoryCircle(
          label: group.authorName,
          imagePath: group.authorImage,
          hasUnread: true,
          context: context,
          group: group,
        );
      },
    ),
  );
}
