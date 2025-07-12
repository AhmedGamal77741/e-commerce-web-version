import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:flutter/material.dart';

class RefundBody extends StatelessWidget {
  final reasonController = TextEditingController();
  // final accountNumberController = TextEditingController();
  // final bankController = TextEditingController();
  // final accountOwnerController = TextEditingController();
  final String userId;
  final String orderId;

  final _formKey = GlobalKey<FormState>();
  RefundBody({super.key, required this.userId, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            decoration: ShapeDecoration(
              color: ColorsManager.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 1, color: ColorsManager.primary100),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Text('사유', style: TextStyles.abeezee16px400wPblack),
                ),
                Divider(color: ColorsManager.primary100),
                TextFormField(
                  maxLines: 6,
                  minLines: 4,
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
                  controller: reasonController,
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
          verticalSpace(50),
          // Container(
          //   decoration: ShapeDecoration(
          //     color: ColorsManager.white,
          //     shape: RoundedRectangleBorder(
          //       side: BorderSide(width: 1, color: ColorsManager.primary100),
          //       borderRadius: BorderRadius.circular(25),
          //     ),
          //   ),
          //   child: Padding(
          //     padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 20),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text('계좌번호', style: TextStyles.abeezee16px400wPblack),
          //         UnderlineTextField(
          //           controller: accountNumberController,
          //           hintText: '입력',
          //           obscureText: false,
          //           keyboardType: TextInputType.number,
          //           validator: (val) {
          //             if (val!.isEmpty) {
          //               return '이 필드를 작성해 주세요';
          //             } else if (val.length > 30) {
          //               return '이름이 너무 깁니다';
          //             }
          //             return null;
          //           },
          //         ),
          //         verticalSpace(15),
          //         Text('은행', style: TextStyles.abeezee16px400wPblack),
          //         UnderlineTextField(
          //           controller: bankController,
          //           hintText: '입력',
          //           obscureText: false,
          //           keyboardType: TextInputType.text,
          //           validator: (val) {
          //             if (val!.isEmpty) {
          //               return '이 필드를 작성해 주세요';
          //             } else if (val.length > 30) {
          //               return '이름이 너무 깁니다';
          //             }
          //             return null;
          //           },
          //         ),
          //         verticalSpace(15),
          //         Text('예금주', style: TextStyles.abeezee16px400wPblack),
          //         UnderlineTextField(
          //           controller: accountOwnerController,
          //           hintText: '입력',
          //           obscureText: false,
          //           keyboardType: TextInputType.name,
          //           validator: (val) {
          //             if (val!.isEmpty) {
          //               return '이 필드를 작성해 주세요';
          //             } else if (val.length > 30) {
          //               return '이름이 너무 깁니다';
          //             }
          //             return null;
          //           },
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          // verticalSpace(50),
          WideTextButton(
            txt: '요청하기',
            color: ColorsManager.primary500,
            txtColor: ColorsManager.white,
            func: () async {
              if (!_formKey.currentState!.validate()) return;
              final docRef =
                  FirebaseFirestore.instance.collection('refunds').doc();
              final refundId = docRef.id;
              final refundData = {
                'refundId': refundId,
                'userId': userId,
                'orderId': orderId,
                'reason': reasonController.text.trim(),
                'createdAt': DateTime.now().toIso8601String(),
              };
              try {
                await docRef.set(refundData);
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .update({'isRequested': true});

                context.pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('요청에 실패했습니다. 다시 시도하세요.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
