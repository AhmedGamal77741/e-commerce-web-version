import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/mypage/data/firebas_funcs.dart';
import 'package:ecommerece_app/features/mypage/ui/widgets/user_info_container.dart';
import 'package:ecommerece_app/features/mypage/ui/widgets/user_options_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("User data not found."));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final bool isSub = userData['isSub'] == true;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              children: [
                isSub
                    ? Text('프리미엄 회원', style: TextStyles.abeezee17px800wPblack)
                    : Text('일반 회원', style: TextStyles.abeezee17px800wPblack),
                verticalSpace(20),
                UserInfoContainer(),
                verticalSpace(30),
                UserOptionsContainer(isSub: isSub),
                verticalSpace(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _launchTermsPage();
                      },
                      child: Text(
                        '이용약관',
                        style: TextStyles.abeezee13px400wP600,
                      ),
                    ),
                    horizontalSpace(5),
                    Text('/', style: TextStyles.abeezee13px400wP600),
                    horizontalSpace(5),
                    GestureDetector(
                      onTap: () async {
                        await signOut();
                      },
                      child: Text(
                        '로그아웃',
                        style: TextStyles.abeezee13px400wP600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _launchTermsPage() async {
  final url = Uri.parse(
    'https://flowery-tub-f11.notion.site/1d938af9230b80fa9d64ce280f6eacbd',
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
