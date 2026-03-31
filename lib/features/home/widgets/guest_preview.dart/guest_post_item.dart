import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_actions.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class GuestPostItem extends StatelessWidget {
  final Map<String, dynamic> post;
  GuestPostItem({Key? key, required this.post}) : super(key: key);
  final PageController _pageController = PageController();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyUser>(
      future: getUser(post['userId']),
      builder: (context, snapshot) {
        final bool userMissing =
            snapshot.hasError ||
            !snapshot.hasData ||
            (snapshot.data?.userId ?? '').isEmpty;
        final myuser = snapshot.data;
        final displayName =
            myuser?.name.isNotEmpty == true ? myuser!.name : '삭제된 사용자';
        final profileUrl = !userMissing ? (myuser?.url ?? '') : '';

        return Column(
          children: [
            if (post['fromComments'] == true)
              Padding(
                padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: ShapeDecoration(
                            image: DecorationImage(
                              image:
                                  profileUrl.isNotEmpty
                                      ? NetworkImage(profileUrl)
                                      : AssetImage('assets/avatar.png')
                                          as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                            shape: OvalBorder(),
                          ),
                        ),
                        horizontalSpace(5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              verticalSpace(5),
                              Text(
                                displayName,
                                style: TextStyles.abeezee16px400wPblack
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),

                              // Only show follower counter if user exists and userId is not empty
                              if (!userMissing && myuser!.userId.isNotEmpty)
                                StreamBuilder<QuerySnapshot>(
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(myuser.userId)
                                          .collection('followers')
                                          .snapshots(),
                                  builder: (context, subSnap) {
                                    if (subSnap.connectionState ==
                                        ConnectionState.waiting) {
                                      return SizedBox(height: 16);
                                    }
                                    if (subSnap.hasError) {
                                      return Text(
                                        '구독자 오류',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 16,
                                        ),
                                      );
                                    }
                                    final count =
                                        subSnap.data?.docs.length ?? 0;
                                    final formatted = count
                                        .toString()
                                        .replaceAllMapped(
                                          RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                          (match) => ',',
                                        );
                                    return Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        '구독자 $formatted명',
                                        style: TextStyle(
                                          color: const Color(0xFF787878),
                                          fontSize: 16,
                                          fontFamily: 'NotoSans',
                                          fontWeight: FontWeight.w400,
                                          height: 1.40,
                                          letterSpacing: -0.09,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (post['text'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                post['text'],
                                style: TextStyle(
                                  color: const Color(0xFF343434),
                                  fontSize: 18,
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w500,
                                  height: 1.40,
                                  letterSpacing: -0.09,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    verticalSpace(5),
                    if (post['imgUrls'] != null && post['imgUrls'].isNotEmpty)
                      SizedBox(
                        height: 428,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: (post['imgUrls'] as List).length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder:
                                  (context, index) => Image.network(
                                    (post['imgUrls'] as List)[index],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const Placeholder(),
                                  ),
                            ),
                            if (post['imgUrls'].length > 1)
                              Positioned.fill(
                                bottom: 0,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    height: 60,
                                    child: Center(
                                      child: SmoothPageIndicator(
                                        controller: _pageController,
                                        count: (post['imgUrls'] as List).length,
                                        effect: const ScrollingDotsEffect(
                                          activeDotColor: Colors.black,
                                          dotColor: Colors.grey,
                                          dotHeight: 10,
                                          dotWidth: 10,
                                        ),
                                        onDotClicked: (index) {
                                          _pageController.animateToPage(
                                            index,
                                            duration: const Duration(
                                              milliseconds: 400,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    verticalSpace(30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(children: [GuestPostActions(post: post)]),
                        horizontalSpace(4),
                        Expanded(
                          child: Container(height: 1, color: Colors.grey[600]),
                        ),

                        InkWell(
                          onTap: () {
                            context.pop();
                          },
                          child: Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (post['fromComments'] != true)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (post['fromComments'] != true) {
                      final postId = post['postId'];
                      GoRouter.of(
                        context,
                      ).push('/guest_comment?postId=$postId');
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: ShapeDecoration(
                          image: DecorationImage(
                            image:
                                profileUrl.isNotEmpty
                                    ? NetworkImage(profileUrl)
                                    : AssetImage('assets/avatar.png')
                                        as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          shape: OvalBorder(),
                        ),
                      ),
                      horizontalSpace(8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            verticalSpace(10),
                            Text(
                              displayName,
                              style: TextStyles.abeezee16px400wPblack.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (post['text'].toString().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text(
                                  post['text'],
                                  style: TextStyle(
                                    color: const Color(0xFF343434),
                                    fontSize: 16,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: -0.09,
                                  ),
                                ),
                              ),
                            verticalSpace(5),
                            if (post['imgUrls'] != null &&
                                post['imgUrls'].isNotEmpty)
                              SizedBox(
                                height: 428,
                                child: Stack(
                                  children: [
                                    PageView.builder(
                                      controller: _pageController,
                                      itemCount:
                                          (post['imgUrls'] as List).length,
                                      physics: const BouncingScrollPhysics(),
                                      itemBuilder:
                                          (context, index) => Image.network(
                                            (post['imgUrls'] as List)[index],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    const Placeholder(),
                                          ),
                                    ),
                                    if (post['imgUrls'].length > 1)
                                      Positioned.fill(
                                        bottom: 0,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: SizedBox(
                                            height: 60,
                                            child: Center(
                                              child: SmoothPageIndicator(
                                                controller: _pageController,
                                                count:
                                                    (post['imgUrls'] as List)
                                                        .length,
                                                effect:
                                                    const ScrollingDotsEffect(
                                                      activeDotColor:
                                                          Colors.black,
                                                      dotColor: Colors.grey,
                                                      dotHeight: 10,
                                                      dotWidth: 10,
                                                    ),
                                                onDotClicked: (index) {
                                                  _pageController.animateToPage(
                                                    index,
                                                    duration: const Duration(
                                                      milliseconds: 400,
                                                    ),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            verticalSpace(5),
                            Row(children: [GuestPostActions(post: post)]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
