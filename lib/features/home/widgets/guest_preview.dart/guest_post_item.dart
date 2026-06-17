import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_comments.dart';
import 'package:ecommerece_app/features/home/widgets/share_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/profile_tab.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_actions.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart'; // imports NaturalAspectPageView
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';

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
    final bool isGuest = FirebaseAuth.instance.currentUser == null;
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    Future<void> runWithLoading(
      BuildContext context,
      Future<void> Function() action,
      String successMessage,
      String errorMessage,
    ) async {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      nav.push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.black26,
          pageBuilder:
              (_, __, ___) => AlertDialog(
                content: Row(
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(width: 16),
                    const Text('처리 중...'),
                  ],
                ),
              ),
        ),
      );
      try {
        await action();
        nav.pop();
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      } catch (e) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('$errorMessage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final cachedUser = postsProvider.getUser(post['userId']);

    return FutureBuilder<MyUser>(
      future:
          cachedUser != null
              ? Future.value(cachedUser)
              : postsProvider.loadUser(post['userId']),
      initialData: cachedUser,
      builder: (context, snapshot) {
        final isWaiting =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final bool userMissing =
            !isWaiting &&
            (snapshot.hasError ||
                !snapshot.hasData ||
                (snapshot.data?.userId ?? '').isEmpty);
        final myuser = snapshot.data;
        final displayName =
            isWaiting
                ? '로딩 중...'
                : (myuser?.name.isNotEmpty == true ? myuser!.name : '삭제된 사용자');
        final profileUrl =
            (!userMissing && !isWaiting) ? (myuser?.url ?? '') : '';

        final List imgUrls =
            (post['imgUrls'] != null && (post['imgUrls'] as List).isNotEmpty)
                ? post['imgUrls'] as List
                : [];

        Widget content = IgnorePointer(
          ignoring: isWaiting,
          child: Column(
            children: [
              // ── fromComments branch ───────────────────────────────────────
              if (post['fromComments'] == true)
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5, left: 10, right: 10),
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
                                width: 48,
                                height: 48,
                                decoration: ShapeDecoration(
                                  image: DecorationImage(
                                    image:
                                        profileUrl.isNotEmpty
                                            ? NetworkImage(profileUrl)
                                            : const AssetImage(
                                                  'assets/avatar.png',
                                                )
                                                as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                  shape: const OvalBorder(),
                                ),
                              ),
                            ),
                            horizontalSpace(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  isWaiting
                                      ? Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(
                                          width: 80,
                                          height: 16,
                                          color: Colors.white,
                                          margin: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                        ),
                                      )
                                      : Text(
                                        displayName,
                                        style: TextStyles.abeezee16px400wPblack
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                          return const SizedBox(height: 16);
                                        }
                                        if (subSnap.hasError) {
                                          return const Text(
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
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            '구독자 ...명', // formatted removed for simplicity
                                            style: TextStyle(
                                              color: Color(0xFF787878),
                                              fontSize: 16,
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              height: 1.40,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            isGuest
                                ? const SizedBox.shrink()
                                : OtherPostMenu(
                                  postId: post['postId'] ?? '',
                                  userId: myuser?.userId ?? '',
                                  onRunWithLoading: runWithLoading,
                                  displayName: displayName,
                                  profileUrl: profileUrl,
                                  postData: post,
                                ),
                          ],
                        ),
                        if (post['text'] != null &&
                            post['text'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Text(
                              post['text'].toString(),
                              style: const TextStyle(
                                color: Color(0xFF343434),
                                fontSize: 18,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w500,
                                height: 1.40,
                              ),
                            ),
                          ),
                        verticalSpace(5),
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
                              child: const Icon(Icons.close),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                            width: 48,
                            height: 48,
                            decoration: ShapeDecoration(
                              image: DecorationImage(
                                image:
                                    profileUrl.isNotEmpty
                                        ? NetworkImage(profileUrl)
                                        : const AssetImage('assets/avatar.png')
                                            as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                              shape: const OvalBorder(),
                            ),
                          ),
                        ),
                        horizontalSpace(10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              isWaiting
                                  ? Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      width: 80,
                                      height: 16,
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(bottom: 2),
                                    ),
                                  )
                                  : Text(
                                    displayName,
                                    style: TextStyles.abeezee16px400wPblack
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                              if (post['text'] != null &&
                                  post['text'].toString().trim().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Text(
                                    post['text'].toString(),
                                    style: TextStyle(
                                      color: Color(0xFF343434),
                                      fontSize: 16,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      height: 1.40,
                                    ),
                                  ),
                                ),
                              verticalSpace(5),
                              if (imgUrls.isNotEmpty)
                                NaturalAspectPageView(
                                  imgUrls: imgUrls,
                                  pageController: _pageController,
                                ),
                              verticalSpace(5),
                              Row(children: [GuestPostActions(post: post)]),
                            ],
                          ),
                        ),
                        isGuest
                            ? const SizedBox.shrink()
                            : OtherPostMenu(
                              postId: post['postId'] ?? '',
                              userId: myuser?.userId ?? '',
                              onRunWithLoading: runWithLoading,
                              displayName: displayName,
                              profileUrl: profileUrl,
                              postData: post,
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );

        return isWaiting
            ? Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: content,
            )
            : content;
      },
    );
  }
}
