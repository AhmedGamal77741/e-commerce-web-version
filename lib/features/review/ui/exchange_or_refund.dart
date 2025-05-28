import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/review/ui/widgets/exchage_body.dart';
import 'package:ecommerece_app/features/review/ui/widgets/refund_body.dart';
import 'package:ecommerece_app/features/review/ui/widgets/req_button.dart';
import 'package:flutter/material.dart';

class ExchangeOrRefund extends StatefulWidget {
  final String userId;
  final String orderId;
  const ExchangeOrRefund({
    super.key,
    required this.userId,
    required this.orderId,
  });

  @override
  State<ExchangeOrRefund> createState() => _ExchangeOrRefundState();
}

class _ExchangeOrRefundState extends State<ExchangeOrRefund> {
  bool isRefund = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorsManager.white,
        title: Text('교환/반품 요청', style: TextStyles.abeezee16px400wPblack),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ReqButton(
                      txt: '교환/반품 요청',
                      color:
                          isRefund
                              ? ColorsManager.primaryblack
                              : ColorsManager.primary500,
                      func: () {
                        if (!isRefund) {
                          setState(() {
                            isRefund = true;
                          });
                        }
                      },
                    ),
                    horizontalSpace(20),
                    ReqButton(
                      txt: '새상품 교환',
                      color:
                          isRefund
                              ? ColorsManager.primary500
                              : ColorsManager.primaryblack,
                      func: () {
                        if (isRefund) {
                          setState(() {
                            isRefund = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
                verticalSpace(50),
                isRefund
                    ? RefundBody(userId: widget.userId, orderId: widget.orderId)
                    : ExchangeBody(
                      userId: widget.userId,
                      orderId: widget.orderId,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
