import 'package:ecommerece_app/core/routing/app_router.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:app_links/app_links.dart';
import 'dart:async';

// final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
//     GlobalKey<ScaffoldMessengerState>();

class EcommerceApp extends StatelessWidget {
  final AppRouter appRouter;
  const EcommerceApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: 428,
            height: 926,
            child: ClipRect(
              child: MaterialApp.router(
                theme: ThemeData(
                  scaffoldBackgroundColor: ColorsManager.primary,
                  appBarTheme: AppBarTheme(
                    backgroundColor: ColorsManager.primary,
                  ),
                  unselectedWidgetColor: Colors.grey,
                  radioTheme: RadioThemeData(
                    fillColor: WidgetStateColor.resolveWith(
                      (states) => Colors.black,
                    ),
                  ),
                ),
                debugShowCheckedModeBanner: false,
                routerConfig: AppRouter.router,
              ),
            ),
          ),
        );
      },
    );
  }
}
