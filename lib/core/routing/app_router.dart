import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/features/cart/order_complete.dart';
import 'package:ecommerece_app/features/cart/place_order.dart';
import 'package:ecommerece_app/features/cart/buy_now.dart';
import 'package:ecommerece_app/features/cart/registered_screen.dart';

import 'package:ecommerece_app/features/home/add_post.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/notifications.dart';
import 'package:ecommerece_app/features/home/widgets/alerts.dart';
import 'package:ecommerece_app/features/mypage/ui/cancel_subscription.dart';
import 'package:ecommerece_app/features/mypage/ui/delete_account_screen.dart';
import 'package:ecommerece_app/features/navBar/nav_bar.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:ecommerece_app/features/shop/shop_search.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_comments.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: Routes.navBar,
    routes: [
      GoRoute(
        name: 'guestCommentsScreen',
        path: '/guest_comment',
        builder: (context, state) {
          final postId = state.uri.queryParameters['postId'] ?? '';
          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Scaffold(
                  body: Center(child: Text('Post not found')),
                );
              }
              final postMap = snapshot.data!.data() as Map<String, dynamic>;
              postMap['postId'] = postId;
              postMap['fromComments'] = true;
              return GuestComments(post: postMap);
            },
          );
        },
      ),

      // ── Bank registered deep link landing ─────────────────────────────────
      // Reached when OS intercepts app.pang2chocolate.com/bank-registered
      // after Payple bank account registration callback redirects here.
      // Top-level route (not nested under navBar) so it works from cold start.
      GoRoute(
        name: 'bankRegisteredScreen',
        path: Routes.bankRegisteredScreen, // '/bank-registered'
        builder: (context, state) {
          final success = state.uri.queryParameters['success'] ?? 'false';
          final userId = state.uri.queryParameters['userId'] ?? '';
          final paymentId = state.uri.queryParameters['paymentId'] ?? '';
          final message = state.uri.queryParameters['message'] ?? '';
          return BankRegisteredScreen(
            success: success == 'true',
            userId: userId,
            paymentId: paymentId,
            message: message,
          );
        },
      ),

      GoRoute(
        name: Routes.navBar,
        path: Routes.navBar,
        builder: (context, state) => const NavBar(),
        routes: [
          GoRoute(
            name: Routes.reviewScreen,
            path: Routes.reviewScreen,
            builder: (context, state) => const ReviewScreen(),
          ),
          GoRoute(
            name: Routes.notificationsScreen,
            path: Routes.notificationsScreen,
            builder: (context, state) => const Notifications(),
          ),
          GoRoute(
            name: Routes.alertsScreen,
            path: Routes.alertsScreen,
            builder: (context, state) => const Alerts(),
          ),
          GoRoute(
            name: Routes.addPostScreen,
            path: Routes.addPostScreen,
            builder: (context, state) => const AddPost(),
          ),
          GoRoute(
            name: Routes.landingScreen,
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
            path: '/${Routes.commentsScreen}',
            builder: (context, state) {
              final postId = state.uri.queryParameters['postId'] ?? '';
              return Comments(postId: postId);
            },
          ),
          GoRoute(
            name: Routes.chatScreen,
            path: '/chat/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              String name = '고객센터';
              final extra = state.extra;
              if (extra is Map &&
                  extra['name'] is String &&
                  (extra['name'] as String).isNotEmpty) {
                name = extra['name'] as String;
              }
              return ChatScreen(chatRoomId: id, chatRoomName: name);
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
              final paymentId = state.uri.queryParameters['paymentId'];
              if (paymentId == null || paymentId.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('잘못된 접근입니다. (Missing paymentId)')),
                );
              }
              return BuyNow(paymentId: paymentId);
            },
          ),
        ],
      ),

      GoRoute(
        name: 'productDetails',
        path: '/product/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Scaffold(
                  body: Center(child: Text('Product not found')),
                );
              }
              final productMap = snapshot.data!.data() as Map<String, dynamic>;
              final product = Product.fromMap(productMap);
              return ItemDetails(
                product: product,
                arrivalDay: productMap['arrivalDay'] ?? '',
                isSub: false,
              );
            },
          );
        },
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(child: Text('No route defined for ${state.uri.path}')),
        ),
  );
}
