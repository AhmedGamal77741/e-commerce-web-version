import 'package:share_plus/share_plus.dart';

class ShareService {
  static const String _appDomain = 'https://app.pang2chocolate.com';

  static Future<void> shareProduct(String productId, String productName) async {
    final link = '$_appDomain/product/$productId';
    await Share.share(
      '이 상품 확인해보세요! 🛍️\n$link',
      subject: '$productName을(를) 공유했습니다',
    );
  }

  static Future<void> sharePost(String postId) async {
    final link = '$_appDomain/comment?postId=$postId';
    await Share.share('이 게시물을 확인해보세요! 👇\n$link', subject: '게시물 공유');
  }
}
