import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/shop/cart_func.dart';

import 'package:ecommerece_app/features/shop/fav_fnc.dart';

import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Shop extends StatefulWidget {
  const Shop({super.key});

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      List<Map<String, dynamic>> categories =
          snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
            };
          }).toList();

      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no categories, show a message
    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Shop'),
          backgroundColor: ColorsManager.white,
        ),
        body: Center(child: Text('No categories available')),
      );
    }
    int initialIndex = 0;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          // Not logged in, just show the shop as before (or you can restrict access)
          return _buildShopTabController(null);
        }
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(firebaseUser.uid)
                  .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Scaffold(
                body: Center(child: Text('User profile not found')),
              );
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            return _buildShopTabController(userData);
          },
        );
      },
    );
  }

  Widget _buildShopTabController(Map<String, dynamic>? userData) {
    int initialIndex = 0;
    final bool isSub = userData != null && (userData['isSub'] ?? false);
    return DefaultTabController(
      length: _categories.length,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          backgroundColor: ColorsManager.white,
          title: TabBar(
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'NotoSans',
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: ColorsManager.primaryblack,
            ),
            unselectedLabelColor: ColorsManager.primary600,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: ColorsManager.primaryblack,
            isScrollable: _categories.length > 4,
            tabs:
                _categories
                    .map((category) => Tab(text: category['name']))
                    .toList(),
          ),
        ),
        body: TabBarView(
          children:
              _categories
                  .map(
                    (category) => CategoryProductsScreen(
                      categoryId: category['id'],
                      categoryName: category['name'],
                      isSub: isSub,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isSub;

  CategoryProductsScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    this.isSub = false,
  }) : super(key: key);

  @override
  _CategoryProductsScreenState createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  Widget build(BuildContext context) {
    // Display products in a grid
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go(Routes.shopSearchScreen);
        },
        elevation: 0,
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        child: ImageIcon(
          AssetImage('assets/010no.png'),
          color: Colors.white,
          size: 60,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('products')
                  .where('category', isEqualTo: widget.categoryId)
                  .snapshots(),
          builder: (context, snapshot) {
            final formatCurrency = NumberFormat('#,###');
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('아직 제품이 없습니다'));
            }
            final products = snapshot.data!.docs;
            // Sort: available products first, then sold out
            final sortedProducts = List.from(products)..sort((a, b) {
              final stockA = (a.data() as Map<String, dynamic>)['stock'] ?? 0;
              final stockB = (b.data() as Map<String, dynamic>)['stock'] ?? 0;
              if ((stockA > 0 && stockB > 0) || (stockA == 0 && stockB == 0))
                return 0;
              if (stockA > 0) return -1;
              return 1;
            });
            return ListView.separated(
              separatorBuilder: (context, index) {
                if (index == sortedProducts.length - 1) {
                  return SizedBox.shrink();
                }
                return Divider();
              },
              itemCount: sortedProducts.length,
              itemBuilder: (context, index) {
                final data2 =
                    sortedProducts[index].data() as Map<String, dynamic>;
                Product p = Product.fromMap(data2);
                return InkWell(
                  onTap: () async {
                    String arrivalTime = await getArrivalDay(
                      p.meridiem,
                      p.baselineTime,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ItemDetails(
                              product: p,
                              arrivalDay: arrivalTime,
                              isSub: widget.isSub,
                            ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            p.imgUrl!,
                            width: 106,
                            height: 106,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.sellerName,
                                style: TextStyles.abeezee14px400wP600,
                              ),
                              verticalSpace(5),
                              Text(
                                p.productName,
                                style: TextStyles.abeezee16px400wPblack,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.isSub
                                    ? '${formatCurrency.format(p.price)} 원'
                                    : '${formatCurrency.format(p.price / 0.9)} 원',
                                style: TextStyles.abeezee16px400wPblack,
                              ),
                              verticalSpace(2),
                              FutureBuilder<String>(
                                future: getArrivalDay(
                                  p.meridiem,
                                  p.baselineTime,
                                ),
                                builder: (context, snapshot) {
                                  if (p.stock == 0) {
                                    return Text(
                                      '품절',
                                      style: TextStyles.abeezee14px400wP600,
                                    );
                                  }
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      '로딩 중...',
                                      style: TextStyles.abeezee11px400wP600,
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Text(
                                      '오류 발생',
                                      style: TextStyles.abeezee11px400wP600,
                                    );
                                  }

                                  return Text(
                                    '${snapshot.data} 도착예정 · ${p.freeShipping == true ? '무료배송' : '배송료가 부과됩니다'} ',
                                    style: TextStyles.abeezee14px400wP600,
                                  );
                                },
                              ),

                              verticalSpace(4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Create a ProductCard widget
