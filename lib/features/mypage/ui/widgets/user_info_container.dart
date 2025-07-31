import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class UserInfoContainer extends StatefulWidget {
  const UserInfoContainer({super.key});

  @override
  State<UserInfoContainer> createState() => _UserInfoContainerState();
}

class _UserInfoContainerState extends State<UserInfoContainer> {
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final bioController = TextEditingController();
  final phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String imgUrl = "";
  String error = '';
  final fireBaseRepo = FirebaseUserRepo();

  MyUser? currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Provider.of<PostsProvider>(context, listen: false).startListening();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await FirebaseUserRepo().user.first;
      if (!mounted) return;
      if (user != null) {
        setState(() {
          currentUser = user;
          nameController.text = user.name.isNotEmpty ? user.name : '';
          bioController.text =
              (user.bio != null && user.bio!.isNotEmpty) ? user.bio! : '';
          phoneController.text =
              (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                  ? user.phoneNumber!
                  : '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading user: $e');
    }
  }

  Future<bool> _reauthenticateUser(BuildContext context) async {
    bool success = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final TextEditingController reauthController = TextEditingController();
        bool obscure = true;
        IconData icon = Icons.visibility_off;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                '비밀번호 재확인',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '비밀번호를 변경하려면 현재 비밀번호를 입력하세요.',
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  UnderlineTextField(
                    controller: reauthController,
                    hintText: '현재 비밀번호',
                    obscureText: obscure,
                    keyboardType: TextInputType.visiblePassword,
                    validator:
                        (val) =>
                            val == null || val.isEmpty ? '비밀번호를 입력하세요' : null,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscure = !obscure;
                          icon =
                              obscure ? Icons.visibility_off : Icons.visibility;
                        });
                      },
                      icon: Icon(icon),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    '취소',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () async {
                    final passwordText = reauthController.text;
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || user.email == null) {
                        throw Exception('로그인 정보가 없습니다');
                      }
                      final cred = EmailAuthProvider.credential(
                        email: user.email!,
                        password: passwordText,
                      );
                      await user.reauthenticateWithCredential(cred);
                      success = true;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              '재인증 실패: 비밀번호를 확인하세요.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    '확인',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return success;
  }

  @override
  void dispose() {
    passwordController.dispose();
    nameController.dispose();
    bioController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(
      decoration: ShapeDecoration(
        color: ColorsManager.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: ColorsManager.primary100),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // userId combo
              // Text(
              //   '아이디', // Translated to Korean
              //   style: TextStyles.abeezee16px400wPblack.copyWith(
              //     fontSize: 16.sp,
              //   ),
              // ),
              // SizedBox(height: 5.h),
              // Container(
              //   width: double.infinity,
              //   padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
              //   decoration: BoxDecoration(
              //     border: Border(
              //       bottom: BorderSide(
              //         color: ColorsManager.primary100,
              //         width: 1.w,
              //       ),
              //     ),
              //   ),
              //   child: Text(
              //     (currentUser?.tag != null && currentUser!.tag!.isNotEmpty)
              //         ? currentUser!.tag!
              //         : '지정되지 않음',
              //     style: TextStyles.abeezee16px400wPblack.copyWith(
              //       color: Colors.grey[700],
              //       fontSize: 16.sp,
              //     ),
              //   ),
              // ),
              // SizedBox(height: 20.h),

              // 닉네임 combo
              Text(
                '닉네임',
                style: TextStyles.abeezee16px400wPblack.copyWith(fontSize: 16),
              ),
              SizedBox(height: 5),
              UnderlineTextField(
                controller: nameController,
                hintText:
                    (currentUser?.name.isNotEmpty ?? false)
                        ? currentUser!.name
                        : '지정되지 않음',
                obscureText: false,
                keyboardType: TextInputType.name,
                validator: (val) {
                  if (val!.isEmpty) return null;
                  if (val.length > 30) return '이름이 너무 깁니다';
                  return null;
                },
              ),
              SizedBox(height: 20),

              // User bio combo
              Text(
                '소개', // Translated to Korean
                style: TextStyles.abeezee16px400wPblack.copyWith(fontSize: 16),
              ),
              SizedBox(height: 5),
              UnderlineTextField(
                controller: bioController,
                hintText:
                    (currentUser?.bio != null && currentUser!.bio!.isNotEmpty)
                        ? currentUser!.bio!
                        : '지정되지 않음',
                obscureText: false,
                keyboardType: TextInputType.name,
                validator: (val) {
                  if (val!.isEmpty) return null;
                  if (val.length > 30) return '이름이 너무 깁니다';
                  return null;
                },
              ),
              SizedBox(height: 20),

              // 전화번호 combo
              Text(
                '전화번호',
                style: TextStyles.abeezee16px400wPblack.copyWith(fontSize: 16),
              ),
              SizedBox(height: 5),
              UnderlineTextField(
                controller: phoneController,
                hintText:
                    (currentUser?.phoneNumber != null &&
                            currentUser!.phoneNumber!.isNotEmpty)
                        ? currentUser!.phoneNumber!
                        : '지정되지 않음',
                obscureText: false,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val!.isEmpty) return null;
                  final koreanReg = RegExp(
                    r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
                  );
                  if (!koreanReg.hasMatch(val)) {
                    return '유효한 한국 전화번호를 입력하세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // 비밀번호 combo
              Text(
                '비밀번호',
                style: TextStyles.abeezee16px400wPblack.copyWith(fontSize: 16),
              ),
              SizedBox(height: 5),
              Builder(
                builder: (context) {
                  // Use a local stateful widget to persist the obscure/icon state
                  return _PasswordFieldWithVisibility(
                    controller: passwordController,
                  );
                },
              ),
              SizedBox(height: 20),

              // Submit button row as a combo
              Row(
                children: [
                  const Spacer(),
                  BlackTextButton(
                    txt: '완료',
                    func: () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (currentUser == null) return;
                      // Check which fields are being updated
                      final isUpdatingName =
                          nameController.text.isNotEmpty &&
                          nameController.text != currentUser!.name;
                      final isUpdatingPassword =
                          passwordController.text.isNotEmpty;
                      final isUpdatingPhone =
                          phoneController.text.isNotEmpty &&
                          phoneController.text !=
                              (currentUser!.phoneNumber ?? '');
                      final isUpdatingBio =
                          bioController.text.isNotEmpty &&
                          bioController.text != (currentUser!.bio ?? '');

                      if (!isUpdatingName &&
                          !isUpdatingPassword &&
                          !isUpdatingPhone &&
                          !isUpdatingBio) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "변경된 내용이 없습니다",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                        return;
                      }

                      // Check for unique nickname if updating name
                      if (isUpdatingName) {
                        final name = nameController.text.trim();
                        final existing = await fireBaseRepo.checkNameExists(
                          name,
                        );
                        // Only block if the name exists and is not the current user's name
                        if (existing && name != currentUser!.name) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '이미 사용 중인 닉네임입니다',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                          return;
                        }
                      }

                      // Prepare updated user
                      final updatedUser = MyUser(
                        userId: currentUser!.userId,
                        email: currentUser!.email,
                        name:
                            isUpdatingName
                                ? nameController.text
                                : currentUser!.name,
                        url: imgUrl.isEmpty ? currentUser!.url : imgUrl,
                        isSub: currentUser!.isSub,
                        defaultAddressId: currentUser!.defaultAddressId,
                        blocked: currentUser!.blocked,
                        payerId: currentUser!.payerId,
                        isOnline: currentUser!.isOnline,
                        lastSeen: currentUser!.lastSeen,
                        chatRooms: currentUser!.chatRooms,
                        friends: currentUser!.friends,
                        friendRequestsSent: currentUser!.friendRequestsSent,
                        friendRequestsReceived:
                            currentUser!.friendRequestsReceived,
                        bio:
                            isUpdatingBio
                                ? bioController.text
                                : currentUser!.bio,
                        phoneNumber:
                            isUpdatingPhone
                                ? phoneController.text
                                : currentUser!.phoneNumber,
                      );
                      try {
                        if (isUpdatingPassword) {
                          final reauth = await _reauthenticateUser(context);
                          if (!reauth) return;
                        }
                        await fireBaseRepo.updateUser(
                          updatedUser,
                          isUpdatingPassword ? passwordController.text : "",
                        );
                        if (!mounted) return;
                        setState(() {
                          currentUser = updatedUser;
                        });
                        // Clear only updated fields
                        if (isUpdatingName) nameController.clear();
                        if (isUpdatingPassword) passwordController.clear();
                        if (isUpdatingPhone) phoneController.clear();
                        if (isUpdatingBio) bioController.clear();

                        String successMessage = "";
                        List<String> updated = [];
                        if (isUpdatingName) updated.add("닉네임");
                        if (isUpdatingPassword) updated.add("비밀번호");
                        if (isUpdatingPhone) updated.add("전화번호");
                        if (isUpdatingBio) updated.add("소개");
                        if (updated.isNotEmpty) {
                          successMessage =
                              updated.join(", ") + "가 성공적으로 업데이트되었습니다";
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              successMessage,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "업데이트 중 오류가 발생했습니다: " + e.toString(),
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      }
                    },
                    style: TextStyles.abeezee14px400wW.copyWith(fontSize: 14),
                  ),
                ],
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this widget at the bottom of the file (or above the class if you prefer)
class _PasswordFieldWithVisibility extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordFieldWithVisibility({Key? key, required this.controller})
    : super(key: key);

  @override
  State<_PasswordFieldWithVisibility> createState() =>
      _PasswordFieldWithVisibilityState();
}

class _PasswordFieldWithVisibilityState
    extends State<_PasswordFieldWithVisibility> {
  bool obscure = true;
  IconData icon = Icons.visibility_off;

  @override
  Widget build(BuildContext context) {
    return UnderlineTextField(
      controller: widget.controller,
      hintText: '영문,숫자 조합',
      obscureText: obscure,
      keyboardType: TextInputType.visiblePassword,
      validator: (val) {
        if (val!.isEmpty) return null;
        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(val)) {
          return '유효한 비밀번호를 입력해 주세요';
        }
        return null;
      },
      suffixIcon: IconButton(
        onPressed: () {
          setState(() {
            obscure = !obscure;
            icon = obscure ? Icons.visibility_off : Icons.visibility;
          });
        },
        icon: Icon(icon),
      ),
    );
  }
}
