import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerece_app/core/routing/app_router.dart';
import 'package:ecommerece_app/e_commerce_app.dart';
import 'package:ecommerece_app/firebase_options.dart';
// import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //setUrlStrategy(PathUrlStrategy());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        Provider<FirebaseUserRepo>(create: (_) => FirebaseUserRepo()),
      ],
      child: EcommerceApp(appRouter: AppRouter()),
    ),
  );
}
