import 'dart:io';

import 'package:ecommerece_app/core/helpers/image_picker_helper.dart';
import 'package:ecommerece_app/core/helpers/loading_service.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool agreedToTerms = false;
  bool agreedToPrivacy = false;
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool obscurePassword = true;
  bool signUpRequired = false;
  bool isPrivate = false;
  String imgUrl = '';
  String error = '';
  final fireBaseRepo = FirebaseUserRepo();
  XFile? selectedImage;

  Future<void> pickImage() async {
    try {
      final XFile? image = await ImagePickerHelper.pickImage();

      if (image != null) {
        setState(() {
          selectedImage = image;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              children: [
                Container(
                  decoration: ShapeDecoration(
                    color: ColorsManager.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: ColorsManager.primary100,
                      ),
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
                          Row(
                            children: [
                              Text(
                                '닉네임',
                                style: TextStyles.abeezee16px400wPblack,
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () async {
                                  await pickImage();
                                },
                                child:
                                    selectedImage != null
                                        ? ClipOval(
                                          child: Image.file(
                                            File(selectedImage!.path),
                                            height: 55,
                                            width: 56,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : Image.asset(
                                          'assets/avatar.png',
                                          height: 55,
                                          width: 56,
                                        ),
                              ),
                            ],
                          ),
                          UnderlineTextField(
                            controller: nameController,
                            hintText: '',
                            obscureText: false,
                            keyboardType: TextInputType.name,
                            validator: (val) {
                              if (val!.isEmpty) {
                                return '이름을 입력하세요';
                              } else if (val.length > 30) {
                                return '이름이 너무 깁니다';
                              }
                              return null;
                            },
                          ),

                          verticalSpace(20),
                          Text('전화번호', style: TextStyles.abeezee16px400wPblack),
                          verticalSpace(8),
                          UnderlineTextField(
                            controller: phoneController,
                            hintText: '',
                            obscureText: false,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return '전화번호를 입력하세요';
                              }
                              final koreanReg = RegExp(
                                r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
                              );
                              if (!koreanReg.hasMatch(val)) {
                                return '유효한 한국 전화번호를 입력하세요';
                              }
                              return null;
                            },
                          ),
                          verticalSpace(20),
                          Text('이메일', style: TextStyles.abeezee16px400wPblack),
                          verticalSpace(8),
                          UnderlineTextField(
                            controller: emailController,
                            hintText: '',
                            obscureText: false,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val!.isEmpty) {
                                return '이 필드를 작성해 주세요';
                              } else if (!RegExp(
                                r'^[\w-\.]+@([\w-]+.)+[\w-]{2,4}$',
                              ).hasMatch(val)) {
                                return '유효한 이메일을 입력해 주세요';
                              }
                              return null;
                            },
                          ),
                          verticalSpace(20),
                          Text('비밀번호', style: TextStyles.abeezee16px400wPblack),
                          verticalSpace(8),
                          UnderlineTextField(
                            controller: passwordController,
                            hintText: '영문,숫자 조합 8자 이상',
                            obscureText: obscurePassword,
                            keyboardType: TextInputType.visiblePassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                            validator: (val) {
                              if (val!.isEmpty) {
                                return '이 필드를 작성해 주세요';
                              } else if (!RegExp(
                                r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
                              ).hasMatch(val)) {
                                return '유효한 비밀번호를 입력해 주세요';
                              }
                              return null;
                            },
                          ),
                          verticalSpace(20),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '비공개 프로필',
                                    style: TextStyles.abeezee16px400wPblack,
                                  ),
                                  verticalSpace(5),
                                  Text(
                                    '비공개로 전환하면, 친구로 수락한\n사람만 회원님을 구독하고 게시물\n을 볼 수 있어요.',
                                    style: TextStyles.abeezee13px400wP600,
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Padding(
                                padding: EdgeInsets.only(right: 15),
                                child: Transform.scale(
                                  scale: 1.3,
                                  child: CupertinoSwitch(
                                    value: isPrivate,
                                    onChanged: (s) {
                                      setState(() {
                                        isPrivate = s;
                                      });
                                    },
                                    activeTrackColor: Colors.black,
                                    inactiveTrackColor: Colors.grey[300],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                verticalSpace(10),

                // ── Terms and Privacy checkboxes ──────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              agreedToTerms = value ?? false;
                            });
                          },
                          checkColor:
                              agreedToTerms ? Colors.white : Colors.black,
                          fillColor: WidgetStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.black;
                            }
                            return Colors.white;
                          }),
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final url = Uri.parse(
                              'https://flowery-tub-f11.notion.site/1d938af9230b80fa9d64ce280f6eacbd',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: const Text(
                            '이용약관 동의',
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: agreedToPrivacy,
                          onChanged: (value) {
                            setState(() {
                              agreedToPrivacy = value ?? false;
                            });
                          },
                          checkColor:
                              agreedToPrivacy ? Colors.white : Colors.black,
                          fillColor: WidgetStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.black;
                            }
                            return Colors.white;
                          }),
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                        const Text(
                          '개인정보 수집 및 이용 동의',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
                verticalSpace(20),
                Text(error, style: TextStyles.abeezee16px400wPred),

                WideTextButton(
                  txt: '가입하기',
                  func: () async {
                    if (!agreedToTerms || !agreedToPrivacy) {
                      setState(() {
                        error = '모든 약관에 동의해야 가입할 수 있습니다.';
                      });
                      return;
                    }
                    if (_formKey.currentState!.validate()) {
                      LoadingService().showLoading();

                      // Check if name is unique
                      final name = nameController.text.trim();
                      final existing = await fireBaseRepo.checkNameExists(name);
                      if (existing) {
                        LoadingService().hideLoading();
                        setState(() {
                          error = '이미 사용 중인 닉네임입니다';
                        });
                        return;
                      }

                      MyUser myUser = MyUser.empty;
                      myUser.email = emailController.text;
                      myUser.name = nameController.text;
                      myUser.isPrivate = isPrivate;
                      imgUrl.isEmpty
                          ? myUser.url = "https://i.ibb.co/mrVrHy7z/avatar.png"
                          : myUser.url = imgUrl;
                      myUser.phoneNumber = phoneController.text;

                      // ── Set flag BEFORE signUp so it's ready when
                      // the auth stream fires and MyPageScreen mounts.
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('show_bank_prompt_after_login', true);

                      var result = await fireBaseRepo.signUp(
                        myUser,
                        passwordController.text,
                        selectedImage,
                      );
                      LoadingService().hideLoading();

                      if (result != '회원가입이 완료되었습니다') {
                        // Signup failed — clear the flag we just set
                        await prefs.remove('show_bank_prompt_after_login');
                        setState(() {
                          error = result;
                        });
                      }
                      // On success: no action needed — LandingScreen's
                      // StreamBuilder reacts to auth state and renders
                      // MyPageScreen, which reads the flag in initState.
                    }
                  },
                  color: ColorsManager.primaryblack,
                  txtColor: ColorsManager.white,
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: LoadingService().isLoading,
          builder: (context, isLoading, child) {
            return isLoading
                ? Container(
                  color: Colors.black54,
                  child: const Center(child: SizedBox.shrink()),
                )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
