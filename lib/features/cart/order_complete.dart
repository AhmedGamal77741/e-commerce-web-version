import 'dart:async'; // Import for Timer

import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:flutter/material.dart';

class OrderComplete extends StatefulWidget {
  const OrderComplete({super.key});

  @override
  State<OrderComplete> createState() => _OrderCompleteState();
}

class _OrderCompleteState extends State<OrderComplete> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoCloseTimer();
  }

  void _startAutoCloseTimer() {
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        // Ensure the widget is still in the tree
        context.pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: You might want a semi-transparent background if this is
      // meant to look like a modal overlaying another screen.
      // backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: TextButton(
          onPressed: () {
            _timer?.cancel(); // Cancel timer if manually closed
            if (mounted) {
              context.pop();
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF121212), // Background color
            foregroundColor: Colors.white, // Text color for ripple, etc.
            minimumSize: Size(220, 45), // Exact dimensions
            padding: EdgeInsets.zero, // Remove default padding
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 1, // Border width
                color: Color(0xFF121212), // Border color
              ),
              borderRadius: BorderRadius.circular(8), // Corner radius
            ),
            elevation: 0, // Remove shadow
          ),
          child: Text(
            '주문 완료', // "Order Completed"
            style: TextStyle(
              color: const Color(0xFFF5F5F5), // Text color
              fontSize: 18,
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w400,
              height:
                  1.40, // TextStyle height is a factor, not pixels. Removed .h
            ),
          ),
        ),
      ),
    );
  }
}
