import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/review/ui/widgets/delivery_status.dart';
import 'package:ecommerece_app/features/review/ui/widgets/delivery_text_row.dart';
import 'package:ecommerece_app/features/review/ui/widgets/table_container.dart';
import 'package:flutter/material.dart';

class TrackOrder extends StatefulWidget {
  final Map<String, dynamic> order;
  final String arrivalDate;
  const TrackOrder({super.key, required this.order, required this.arrivalDate});

  @override
  State<TrackOrder> createState() => _TrackOrderState();
}

class _TrackOrderState extends State<TrackOrder> {
  late Map<String, dynamic> order;
  late String arrivalDate;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    order = widget.order;
    arrivalDate = widget.arrivalDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorsManager.white,
        title: Text('배송조회', style: TextStyles.abeezee16px400wPblack),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),

        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(arrivalDate, style: TextStyles.abeezee20px400wPblack),
              verticalSpace(40),
              DeliveryStatus(orderStatus: order['orderStatus']),
              verticalSpace(10),
              DeliveryTextRow(orderStatus: order['orderStatus']),
              verticalSpace(30),
              TableContainer(orderId: order['orderId']),
            ],
          ),
        ),
      ),
    );
  }
}
