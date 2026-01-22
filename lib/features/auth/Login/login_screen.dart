import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final passwordController = TextEditingController();

  final emailController = TextEditingController();

  bool obsecurepassword = true;

  final _formKey = GlobalKey<FormState>();

  String? _errorMsg;

  String error = '';
  final fireBaseRepo = FirebaseUserRepo();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            Container(
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
                      verticalSpace(20),
                      Text('아이디', style: TextStyles.abeezee16px400wPblack),
                      UnderlineTextField(
                        controller: emailController,
                        hintText: '이메일',
                        obscureText: false,
                        keyboardType: TextInputType.emailAddress,
                        errorMsg: _errorMsg,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return 'Please fill in this field';
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
                      UnderlineTextField(
                        controller: passwordController,
                        hintText: '영문,숫자 조합',
                        obscureText: obsecurepassword,
                        keyboardType: TextInputType.visiblePassword,
                        errorMsg: _errorMsg,
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
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obsecurepassword = !obsecurepassword;
                            });
                          },
                          icon: Icon(
                            obsecurepassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            verticalSpace(30),
            Text(error, style: TextStyles.abeezee16px400wPred),
            WideTextButton(
              txt: '로그인',
              func: () async {
                if (_formKey.currentState!.validate()) {
                  dynamic result = await fireBaseRepo.signIn(
                    emailController.text,
                    passwordController.text,
                  );

                  if (result is String) {
                    setState(() {
                      error = result;
                    });
                  }
                }
              },
              color: ColorsManager.primaryblack,
              txtColor: ColorsManager.white,
            ),
          ],
        ),
      ),
    );
  }
}
