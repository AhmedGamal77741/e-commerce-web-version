import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/features/cart/order_complete.dart';
import 'package:ecommerece_app/features/cart/place_order.dart';
import 'package:ecommerece_app/features/cart/buy_now.dart';
import 'package:ecommerece_app/features/home/add_post.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/notifications.dart';
import 'package:ecommerece_app/features/mypage/ui/cancel_subscription.dart';
import 'package:ecommerece_app/features/mypage/ui/delete_account_screen.dart';
import 'package:ecommerece_app/features/navBar/nav_bar.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/shop_search.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: Routes.navBar,
    routes: [
      GoRoute(
        name: Routes.navBar,
        path: Routes.navBar, // '/nav-bar'
        builder: (context, state) => const NavBar(),

        routes: [
          GoRoute(
            name: Routes.reviewScreen,
            path: Routes.reviewScreen, // '/review'
            builder: (context, state) => const ReviewScreen(),
          ),
          GoRoute(
            name: Routes.notificationsScreen,
            path: Routes.notificationsScreen, // '/notifications'
            builder: (context, state) => const Notifications(),
          ),
          GoRoute(
            name: Routes.addPostScreen,
            path: '${Routes.addPostScreen}', // '/add-post'
            builder: (context, state) => const AddPost(),
          ),
          GoRoute(
            name: Routes.landingScreen, // name added
            path: Routes.landingScreen,
            builder: (context, state) => const LandingScreen(),
          ),
          GoRoute(
            name: Routes.placeOrderScreen,
            path: Routes.placeOrderScreen,
            builder: (context, state) => const PlaceOrder(),
          ),
          GoRoute(
            name: Routes.orderCompleteScreen,
            path: Routes.orderCompleteScreen,
            builder: (context, state) => const OrderComplete(),
          ),
          GoRoute(
            name: Routes.shopSearchScreen,
            path: Routes.shopSearchScreen,
            builder: (context, state) => const ShopSearch(),
          ),
          GoRoute(
            name: Routes.commentsScreen,
            path: '/${Routes.commentsScreen}', // '/comment'
            builder: (context, state) {
              final postId = state.uri.queryParameters['postId'] ?? '';
              return Comments(postId: postId);
            },
          ),
          GoRoute(
            name: Routes.cancelSubscription,
            path: Routes.cancelSubscription,
            builder: (context, state) => const CancelSubscription(),
          ),
          GoRoute(
            name: Routes.deleteAccount,
            path: Routes.deleteAccount,
            builder: (context, state) => DeleteAccountScreen(),
          ),
          GoRoute(
            name: Routes.buyNowScreen,
            path: Routes.buyNowScreen,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null ||
                  !extra.containsKey('product') ||
                  !extra.containsKey('quantity') ||
                  !extra.containsKey('price')) {
                return Scaffold(
                  body: Center(
                    child: Text('잘못된 접근입니다. (Missing Buy Now arguments)'),
                  ),
                );
              }
              return BuyNow(
                product: extra['product'],
                quantity: extra['quantity'],
                price: extra['price'],
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(child: Text('No route defined for ${state.uri.path}')),
        ),
  );
}
