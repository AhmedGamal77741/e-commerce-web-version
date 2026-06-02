import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostActions({Key? key, required this.postId, required this.postData})
    : super(key: key);

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
