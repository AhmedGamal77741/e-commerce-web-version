import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecommerece_app/core/routing/routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BankRegisteredScreen
//
// Shown when the OS intercepts app.pang2chocolate.com/bank-registered after
// Payple bank account registration. Reads success/failure from query params:
//   • success=true  → snackbar "계좌가 등록되었습니다 ✓" → back to place-order
//   • success=false → snackbar with error message → back to place-order
//
// Intentionally minimal — exists only to catch the deep link, show feedback,
// and get the user back to checkout immediately.
// ─────────────────────────────────────────────────────────────────────────────

class BankRegisteredScreen extends StatefulWidget {
  final bool success;
  final String userId;
  final String paymentId;
  final String message;

  const BankRegisteredScreen({
    super.key,
    required this.success,
    required this.userId,
    required this.paymentId,
    required this.message,
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

  void _handleResult() {
    if (!mounted) return;

    if (widget.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계좌가 등록되었습니다 ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
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

    // go() replaces stack so user can't back-navigate to this screen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) context.go(Routes.placeOrderScreen);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Visible for ~300ms before redirect
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
