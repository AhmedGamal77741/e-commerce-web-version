import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/widgets/tab_app_bar.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page.dart';
import 'package:ecommerece_app/features/mypage/ui/my_story.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  String imgUrl = "";
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(); // loading indicator
                  }

                  if (snapshot.hasError) {
                    return const Text('Error loading user data');
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('User data not found');
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;

                  return InkWell(
                    onTap: () async {
                      showLoadingDialog(context);
                      final newUrl = await uploadImageToFirebaseStorage();
                      if (!mounted) return;
                      setState(() => imgUrl = newUrl);
                      Navigator.pop(context);
                    },
                    child: ClipOval(
                      child: Image.network(
                        (imgUrl.isEmpty ? userData['url'] : imgUrl) ?? '',
                        height: 55,
                        width: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          centerTitle: true,
          bottom: TabBar(
            tabs: [Tab(text: '내 이야기'), Tab(text: '마이페이지')],
            labelStyle: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'NotoSans',
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: ColorsManager.primaryblack,
            ),
            unselectedLabelColor: ColorsManager.primary600,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: ColorsManager.primaryblack,
          ),
        ),
        body: TabBarView(children: [MyStory(), MyPage()]),
      ),
    );
  }
}
