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

  @override
  void didChangeDependencies() {
    precacheImage(AssetImage('assets/010no.png'), context);
    super.didChangeDependencies();
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
    return DefaultTabController(
      length: _categories.length,
      initialIndex: initialIndex,

      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          backgroundColor: ColorsManager.white,
          title: TabBar(
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
            isScrollable:
                _categories.length > 4, // Make scrollable if many categories
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
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

// Create a CategoryProductsScreen widget to display products for each category
class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  CategoryProductsScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  _CategoryProductsScreenState createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  void initState() {
    super.initState();
  }

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
          size: 56,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('products')
                  .where('category', isEqualTo: widget.categoryId)
                  .snapshots(),

          builder: (context, snapshot) {
            print(snapshot);
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
            return ListView.separated(
              separatorBuilder: (context, index) {
                if (index == products.length - 1) {
                  return SizedBox.shrink();
                }
                return Divider();
              },
              itemCount: products.length,
              itemBuilder: (context, index) {
                final data2 = products[index].data() as Map<String, dynamic>;
                Product p = Product.fromMap(data2);

                return InkWell(
                  onTap: () async {
                    bool isSub = await isUserSubscribed();
                    bool liked = isFavoritedByUser(
                      p: p,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    );
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
                              isSub: isSub,
                            ),
                      ),
                    );

                    // context.pushNamed(
                    //   Routes.itemDetailsScreen,
                    //   arguments: {
                    // 'imgUrl': data['imgUrl'],
                    // 'sellerName': data['sellerName	'],
                    // 'price': data['price	'],
                    // 'product_id': data['product_id'],
                    // 'freeShipping': data['freeShipping	'],
                    // 'meridiem': data['meridiem'],
                    // 'baselinehour': data['baselinehour	'],
                    // 'productName': data['productName	'],
                    //   },
                    // );
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
                              FutureBuilder<bool>(
                                future: isUserSubscribed(),
                                builder: (context, snapshot) {
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
                                  print(snapshot.data);
                                  if (snapshot.data == true) {
                                    return Text(
                                      '${formatCurrency.format(p.price)} 원',

                                      style: TextStyles.abeezee16px400wPblack,
                                    );
                                  } else {
                                    return Text(
                                      '${formatCurrency.format(p.price / 0.9)} 원',

                                      style: TextStyles.abeezee16px400wPblack,
                                    );
                                  }
                                },
                              ),
                              verticalSpace(2),
                              FutureBuilder<String>(
                                future: getArrivalDay(
                                  p.meridiem,
                                  p.baselineTime,
                                ),
                                builder: (context, snapshot) {
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
