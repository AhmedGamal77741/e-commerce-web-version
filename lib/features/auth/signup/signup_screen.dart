import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final paymentInfoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  IconData iconPassword = Icons.visibility;
  bool obscurePassword = true;
  bool signUpRequired = false;
  String imgUrl = '';
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
                      Row(
                        children: [
                          Text('닉네임', style: TextStyles.abeezee16px400wPblack),
                          Spacer(),
                          InkWell(
                            onTap: () async {
                              imgUrl = await uploadImageToFirebaseStorage();
                              setState(() {});
                            },
                            child:
                                imgUrl.isEmpty
                                    ? Image.asset(
                                      'assets/mypage_avatar.png',
                                      height: 55,
                                      width: 56,
                                    )
                                    : ClipOval(
                                      child: Image.network(
                                        imgUrl,
                                        height: 55,
                                        width: 56,
                                        fit:
                                            BoxFit
                                                .cover, // Ensures proper filling
                                      ),
                                    ),
                          ),
                        ],
                      ),
                      UnderlineTextField(
                        controller: nameController,
                        hintText: '팽이마켓',
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
                      Text('이메일', style: TextStyles.abeezee16px400wPblack),
                      verticalSpace(8),
                      UnderlineTextField(
                        controller: emailController,
                        hintText: '이메일을 입력하세요',
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
                              if (obscurePassword) {
                                iconPassword = Icons.visibility_off;
                              } else {
                                iconPassword = Icons.visibility;
                              }
                            });
                          },
                          icon: Icon(iconPassword),
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
                    ],
                  ),
                ),
              ),
            ),
            verticalSpace(40),
            Text(error, style: TextStyles.abeezee16px400wPred),

            // Container(
            //   decoration: ShapeDecoration(
            //     color: ColorsManager.white,
            //     shape: RoundedRectangleBorder(
            //       side: BorderSide(width: 1, color: ColorsManager.primary100),
            //       borderRadius: BorderRadius.circular(25),
            //     ),
            //   ),
            //   child: Padding(
            //     padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 20.h),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text('월 회비', style: TextStyles.abeezee16px400wPblack),
            //         Text('3,000원', style: TextStyles.abeezee14px400wP600),
            //         Divider(color: ColorsManager.primary100),
            //         Text('혜택', style: TextStyles.abeezee16px400wPblack),
            //         Text(
            //           '전제품 무료배송, 무료반품 , 멤버십 커뮤니티 이용, 최저가 \n 상품 구매 ',
            //           style: TextStyles.abeezee14px400wP600,
            //         ),
            //         Divider(color: ColorsManager.primary100),
            //         Text('결제', style: TextStyles.abeezee16px400wPblack),
            //         UnderlineTextField(
            //           controller: paymentInfoController,
            //           hintText: '결제수단 등록',
            //           obscureText: false,
            //           keyboardType: TextInputType.name,
            //         ),
            //         /* Text('결제 정보를 입력하세요', style: TextStyles.abeezee14px400wP600), */
            //       ],
            //     ),
            //   ),
            // ),
            WideTextButton(
              txt: '가입하기',
              func: () async {
                if (_formKey.currentState!.validate()) {
                  MyUser myUser = MyUser.empty;
                  myUser.email = emailController.text;
                  myUser.name = nameController.text;
                  imgUrl.isEmpty
                      ? myUser.url =
                          "https://i.ibb.co/6kmLx2D/mypage-avatar.png"
                      : myUser.url = imgUrl;

                  var result = await fireBaseRepo.signUp(
                    myUser,
                    passwordController.text,
                  );
                  if (result != '회원가입이 완료되었습니다') {
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
