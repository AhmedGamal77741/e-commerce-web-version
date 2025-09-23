import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/mypage/data/firebas_funcs.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final reasonController = TextEditingController();

  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 탈퇴', style: TextStyles.abeezee16px400wPblack),
        centerTitle: true,
      ),

      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '서비스 개선을 위해\n 멤버십을 해지하는 이유를 알려주세요',
              textAlign: TextAlign.center,
              style: TextStyles.abeezee20px400wPblack,
            ),
            verticalSpace(30),
            Container(
              decoration: ShapeDecoration(
                color: ColorsManager.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1, color: ColorsManager.primary100),
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 25,
                      ),
                      child: Text(
                        '사유',
                        style: TextStyles.abeezee16px400wPblack,
                      ),
                    ),
                    Divider(color: ColorsManager.primary100),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 10,
                      minLines: 6,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: "입력",
                        hintStyle: TextStyles.abeezee16px400wP600,
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                      ),
                      validator: (val) {
                        if (val!.isEmpty) {
                          return '이름을 입력하세요';
                        } else if (val.length > 30) {
                          return '이름이 너무 깁니다';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            verticalSpace(50),
            WideTextButton(
              txt: '요청하기',
              color: ColorsManager.white,
              txtColor: ColorsManager.primaryblack,
              func: () async {
                if (!_formKey.currentState!.validate()) return;

                final confirmed = await showDeleteAccountDialog(context);
                if (confirmed) {
                  try {
                    // Store delete reason in 'deletes' collection only
                    final docRef =
                        FirebaseFirestore.instance.collection('deletes').doc();
                    final deleteId = docRef.id;
                    final deleteData = {
                      'deleteId': deleteId,
                      'userId': userId,
                      'reason': reasonController.text.trim(),
                      'createdAt': DateTime.now().toIso8601String(),
                    };
                    await docRef.set(deleteData);

                    // Soft delete: mark user as deleted in Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({
                          'deleted': true,
                          'deletedAt': DateTime.now().toIso8601String(),
                        });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('계정이 삭제 예약되었습니다. 30일 이내에 복구할 수 있습니다.'),
                        ),
                      );
                    }

                    // Sign out the user
                    await FirebaseAuth.instance.signOut();

                    if (mounted) {
                      context.pop();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('계정 삭제 실패. 다시 시도해주세요.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obsecurePassword = true;
  IconData iconPassword = Icons.visibility_off;
  bool isLoading = false;
  String? errorMsg;

  return await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('탈퇴 확인'),
        content: const Text('정말로 계정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            child: Text('취소 ', style: TextStyles.abeezee13px400wPblack),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BlackTextButton(
            txt: '계정 삭제',
            func: () async {
              Navigator.of(context).pop(true);
            },
            style: TextStyles.abeezee14px400wW,
          ),
        ],
      );
    },
  ).then((value) => value ?? false); // return false if null
}
