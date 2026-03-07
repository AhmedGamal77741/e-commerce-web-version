import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/core/helpers/loading_service.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page.dart';
import 'package:ecommerece_app/features/mypage/ui/my_story.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ecommerece_app/core/widgets/safe_network_image.dart';

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
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              centerTitle: true,
              toolbarHeight: 100,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return const Text('Error loading user data');
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Text('User data not found');
                      }

                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () async {
                              LoadingService().showLoading();
                              final newUrl = await uploadImageToFirebaseStorage(
                                await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                ),
                              );
                              LoadingService().hideLoading();
                            },
                            child: ClipOval(
                              child: SafeNetworkImage(
                                url:
                                    (imgUrl.isEmpty
                                        ? (userData['url'] as String?)
                                        : imgUrl) ??
                                    '',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: Icon(Icons.person, size: 64),
                                placeholder: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          verticalSpace(10),
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('followers')
                                    .snapshots(),
                            builder: (context, subSnap) {
                              if (subSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return verticalSpace(5);
                              }
                              if (subSnap.hasError) {
                                return const Text('구독자 오류');
                              }
                              final count = subSnap.data?.docs.length ?? 0;
                              final formatted = count
                                  .toString()
                                  .replaceAllMapped(
                                    RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                    (match) => ',',
                                  );
                              return Text(
                                '구독자 $formatted 명',
                                style: TextStyles.abeezee14px400wP600,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              bottom: TabBar(
                tabs: [Tab(text: '내 이야기'), Tab(text: '마이페이지')],
                labelStyle: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: ColorsManager.primaryblack,
                ),
                unselectedLabelColor: ColorsManager.primary600,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: ColorsManager.primaryblack,
              ),
            ),
            body: const TabBarView(children: [MyStory(), MyPage()]),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: LoadingService().isLoading,
            builder: (context, isLoading, child) {
              return isLoading
                  ? Container(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                  )
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
