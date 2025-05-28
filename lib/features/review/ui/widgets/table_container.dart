import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/table_text_row.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TableContainer extends StatefulWidget {
  final String orderId;

  TableContainer({super.key, required this.orderId});

  @override
  State<TableContainer> createState() => _TableContainerState();
}

class _TableContainerState extends State<TableContainer> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final orderStream =
        FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots();

    return Container(
      decoration: ShapeDecoration(
        color: ColorsManager.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: ColorsManager.primary100),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Column(
        children: [
          TbaleTextRow(
            firstElment: '시간',
            secondElment: '현재\n위치',
            thirdElment: '상태',
            style: TextStyles.abeezee16px400wPblack,
          ),
          Divider(color: ColorsManager.primary100),
          StreamBuilder(
            stream: orderStream,

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('Order not found.'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final trackOrder =
                  data['trackingEvents']['edges'] as List<dynamic>?;
              print('${trackOrder} 5555');
              if (trackOrder == null || trackOrder.isEmpty) {
                return Center(child: Text('No tracking updates yet.'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: trackOrder.length,
                itemBuilder: (context, index) {
                  final event = trackOrder[index];

                  return index % 2 == 0
                      ? TbaleTextRow(
                        firstElment: formatIsoDateTime(event['node']['time']),
                        secondElment: event['node']['status']['name'],
                        thirdElment: event['node']['description'],
                        style: TextStyles.abeezee16px400wP600,
                      )
                      : TbaleTextRow(
                        firstElment: formatIsoDateTime(event['node']['time']),
                        secondElment: event['node']['status']['name'],
                        thirdElment: event['node']['description'],
                        style: TextStyles.abeezee16px400wPblack,
                      );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

String formatIsoDateTime(
  String isoString, {
  String pattern = 'yyyy-MM-dd HH:mm',
}) {
  try {
    final dateTime = DateTime.parse(isoString);
    final formatter = DateFormat(pattern);
    return formatter.format(dateTime);
  } catch (e) {
    return 'Invalid date';
  }
}
