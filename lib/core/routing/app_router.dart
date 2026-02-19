import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/features/cart/order_complete.dart';
import 'package:ecommerece_app/features/cart/place_order.dart';
import 'package:ecommerece_app/features/cart/buy_now.dart';
import 'package:ecommerece_app/features/home/add_post.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/notifications.dart';
import 'package:ecommerece_app/features/home/widgets/alerts.dart';
import 'package:ecommerece_app/features/mypage/ui/cancel_subscription.dart';
import 'package:ecommerece_app/features/mypage/ui/delete_account_screen.dart';
import 'package:ecommerece_app/features/navBar/nav_bar.dart';
import 'package:ecommerece_app/features/review/ui/review_screen.dart';
import 'package:ecommerece_app/features/shop/shop_search.dart';
import 'package:ecommerece_app/landing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_comments.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: Routes.navBar,
    routes: [
      // Deep link for product details
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
              // You may need to adjust this to match your Product model constructor
              final product = Product.fromMap(productMap);
              return ItemDetails(
                product: product,
                arrivalDay: productMap['arrivalDay'] ?? '',
                isSub: false, // Or derive from productMap if needed
              );
            },
          );
        },
      ),
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
            name: Routes.alertsScreen,
            path: Routes.alertsScreen, // '/notifications'
            builder: (context, state) => const Alerts(),
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
              // Check auth and subscription status
              return FutureBuilder(
                future: Future.value(FirebaseAuth.instance.currentUser),
                builder: (context, authSnapshot) {
                  final user = authSnapshot.data;
                  if (user == null) {
                    // Not logged in: show guest comments
                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .get(),
                      builder: (context, postSnapshot) {
                        if (!postSnapshot.hasData ||
                            postSnapshot.data?.data() == null) {
                          return const Scaffold(
                            body: Center(child: Text('Post not found')),
                          );
                        }
                        final postMap =
                            postSnapshot.data!.data() as Map<String, dynamic>;
                        postMap['postId'] = postId;
                        postMap['fromComments'] = true;
                        return GuestComments(post: postMap);
                      },
                    );
                  }
                  // Logged in: check subscription
                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData ||
                          userSnapshot.data?.data() == null) {
                        return const Scaffold(
                          body: Center(child: Text('User profile not found')),
                        );
                      }
                      final userMap =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final isSub = userMap['isSub'] == true;
                      if (isSub) {
                        return Comments(postId: postId);
                      } else {
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(postId)
                                  .get(),
                          builder: (context, postSnapshot) {
                            if (!postSnapshot.hasData ||
                                postSnapshot.data?.data() == null) {
                              return const Scaffold(
                                body: Center(child: Text('Post not found')),
                              );
                            }
                            final postMap =
                                postSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            postMap['postId'] = postId;
                            postMap['fromComments'] = true;
                            return GuestComments(post: postMap);
                          },
                        );
                      }
                    },
                  );
                },
              );
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
              // Expect a paymentId query parameter created by the client
              final paymentId = state.uri.queryParameters['paymentId'];
              if (paymentId == null || paymentId.isEmpty) {
                return Scaffold(
                  body: Center(child: Text('잘못된 접근입니다. (Missing paymentId)')),
                );
              }
              return BuyNow(paymentId: paymentId);
            },
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(child: Text('No route defined for ${state.uri.path}')),
        ),
    routerNeglect: false,
  );
}
