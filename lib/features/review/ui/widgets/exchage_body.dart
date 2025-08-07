import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:flutter/material.dart';

class ExchangeBody extends StatelessWidget {
  final String userId;
  final String orderId;
  final _formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  ExchangeBody({super.key, required this.userId, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Text('사유', style: TextStyles.abeezee16px400wPblack),
                ),
                Divider(color: ColorsManager.primary100),
                TextFormField(
                  controller: reasonController,
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
          color: ColorsManager.primary500,
          txtColor: ColorsManager.white,
          func: () async {
            if (!_formKey.currentState!.validate()) return;
            // Fetch order date
            final orderDoc =
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .get();
            if (!orderDoc.exists) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('주문 정보를 찾을 수 없습니다.')));
              return;
            }
            final orderDataMap = orderDoc.data();
            final orderDateStr = orderDataMap?['orderDate'];
            if (orderDateStr == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('주문 날짜 정보가 없습니다.')));
              return;
            }
            final orderDate = DateTime.tryParse(orderDateStr);
            if (orderDate == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('주문 날짜 형식이 올바르지 않습니다.')));
              return;
            }
            final now = DateTime.now();
            final daysSinceOrder = now.difference(orderDate).inDays;
            if (daysSinceOrder > 7) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('주문 후 7일이 지나 교환 요청이 불가합니다.')),
              );
              return;
            }
            final docRef =
                FirebaseFirestore.instance.collection('exchanges').doc();
            final exchangeId = docRef.id;
            final exchangeData = {
              'exchangeId': exchangeId,
              'userId': userId,
              'orderId': orderId,
              'reason': reasonController.text.trim(),
              'createdAt': DateTime.now().toIso8601String(),
            };
            try {
              await docRef.set(exchangeData);
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .update({'isRequested': true});
              context.pop();
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('요청에 실패했습니다. 다시 시도하세요.')));
            }
          },
        ),
      ],
    );
  }
}
