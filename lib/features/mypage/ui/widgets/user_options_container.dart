import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String supportUserId = '4hSVptbp63W7Ctl05FjbVUkOO9u1';

  Future<void> openSupportChat(BuildContext context) async {
    if (user == null) return;
    if (user?.uid == supportUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('고객센터 계정에서는 고객센터 채팅을 이용할 수 없습니다.')),
      );
      return;
    }
    String? chatRoomId;
    try {
      chatRoomId = await _chatService.createDirectChatRoom(supportUserId, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('고객센터 채팅방 생성에 실패했습니다.')));
      return;
    }
    // Get support user name (optional, fallback to '고객센터')
    String supportName = '고객센터';
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(supportUserId)
              .get();
      if (doc.exists && doc.data()?['name'] != null) {
        supportName = doc.data()!['name'];
      }
    } catch (_) {}
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                ChatScreen(chatRoomId: chatRoomId!, chatRoomName: supportName),
      ),
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isSupport ? Colors.grey[200] : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: isSupport ? null : () => openSupportChat(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '고객센터 연결',
                            style: TextStyles.abeezee17px800wPblack.copyWith(
                              color: isSupport ? Colors.grey : null,
                            ),
                          ),
                          Text(
                            '고객센터 운영시간 : 10:00시 ~ 23:00시',
                            style: TextStyles.abeezee11px400wP600.copyWith(
                              color: isSupport ? Colors.grey : null,
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
                    child: Text('재구독', style: TextStyles.abeezee17px800wPblack),
                    onTap:
                        nextBillingDate == null
                            ? null
                            : () => resubscribeDialog(nextBillingDate!),
                  )
                else
                  InkWell(
                    child: Text(
                      '프리미엄 멤버십 가입',
                      style: TextStyles.abeezee17px800wPblack,
                    ),
                    onTap: () async {
                      _launchPaymentPage('3000', user!.uid);
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
                  '월 회비 : 3,000원 혜택 : 전 제품 10% 할인',
                  style: TextStyles.abeezee11px400wP600,
                ),
                Divider(color: ColorsManager.primary100),
                InkWell(
                  child: Text('회원탈퇴', style: TextStyles.abeezee17px800wPblack),
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
                                  onPressed: () => Navigator.of(ctx).pop(false),
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
                  child: Text('입점신청', style: TextStyles.abeezee17px800wPblack),
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
        );
      },
    );
  }
}

void _launchPaymentPage(String amount, String userId) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/payment.html?amount=$amount&userId=$userId',
  );

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      // mode: LaunchMode.externalApplication, // Forces external browser
    );
  } else {
    throw 'Could not launch $url';
  }
}

void _launchPartnerPage() async {
  final url = Uri.parse('https://tally.so/r/w5O556');

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      // mode: LaunchMode.externalApplication, // Forces external browser
    );
  } else {
    throw 'Could not launch $url';
  }
}
