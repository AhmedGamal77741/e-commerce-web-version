import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeletedAccount extends StatelessWidget {
  final String deletedAt;
  final VoidCallback onRecover;
  final VoidCallback onSignOut;

  const DeletedAccount({
    super.key,
    required this.deletedAt,
    required this.onRecover,
    required this.onSignOut,
  });

  Future<void> _showRecoverDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ColorsManager.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('계정 복구 확인', style: TextStyles.abeezee16px400wPblack),
          content: Text(
            '정말로 계정을 복구하시겠습니까?',
            style: TextStyles.abeezee16px400wP600,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소', style: TextStyles.abeezee13px400wPblack),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsManager.primaryblack,
                foregroundColor: ColorsManager.white,
              ),
              child: Text('복구', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      onRecover();
      // Also delete the user's doc from the 'deleted' collection
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance
              .collection('deleted')
              .doc(uid)
              .delete();
        } catch (_) {}
        // Also delete the user's reason doc from the 'deletes' collection
        try {
          final query =
              await FirebaseFirestore.instance
                  .collection('deletes')
                  .where('userId', isEqualTo: uid)
                  .get();
          for (final doc in query.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }
    }
  }

  String _formatDeletedAt(String deletedAt) {
    // Try to parse as Timestamp (from Firestore)
    try {
      if (deletedAt.isEmpty) return '';
      // If it's a Firestore Timestamp string
      if (deletedAt.contains('Timestamp(')) {
        final match = RegExp(
          r'Timestamp\((\d+), (\d+)\)',
        ).firstMatch(deletedAt);
        if (match != null) {
          final seconds = int.parse(match.group(1)!);
          final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }
      // Try ISO8601 string
      final date = DateTime.tryParse(deletedAt);
      if (date != null) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return deletedAt;
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDeletedAt(deletedAt);
    return Scaffold(
      backgroundColor: ColorsManager.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ColorsManager.red,
                size: 64,
              ),
              verticalSpace(24),
              Text(
                '계정이 삭제 예약되었습니다.',
                style: TextStyles.abeezee20px400wPblack.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              verticalSpace(16),
              Text(
                '계정은 $formattedDate 에 영구적으로 삭제됩니다.\n그 전까지 언제든 복구할 수 있습니다.',
                style: TextStyles.abeezee16px400wP600.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              verticalSpace(32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _showRecoverDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorsManager.primaryblack,
                    foregroundColor: ColorsManager.white,
                  ),
                  child: Text('계정 복구', style: TextStyle(fontSize: 16)),
                ),
              ),
              verticalSpace(12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorsManager.primaryblack,
                    side: const BorderSide(color: ColorsManager.primaryblack),
                  ),
                  child: Text('로그아웃', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
