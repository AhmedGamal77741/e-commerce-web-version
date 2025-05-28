import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:flutter/material.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false, // Don't show the leading button
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios),
              ),
              Text("알림", style: TextStyle(fontFamily: 'ABeeZee')),
            ],
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 20,
            children: [
              verticalSpace(5),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '00님 외  2명이 내 이야기에 댓글을 남겼습니다',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w400,
                      height: 1.40,
                    ),
                  ),
                  Text(
                    '댓글 : 꿀팁 공유 감사합니다 오늘 하루도 화이팅! ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w400,
                      height: 1.40,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: Text(
                      '00님 외 1,324명이 내 이야기에 좋아요를 눌렀습니다',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.w400,
                        height: 1.40,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: Text(
                      '00님 외 2명이 내 이야기에 좋아요를 눌렀습니다',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.w400,
                        height: 1.40,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
