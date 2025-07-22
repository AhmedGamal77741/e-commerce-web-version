import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void showPostMenu(BuildContext context, String postId, String userId) {
  showModalBottomSheet(
    context: context,
    builder:
        (context) => Container(
          height: 233,
          padding: EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: ColorsManager.primary50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          child: SizedBox(
            width: 393,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              // spacing: 20.h, // Remove if not supported by Column
              children: [
                // Unified option rows
                InkWell(
                  onTap: () async {
                    final base = Uri.base.origin;
                    final url = '$base/comment?postId=$postId';
                    await Clipboard.setData(ClipboardData(text: url));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('댓글 링크가 복사되었습니다!')));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '링크 복사',
                          style: TextStyle(
                            color: const Color(0xFF343434),
                            fontSize: 16,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                        ImageIcon(AssetImage('assets/icon=link.png'), size: 20),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text("신고 처리 중..."),
                            ],
                          ),
                        );
                      },
                    );
                    try {
                      await Provider.of<PostsProvider>(
                        context,
                        listen: false,
                      ).addToNotInterested(postId);
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Blocked successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("an error has occured: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '관심 없음',
                          style: TextStyle(
                            color: const Color(0xFF343434),
                            fontSize: 16,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                        ImageIcon(
                          AssetImage('assets/icon=no_interest.png'),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    showDialog(
                      context: context,
                      barrierDismissible:
                          false, // Prevent closing by tapping outside
                      builder: (BuildContext context) {
                        return AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text("신고 처리 중..."), // "Processing report..."
                            ],
                          ),
                        );
                      },
                    );

                    try {
                      await blockUser(userIdToBlock: userId);

                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Blocked successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("an error has occured: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(color: Colors.white),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                child: Text(
                                  '차단',
                                  style: TextStyle(
                                    color: const Color(0xFFDA3A48),
                                    fontSize: 16,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                  ),
                                ),
                              ),
                              ImageIcon(
                                AssetImage('assets/person_off.png'),
                                size: 20,
                                color: const Color(0xFFDA3A48),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            showDialog(
                              context: context,
                              barrierDismissible:
                                  false, // Prevent closing by tapping outside
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  content: Row(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 16),
                                      Text(
                                        "신고 처리 중...",
                                      ), // "Processing report..."
                                    ],
                                  ),
                                );
                              },
                            );

                            try {
                              await reportUser(
                                reportedUserId: userId,
                                postId: postId,
                              );

                              Navigator.of(context).pop();
                              Navigator.of(context).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("신고가 접수되었습니다."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("신고 처리 중 오류가 발생했습니다."),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(color: Colors.white),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  child: Text(
                                    '신고하기',
                                    style: TextStyle(
                                      color: const Color(0xFFDA3A48),
                                      fontSize: 16,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      height: 1.40,
                                    ),
                                  ),
                                ),
                                ImageIcon(
                                  AssetImage('assets/report.png'),
                                  size: 20,
                                  color: const Color(0xFFDA3A48),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}
