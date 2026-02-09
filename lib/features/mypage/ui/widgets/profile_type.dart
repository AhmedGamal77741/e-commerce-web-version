import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileType extends StatefulWidget {
  final bool isPrivate;
  final String userId;

  const ProfileType({super.key, required this.isPrivate, required this.userId});

  @override
  State<ProfileType> createState() => _ProfileTypeState();
}

class _ProfileTypeState extends State<ProfileType> {
  late bool isPrivate;

  @override
  void initState() {
    super.initState();
    isPrivate = widget.isPrivate;
  }

  Future<void> _updatePrivacy(bool value) async {
    final wasPrivate = isPrivate;
    setState(() => isPrivate = value);
    try {
      // If changing from private to public, accept all pending requests
      if (wasPrivate && !value) {
        await _acceptAllPendingRequests();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'isPrivate': value});
    } catch (e) {
      // If update fails, revert locally and optionally show error
      setState(() => isPrivate = !value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('설정 업데이트에 실패했습니다. 다시 시도해 주세요.')));
    }
  }

  Future<void> _acceptAllPendingRequests() async {
    try {
      final requestsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('followRequests')
              .get();

      if (requestsSnapshot.docs.isEmpty) {
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var requestDoc in requestsSnapshot.docs) {
        final requestingUserId = requestDoc.id;

        // Add to followers subcollection
        batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .doc(requestingUserId),
          {
            'userId': requestingUserId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        // Add to requesting user's following subcollection
        batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(requestingUserId)
              .collection('following')
              .doc(widget.userId),
          {'userId': widget.userId, 'createdAt': FieldValue.serverTimestamp()},
        );

        // Delete the follow request
        batch.delete(requestDoc.reference);
      }

      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('요청 처리 중 오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isPrivate ? '비공개 프로필' : '공개 프로필',
          style: TextStyles.abeezee17px800wPblack,
        ),
        verticalSpace(20),
        Container(
          decoration: ShapeDecoration(
            color: ColorsManager.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1, color: ColorsManager.primary100),
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 20, 25, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이름', style: TextStyles.abeezee17px800wPblack),
                verticalSpace(30),
                Divider(color: ColorsManager.primary100),
                verticalSpace(10),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '비공개 프로필',
                          style: TextStyles.abeezee17px800wPblack,
                        ),
                        verticalSpace(5),
                        Text(
                          '비공개로 전환하면, 친구로 수락한\n사람만 회원님을 구독하고 게시물\n을 볼 수 있어요.',
                          style: TextStyles.abeezee13px400wP600,
                        ),
                      ],
                    ),
                    Spacer(),
                    Transform.scale(
                      scale: 1.3,
                      child: CupertinoSwitch(
                        value: isPrivate,
                        onChanged: (s) async {
                          await _updatePrivacy(s);
                        },
                        activeTrackColor: Colors.black,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
