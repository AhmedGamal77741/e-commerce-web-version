import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/routing/app_router.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/review/ui/order_history.dart';

// app router (root-level GoRouter)
import 'package:ecommerece_app/core/routing/app_router.dart';

class UserOptionsContainer extends StatefulWidget {
  final bool isSub;
  const UserOptionsContainer({super.key, required this.isSub});

  @override
  State<UserOptionsContainer> createState() => _UserOptionsContainerState();
}

class _UserOptionsContainerState extends State<UserOptionsContainer>
    with RouteAware {
  final user = FirebaseAuth.instance.currentUser;
  final ChatService _chatService = ChatService();
  final String supportUserId = 'JuxEfED9YSc2XyHRFgkPcNCFUSJ3';

  bool _isLoading = false;

  Future<void> openSupportChat(BuildContext context) async {
    if (_isLoading) return;
    if (user == null) return;

    if (user!.uid == supportUserId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('고객센터 계정에서는 고객센터 채팅을 이용할 수 없습니다.')),
        );
      }
      return;
    }

    // show inline loader
    if (mounted) setState(() => _isLoading = true);

    try {
      final chatRoomId = await _chatService.createDirectChatRoom(
        supportUserId,
        true,
      );

      if (chatRoomId == null || chatRoomId.isEmpty) {
        throw Exception('Failed to create chat room');
      }

      // Fetch support name (best-effort)
      String supportName = '고객센터';
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(supportUserId)
                .get();
        final data = doc.data();
        if (doc.exists &&
            data != null &&
            (data['name'] as String?)?.isNotEmpty == true) {
          supportName = data['name'] as String;
        }
      } catch (_) {
        // ignore - keep fallback
      }

      // Clear loading BEFORE navigation so UI updates and doesn't look stuck
      if (mounted) setState(() => _isLoading = false);

      // Navigate using app-level router (root navigation — won't be cancelled by local rebuilds)
      // Use named route with params to match your router.dart
      AppRouter.router.pushNamed(
        Routes.chatScreen,
        pathParameters: {'id': chatRoomId},
        extra: {'name': supportName},
      );
    } catch (e, st) {
      // optional: print('openSupportChat error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('고객센터 채팅방 생성에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> resubscribeDialog(DateTime nextBillingDate) async {
    final formattedDate =
        "${nextBillingDate.year}-${nextBillingDate.month.toString().padLeft(2, '0')}-${nextBillingDate.day.toString().padLeft(2, '0')}";
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              '프리미엄 멤버십 재구독',
              style: TextStyles.abeezee17px800wPblack,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '프리미엄 멤버십을 다시 활성화하시겠습니까?',
                  style: TextStyles.abeezee16px400wPblack,
                ),
                SizedBox(height: 12),
                Text(
                  '다음 결제일($formattedDate)까지 프리미엄 혜택이 유지됩니다.',
                  style: TextStyles.abeezee13px400wP600,
                ),
                SizedBox(height: 8),
                Text(
                  '결제일 이후에는 자동 결제가 재개됩니다.',
                  style: TextStyles.abeezee13px400wP600,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('취소', style: TextStyle(color: Colors.black)),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              BlackTextButton(
                txt: '재구독',
                func: () => Navigator.of(ctx).pop(true),
                style: TextStyles.abeezee16px400wW,
              ),
            ],
          ),
    );
    if (confirmed == true) {
      final subSnap =
          await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('nextBillingDate', descending: true)
              .limit(1)
              .get();
      if (subSnap.docs.isNotEmpty) {
        await subSnap.docs.first.reference.update({'status': 'active'});
        // Delete any cancel document for this user
        final cancelsSnap =
            await FirebaseFirestore.instance
                .collection('cancels')
                .where('userId', isEqualTo: user!.uid)
                .get();
        for (final doc in cancelsSnap.docs) {
          await doc.reference.delete();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('재구독이 완료되었습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Center(child: Text('로그인이 필요합니다.'));
    }
    final isSupport = user?.uid == supportUserId;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('nextBillingDate', descending: true)
              .limit(1)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        bool? isSub;
        String? subStatus;
        DateTime? nextBillingDate;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data();
          isSub =
              (data['status'] == 'active' ||
                  (data['status'] == 'canceled' &&
                      (data['nextBillingDate']?.toDate()?.isAfter(
                            DateTime.now(),
                          ) ??
                          false)));
          subStatus = data['status'];
          nextBillingDate = data['nextBillingDate']?.toDate();
        } else {
          isSub = false;
          subStatus = null;
          nextBillingDate = null;
        }
        return Container(
          decoration: ShapeDecoration(
            color: ColorsManager.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1, color: ColorsManager.primary100),
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReviewScreen()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주문내역',
                        style: TextStyles.abeezee17px800wPblack.copyWith(
                          color: isSupport ? Colors.grey : null,
                        ),
                      ),
                      verticalSpace(5),
                      // Horizontal, scrollable gallery of the user's recent order images
                      StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('orders')
                                .where('userId', isEqualTo: user!.uid)
                                .limit(10)
                                .snapshots(),
                        builder: (context, orderSnap) {
                          if (orderSnap.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              height: 40,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (!orderSnap.hasData ||
                              orderSnap.data!.docs.isEmpty) {
                            return Text(
                              '주문이 없습니다.',
                              style: TextStyles.abeezee11px400wP600.copyWith(
                                color: isSupport ? Colors.grey : null,
                              ),
                            );
                          }

                          final orders = orderSnap.data!.docs;

                          return SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: orders.length,
                              itemBuilder: (context, i) {
                                final data =
                                    orders[i].data() as Map<String, dynamic>;
                                final productId = data['productId'] as String?;
                                if (productId == null) return SizedBox.shrink();

                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future:
                                        FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(productId)
                                            .get(),
                                    builder: (context, prodSnap) {
                                      if (prodSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                        );
                                      }

                                      if (!prodSnap.hasData ||
                                          !prodSnap.data!.exists) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                          ),
                                        );
                                      }

                                      final prod =
                                          prodSnap.data!.data()
                                              as Map<String, dynamic>;
                                      final imgUrl =
                                          (prod['imgUrl'] as String?) ?? '';

                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child:
                                            imgUrl.isNotEmpty
                                                ? Image.network(
                                                  imgUrl,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                )
                                                : Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.grey[200],
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Divider(color: ColorsManager.primary100),
                  Container(
                    decoration: BoxDecoration(
                      color: isSupport ? Colors.grey[200] : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap:
                          (isSupport || _isLoading)
                              ? null
                              : () => openSupportChat(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '고객센터 연결',
                                  style: TextStyles.abeezee17px800wPblack
                                      .copyWith(
                                        color: isSupport ? Colors.grey : null,
                                      ),
                                ),
                                Text(
                                  '고객센터 운영시간 : 09:00시 ~ 16:30시',
                                  style: TextStyles.abeezee11px400wP600
                                      .copyWith(
                                        color: isSupport ? Colors.grey : null,
                                      ),
                                ),
                              ],
                            ),
                            if (_isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Divider(color: ColorsManager.primary100),
                  if (isSub == true && subStatus == 'active')
                    InkWell(
                      child: Text(
                        '프리미엄 멤버십 해지',
                        style: TextStyles.abeezee17px800wPblack,
                      ),
                      onTap: () async {
                        await context.push(Routes.cancelSubscription);
                      },
                    )
                  else if (isSub == true &&
                      subStatus == 'canceled' &&
                      (nextBillingDate?.isAfter(DateTime.now()) ?? false))
                    InkWell(
                      onTap:
                          nextBillingDate == null
                              ? null
                              : () => resubscribeDialog(nextBillingDate!),
                      child: Text(
                        '재구독',
                        style: TextStyles.abeezee17px800wPblack,
                      ),
                    )
                  else
                    InkWell(
                      child: Text(
                        '프리미엄 멤버십 가입',
                        style: TextStyles.abeezee17px800wPblack,
                      ),
                      onTap: () async {
                        _launchPaymentPage('10000', user!.uid);
                      },
                    ),
                  if (isSub == true && nextBillingDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                      child: Text(
                        '다음 결제일: ${nextBillingDate.year}-${nextBillingDate.month.toString().padLeft(2, '0')}-${nextBillingDate.day.toString().padLeft(2, '0')}',
                        style: TextStyles.abeezee11px400wP600,
                      ),
                    ),
                  Text(
                    '월 회비 : 10,000원 혜택 : 전 제품 20% 할인',
                    style: TextStyles.abeezee11px400wP600,
                  ),
                  Divider(color: ColorsManager.primary100),
                  InkWell(
                    child: Text(
                      '회원탈퇴',
                      style: TextStyles.abeezee17px800wPblack,
                    ),
                    onTap: () async {
                      if (isSub == true) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text(
                                  '회원탈퇴 안내',
                                  style: TextStyles.abeezee17px800wPblack,
                                ),
                                content: Text(
                                  '프리미엄 멤버십이 영구적으로 삭제됩니다.\n정말로 회원탈퇴를 진행하시겠습니까?',
                                  style: TextStyles.abeezee16px400wPblack,
                                ),
                                actions: [
                                  TextButton(
                                    child: Text(
                                      '취소',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                  ),
                                  BlackTextButton(
                                    txt: '탈퇴',
                                    func: () => Navigator.of(ctx).pop(true),
                                    style: TextStyles.abeezee16px400wW,
                                  ),
                                ],
                              ),
                        );
                        if (confirmed == true) {
                          context.go(Routes.deleteAccount);
                        }
                      } else {
                        context.go(Routes.deleteAccount);
                      }
                    },
                  ),
                  Text(
                    '멤버십 해지 후 탈퇴 가능합니다.',
                    style: TextStyles.abeezee11px400wP600,
                  ),
                  Divider(color: ColorsManager.primary100),
                  InkWell(
                    child: Text(
                      '입점신청',
                      style: TextStyles.abeezee17px800wPblack,
                    ),
                    onTap: () {
                      _launchPartnerPage();
                    },
                  ),
                  Text(
                    '‘좋은 제품 좋은 가격’ 이라면 누구나 입점 가능합니다.',
                    style: TextStyles.abeezee11px400wP600,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _launchPaymentPage(String amount, String userId) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/web-payment.html?amount=$amount&userId=$userId',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}

void _launchPartnerPage() async {
  final url = Uri.parse('https://tally.so/r/w5O556');
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}
