import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddPost extends StatefulWidget {
  const AddPost({super.key});

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  String imgUrl = "";
  final currentUser = FirebaseAuth.instance.currentUser;
  TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        floatingActionButton: ElevatedButton(
          onPressed: () async {
            if (_textController.text.isEmpty && imgUrl.isEmpty) return;

            showLoadingDialog(context);
            try {
              await uploadPost(text: _textController.text, imgUrl: imgUrl);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('성공')));

              Navigator.pop(context);
            } catch (e) {
              print(e.toString());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('게시물 게시에 실패했습니다: ${e.toString()}')),
              );
            }
          },

          style: ElevatedButton.styleFrom(
            backgroundColor:
                _textController.text.isEmpty && imgUrl.isEmpty
                    ? ColorsManager.primary200
                    : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Circular edges
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ), // Width/height
            elevation: 0,
          ),
          child: Text("게시", style: TextStyle(color: Colors.white)),
        ),
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
              Text(
                "오늘의 이야기",
                style: TextStyle(
                  color: const Color(0xFF121212),
                  fontSize: 16,
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  height: 1.40,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(4.0),
            child: Container(color: ColorsManager.primary100, height: 1.0),
          ),
        ),
        body: Column(
          children: [
            verticalSpace(20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Container(
                    width: 56,
                    height: 55,
                    decoration: ShapeDecoration(
                      image: DecorationImage(
                        image: NetworkImage(currentUser!.photoURL!),
                        fit: BoxFit.cover,
                      ),
                      shape: OvalBorder(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // spacing: 15,
                    children: [
                      Text(
                        currentUser!.displayName!,
                        style: TextStyles.abeezee16px400wPblack,
                      ),
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Visibility(
                            visible: _textController.text.isEmpty,
                            child: FutureBuilder(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('widgets')
                                      .doc('placeholders')
                                      .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return const Center(child: Text('Error'));
                                }

                                return Text(
                                  snapshot.data!
                                      .data()!['innerPlaceholderText'],
                                  style: TextStyle(
                                    color: const Color(0xFF5F5F5F),
                                    fontSize: 13,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                  ),
                                );
                              },
                            ),
                          ),
                          TextField(
                            controller: _textController,
                            onChanged: (value) => setState(() {}),
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: TextStyle(
                              color: const Color(0xFF5F5F5F),
                              fontSize: 13,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () async {
                          showLoadingDialog(context);

                          imgUrl = await uploadImageToFirebaseStorage();
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child:
                            imgUrl.isEmpty
                                ? ImageIcon(
                                  AssetImage('assets/image_icon.png'),
                                  size: 17,
                                )
                                : Image.network(
                                  imgUrl,
                                  height: 272,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
