import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/review/ui/widgets/avatar_and_title.dart';
import 'package:ecommerece_app/features/review/ui/widgets/img_and_text.dart';
import 'package:ecommerece_app/features/review/ui/widgets/rating_and_complete.dart';
import 'package:ecommerece_app/features/review/ui/widgets/rep_filed.dart';
import 'package:flutter/material.dart';

class LeaveReview extends StatelessWidget {
  const LeaveReview({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            AvatarAndTitle(),
            verticalSpace(10),
            RatingAndComplete(),
            verticalSpace(10),
            RepField(),
            verticalSpace(10),
            ImgAndTxt(),
            Divider(color: ColorsManager.primary600),
          ],
        ),
      ),
    );
  }
}
