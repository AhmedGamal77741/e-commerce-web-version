import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class NoBankAccountScreen extends StatefulWidget {
  final String source; // 'shop' or 'sub'
  const NoBankAccountScreen({super.key, this.source = 'shop'});

  @override
  State<NoBankAccountScreen> createState() => _NoBankAccountScreenState();
}

class _NoBankAccountScreenState extends State<NoBankAccountScreen> {
  bool _isLaunching = false;

  Future<void> _launchBankRegistration() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String phoneNo = '';
    try {
      final cache =
          await FirebaseFirestore.instance
              .collection('usercached_values')
              .doc(uid)
              .get();
      phoneNo = (cache.data()?['phone'] as String?) ?? '';
    } catch (_) {}

    final uri = Uri.parse(
      'https://pay.pang2chocolate.com/web-payment.html'
      '?userId=${Uri.encodeComponent(uid)}'
      '&phoneNo=${Uri.encodeComponent(phoneNo)}'
      '&source=${Uri.encodeComponent(widget.source)}',
    );

    setState(() => _isLaunching = true);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: const Center(
        child: Text(
          '계좌 등록 후 이용가능합니다',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: _isLaunching ? null : _launchBankRegistration,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLaunching
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Text(
                        '계좌 등록하기',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
