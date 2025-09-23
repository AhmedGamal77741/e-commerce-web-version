import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class CancelSubscription extends StatefulWidget {
  const CancelSubscription({super.key});

  @override
  State<CancelSubscription> createState() => _CancelSubscriptionState();
}

List<String> options = ['월 회비가 비쌈', '최근 쇼핑 횟수가 줄었음', '살만한 물건이 없음', '기타'];

class _CancelSubscriptionState extends State<CancelSubscription> {
  String currentOption = options[0];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('프리미엄 멤버십 해지', style: TextStyles.abeezee16px400wPblack),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '서비스 개선을 위해 프리미엄\n멤버십을 해지하는 이유를\n알려주세요',
                textAlign: TextAlign.center,
                style: TextStyles.abeezee20px400wPblack,
              ),
              verticalSpace(30),
              ListTile(
                title: Text(
                  options[0],
                  style: TextStyles.abeezee16px400wPblack,
                ),
                leading: Radio(
                  value: options[0],
                  groupValue: currentOption,
                  onChanged: (val) {
                    setState(() {
                      currentOption = val.toString();
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  options[1],
                  style: TextStyles.abeezee16px400wPblack,
                ),
                leading: Radio(
                  value: options[1],
                  groupValue: currentOption,
                  onChanged: (val) {
                    setState(() {
                      currentOption = val.toString();
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  options[2],
                  style: TextStyles.abeezee16px400wPblack,
                ),
                leading: Radio(
                  value: options[2],
                  groupValue: currentOption,
                  onChanged: (val) {
                    setState(() {
                      currentOption = val.toString();
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  options[3],
                  style: TextStyles.abeezee16px400wPblack,
                ),
                leading: Radio(
                  value: options[3],
                  groupValue: currentOption,
                  onChanged: (val) {
                    setState(() {
                      currentOption = val.toString();
                    });
                  },
                ),
              ),
              verticalSpace(30),
              WideTextButton(
                txt: '해지하기',
                color: Colors.white,
                txtColor: ColorsManager.primaryblack,
                func: () async {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: Text(
                            '프리미엄 멤버십 해지',
                            style: TextStyles.abeezee17px800wPblack,
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '정말로 프리미엄 멤버십을 해지하시겠습니까?',
                                style: TextStyles.abeezee16px400wPblack,
                              ),
                              SizedBox(height: 12),
                              Text(
                                '해지해도 다음 결제일까지 프리미엄 혜택이 유지됩니다.',
                                style: TextStyles.abeezee13px400wP600,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '결제일 이후에는 자동으로 일반 회원으로 전환됩니다.',
                                style: TextStyles.abeezee13px400wP600,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '결제일 이전에 언제든지 재구독할 수 있습니다.',
                                style: TextStyles.abeezee13px400wP600,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                '취소',
                                style: TextStyle(color: Colors.black),
                              ),
                              onPressed: () => navigator.pop(false),
                            ),
                            WideTextButton(
                              txt: '해지',
                              color: Colors.black,
                              txtColor: Colors.white,
                              func: () => navigator.pop(true),
                            ),
                          ],
                        ),
                  );
                  if (confirmed != true) return;
                  final userId = FirebaseAuth.instance.currentUser!.uid;
                  final subSnap =
                      await FirebaseFirestore.instance
                          .collection('subscriptions')
                          .where('userId', isEqualTo: userId)
                          .orderBy('nextBillingDate', descending: true)
                          .limit(1)
                          .get();
                  final docRef =
                      FirebaseFirestore.instance.collection('cancels').doc();
                  final cancelId = docRef.id;
                  final cancelData = {
                    'cancelId': cancelId,
                    'userId': userId,
                    'reason': currentOption.trim(),
                    'createdAt': DateTime.now().toIso8601String(),
                  };
                  try {
                    await docRef.set(cancelData);
                    if (subSnap.docs.isNotEmpty) {
                      await subSnap.docs.first.reference.update({
                        'status': 'canceled',
                      });
                    }
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('멤버십이 성공적으로 해지되었습니다.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('사유 저장 실패. 다시 시도해주세요.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
