import 'package:ecommerece_app/features/auth/auth_screen.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<FirebaseUserRepo>(context, listen: false);
    return StreamBuilder<MyUser?>(
      stream: authRepo.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return AuthScreen();
        } else {
          return MyPageScreen();
        }
      },
    );
  }
}
