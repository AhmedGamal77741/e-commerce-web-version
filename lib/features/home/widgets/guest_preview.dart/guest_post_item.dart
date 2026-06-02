import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/profile_tab.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_actions.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_comments.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart'; // imports NaturalAspectPageView
import 'package:ecommerece_app/features/home/widgets/share_dialog.dart';
import 'package:flutter/material.dart';

class GuestPostItem extends StatelessWidget {
  final Map<String, dynamic> post;

  /// Caller-supplied explicit image width.
  /// GuestComments computes this via MediaQuery and passes it in so
  /// NaturalAspectPageView always has the correct pixel width even when
  /// it lives inside a Column/SingleChildScrollView (unbounded width).
  final double? imageWidth;
  final String? currentProfileUserId;

  GuestPostItem({
    Key? key,
    required this.post,
    this.imageWidth,
    this.currentProfileUserId,
  }) : super(key: key);

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

        final List imgUrls =
            (post['imgUrls'] != null && (post['imgUrls'] as List).isNotEmpty)
                ? post['imgUrls'] as List
                : [];

        return Column(
          children: [
            // ── fromComments branch ───────────────────────────────────────
            if (post['fromComments'] == true)
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              if (myuser != null &&
                                  currentProfileUserId != myuser.userId) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => Scaffold(
                                          body: ProfileTab(
                                            userId: myuser.userId,
                                          ),
                                        ),
                                  ),
                                );
                              }
                            },
                            child: Container(
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
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'share') {
                                showShareDialog(
                                  context,
                                  'post',
                                  'https://app.pang2chocolate.com/comment?postId=${post['postId']}',
                                  post['postId'] ?? '',
                                  displayName,
                                  profileUrl,
                                  post,
                                );
                              }
                            },
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder:
                                (_) => [
                                  const PopupMenuItem<String>(
                                    value: 'share',
                                    child: Text(
                                      '공유하기',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'NotoSans',
                                      ),
                                    ),
                                  ),
                                ],
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.more_horiz,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (post['text'].toString().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 15),
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
                      verticalSpace(5),
                      // imageWidth forwarded from GuestComments so that
                      // NaturalAspectPageView renders at the correct ratio.
                      if (imgUrls.isNotEmpty)
                        NaturalAspectPageView(
                          imgUrls: imgUrls,
                          pageController: _pageController,
                          explicitWidth: imageWidth,
                        ),
                      verticalSpace(30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(children: [GuestPostActions(post: post)]),
                          horizontalSpace(4),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey[600],
                            ),
                          ),
                          InkWell(
                            onTap: () => GoRouter.of(context).pop(),
                            child: Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── normal feed branch ────────────────────────────────────────
            if (post['fromComments'] != true)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => Container(
                            height: MediaQuery.of(context).size.height * 0.95,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: GuestComments(post: post),
                            ),
                          ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Avatar
                      InkWell(
                        onTap: () {
                          if (myuser != null &&
                              currentProfileUserId != myuser.userId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => Scaffold(
                                      body: ProfileTab(userId: myuser.userId),
                                    ),
                              ),
                            );
                          }
                        },
                        child: Container(
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
                      ),
                      horizontalSpace(8),

                      // Expanded gives NaturalAspectPageView a bounded width
                      // via LayoutBuilder — no explicitWidth needed here.
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
                            if (imgUrls.isNotEmpty)
                              NaturalAspectPageView(
                                imgUrls: imgUrls,
                                pageController: _pageController,
                                // No explicitWidth needed — Expanded above
                                // already provides a bounded maxWidth.
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
