import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecommerece_app/core/routing/routes.dart';

class BankRegisteredScreen extends StatefulWidget {
  final bool success;
  final String userId;
  final String paymentId;
  final String message;
  final String source; // 'shop' or 'sub'

  const BankRegisteredScreen({
    super.key,
    required this.success,
    required this.userId,
    required this.paymentId,
    required this.message,
    this.source = 'shop',
  });

  @override
  State<BankRegisteredScreen> createState() => _BankRegisteredScreenState();
}

class _BankRegisteredScreenState extends State<BankRegisteredScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleResult());
  }

  Future<void> _handleResult() async {
    if (!mounted) return;

    if (widget.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계좌가 등록되었습니다 ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // Save pending source so NavBar knows where to resume after redirect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_nav_source', widget.source);
    } else {
      final errorMsg =
          widget.message.isNotEmpty
              ? widget.message
              : '계좌 등록에 실패했습니다. 다시 시도해 주세요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Always go to NavBar — gates will re-run from there
    context.go(Routes.navBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.success
                ? const Icon(
                  Icons.account_balance,
                  size: 56,
                  color: Colors.black,
                )
                : const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              widget.success ? '계좌 등록 완료' : '계좌 등록 실패',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'NotoSans',
              ),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}
