import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
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
  final _formKey = GlobalKey<FormState>();
  String imgUrl = "";
  String error = '';
  final fireBaseRepo = FirebaseUserRepo();

  MyUser? currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Start listening to posts as before
    Provider.of<PostsProvider>(context, listen: false).startListening();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await FirebaseUserRepo().user.first;
      if (!mounted) return;
      setState(() {
        currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading user: $e');
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: ColorsManager.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: ColorsManager.primary100),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Row
              Text('닉네임', style: TextStyles.abeezee16px400wPblack),

              verticalSpace(20),

              // Name field
              UnderlineTextField(
                controller: nameController,
                hintText: '팽이마켓',
                obscureText: false,
                keyboardType: TextInputType.name,
                validator: (val) {
                  // Skip validation if empty - we'll handle this separately
                  if (val!.isEmpty) return null;
                  if (val.length > 30) return '이름이 너무 깁니다';
                  return null;
                },
              ),

              verticalSpace(20),

              // Password and submit button
              Text('비밀번호', style: TextStyles.abeezee16px400wPblack),
              Row(
                children: [
                  const Spacer(),
                  BlackTextButton(
                    txt: '완료',
                    func: () async {
                      if (!_formKey.currentState!.validate()) return;

                      // Check if both fields are empty
                      if (nameController.text.isEmpty &&
                          passwordController.text.isEmpty) {
                        setState(() {
                          error = "이름 또는 비밀번호를 입력해 주세요";
                        });
                        return;
                      }

                      // Track what we're trying to update
                      final isUpdatingName = nameController.text.isNotEmpty;
                      final isUpdatingPassword =
                          passwordController.text.isNotEmpty;

                      // Prepare user model (only update name if it's provided)
                      final myUser = MyUser(
                        userId: currentUser!.userId,
                        email: currentUser!.email,
                        name:
                            isUpdatingName
                                ? nameController.text
                                : currentUser!.name,
                        url: imgUrl.isEmpty ? currentUser!.url : imgUrl,
                      );

                      try {
                        // Pass empty string for password if we're not updating it
                        final result = await fireBaseRepo.updateUser(
                          myUser,
                          isUpdatingPassword ? passwordController.text : "",
                        );

                        if (!mounted) return;

                        if (result == null) {
                          setState(() {
                            error = "이미 사용 중인 닉네임입니다";
                          });
                        } else {
                          // Clear error message
                          setState(() {
                            error = "";
                          });

                          // Clear fields that were updated
                          if (isUpdatingName) nameController.clear();
                          if (isUpdatingPassword) passwordController.clear();

                          // Show appropriate success message based on what was updated
                          String successMessage;
                          if (isUpdatingName && isUpdatingPassword) {
                            successMessage = "닉네임과 비밀번호가 성공적으로 업데이트되었습니다";
                          } else if (isUpdatingName) {
                            successMessage = "닉네임이 성공적으로 업데이트되었습니다";
                          } else {
                            successMessage = "비밀번호가 성공적으로 업데이트되었습니다";
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(successMessage)),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          error = "업데이트 중 오류가 발생했습니다: ${e.toString()}";
                        });
                      }
                    },
                    style: TextStyles.abeezee14px400wW,
                  ),
                ],
              ),

              // Password field
              UnderlineTextField(
                controller: passwordController,
                hintText: '영문,숫자 조합',
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                validator: (val) {
                  // Skip validation if empty - we'll handle this separately
                  if (val!.isEmpty) return null;
                  if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(val)) {
                    return '유효한 비밀번호를 입력해 주세요';
                  }
                  return null;
                },
              ),

              if (error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
