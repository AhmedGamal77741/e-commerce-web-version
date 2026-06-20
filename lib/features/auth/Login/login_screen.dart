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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: '이메일',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
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
              ),
              verticalSpace(12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: obsecurepassword,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    hintText: '영어, 숫자 조합',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
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
                        color: Colors.grey,
                      ),
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
              ),
              if (error.isNotEmpty) ...[
                verticalSpace(12),
                Text(error, style: TextStyles.abeezee16px400wPred),
              ],
              verticalSpace(20),
              ElevatedButton(
                onPressed: () async {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              verticalSpace(16),
              Center(
                child: TextButton(
                  onPressed: () {
                    _showForgotPasswordDialog(context);
                  },
                  child: Text(
                    '비밀번호 찾기',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final resetEmailController = TextEditingController();
    String dialogError = '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: ColorsManager.white,
              title: Text('비밀번호 찾기', style: TextStyles.abeezee16px400wPblack),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '가입한 이메일을 입력해주세요.',
                    style: TextStyles.abeezee13px400wPblack,
                  ),
                  verticalSpace(10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextFormField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: '이메일',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  if (dialogError.isNotEmpty) ...[
                    verticalSpace(10),
                    Text(dialogError, style: TextStyles.abeezee16px400wPred),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('취소', style: TextStyles.abeezee14px400wP600),
                ),
                TextButton(
                  onPressed: () async {
                    if (resetEmailController.text.isEmpty) {
                      setDialogState(() {
                        dialogError = '이메일을 입력해주세요.';
                      });
                      return;
                    }

                    final result = await fireBaseRepo.sendPasswordReset(
                      resetEmailController.text,
                    );
                    if (result == null) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('비밀번호 재설정 이메일이 전송되었습니다.'),
                          ),
                        );
                      }
                    } else {
                      setDialogState(() {
                        dialogError = result;
                      });
                    }
                  },
                  child: Text(
                    '전송',
                    style: TextStyles.abeezee14px400wP600.copyWith(
                      color: ColorsManager.primaryblack,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
