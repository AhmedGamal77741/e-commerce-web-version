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
        backgroundColor: Colors.white,
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
                  final userId = FirebaseAuth.instance.currentUser!.uid;
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
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({'isSub': false});
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
