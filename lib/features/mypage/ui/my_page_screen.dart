import 'package:ecommerece_app/core/helpers/loading_service.dart';
import 'package:ecommerece_app/features/mypage/ui/my_page.dart';
import 'package:ecommerece_app/core/widgets/no_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';

class MyPageScreen extends StatefulWidget {
  final MyUser currentUser;
  const MyPageScreen({super.key, required this.currentUser});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _hasShownBankPrompt = false;

  @override
  void initState() {
    super.initState();
    _checkPendingBankPrompt();
  }

  Future<void> _checkPendingBankPrompt() async {
    // Small delay so the flag write in signup_screen is guaranteed
    // to be flushed to disk before we read it here.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('show_bank_prompt_after_login') ?? false;
    if (!shouldShow || !mounted) return;

    // Remove the flag immediately so it never fires twice
    await prefs.remove('show_bank_prompt_after_login');
    if (!mounted) return;

    if (!_hasShownBankPrompt && mounted) {
      _hasShownBankPrompt = true;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          // source: 'signup' → shows skip button, does NOT gate anything
          builder: (_) => const NoBankAccountScreen(source: 'signup'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(body: MyPage(currentUser: widget.currentUser)),
        ValueListenableBuilder<bool>(
          valueListenable: LoadingService().isLoading,
          builder: (context, isLoading, child) {
            return isLoading
                ? Container(
                  color: Colors.black54,
                  child: const SizedBox.shrink(),
                )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
