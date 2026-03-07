import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/cart/cart.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_list_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Shop extends StatefulWidget {
  const Shop({super.key});

  @override
  State<Shop> createState() => ShopState();
}

class ShopState extends State<Shop> with TickerProviderStateMixin {
  TabController? _tabController;
  final ScrollController categoryProductsScreenScrollController =
      ScrollController();

  @override
  void initState() {
    super.initState();
    // no manual loading, categories are obtained via stream in build
  }

  void resetToFirstCategory() {
    if (_tabController != null) {
      _tabController!.animateTo(0);
    }
    if (categoryProductsScreenScrollController.hasClients) {
      categoryProductsScreenScrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // listen for realtime category changes (with order field)
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('categories')
              .orderBy('order')
              .snapshots(),
      builder: (context, catSnapshot) {
        if (catSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (catSnapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error loading categories')),
          );
        }

        // convert docs to simple map list
        final categories =
            catSnapshot.data?.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'name':
                        (doc.data() as Map<String, dynamic>)['name'] ??
                        'Unknown',
                  },
                )
                .toList() ??
            [];

        if (categories.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('Shop')),
            body: Center(child: Text('No categories available')),
          );
        }

        // now continue with auth/user stream as before
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final firebaseUser = authSnapshot.data;
            if (firebaseUser == null) {
              return _buildShopTabController(null, categories);
            }
            return StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(firebaseUser.uid)
                      .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return Scaffold(
                    body: Center(child: Text('User profile not found')),
                  );
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                return _buildShopTabController(userData, categories);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShopTabController(
    Map<String, dynamic>? userData,
    List<Map<String, dynamic>> categories,
  ) {
    int initialIndex = 0;
    final bool isSub = userData != null && (userData['isSub'] ?? false);

    // Get default address name
    String addressName = '배송지 선택';
    if (userData != null &&
        userData['defaultAddressId'] != null &&
        userData['defaultAddressId'] != '') {
      final addressId = userData['defaultAddressId'];
      final addressSnapshot = FirebaseFirestore.instance
          .collection('addresses')
          .doc(addressId);
      addressSnapshot.get().then((addressDoc) {
        if (addressDoc.exists) {
          final addressData = addressDoc.data() as Map<String, dynamic>;
          setState(() {
            addressName = addressData['address'] ?? 'Unknown';
          });
        }
      });
    }
    return DefaultTabController(
      key: ValueKey(categories.map((c) => c['id']).join(',')),
      length: categories.length,
      initialIndex: initialIndex,
      child: Builder(
        builder: (context) {
          _tabController = DefaultTabController.of(context);

          return Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => Cart()));
              },
              elevation: 0,
              backgroundColor: Colors.black,
              shape: const CircleBorder(),
              child: ImageIcon(
                AssetImage('assets/003m.png'),
                color: Colors.white,
                size: 40,
              ),
            ),
            appBar: AppBar(
              toolbarHeight: 40,
              title: Text(''),
              centerTitle: false,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 4, top: 4),
                          child: FutureBuilder<DocumentSnapshot<Object?>>(
                            future:
                                (userData != null &&
                                        userData['defaultAddressId'] != null &&
                                        userData['defaultAddressId'] != '')
                                    ? FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userData['userId'])
                                        .collection('addresses')
                                        .doc(userData['defaultAddressId'])
                                        .get()
                                    : null,
                            builder: (context, snapshot) {
                              String displayName = '배송지 선택';
                              final addressSnap = snapshot.data;
                              if (addressSnap != null && addressSnap.exists) {
                                final addressData =
                                    addressSnap.data() as Map<String, dynamic>?;
                                displayName =
                                    addressData?['address'] ?? '배송지 선택';
                              }
                              return TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 0,
                                  ),
                                  minimumSize: Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddressListScreen(),
                                    ),
                                  );
                                  setState(() {});
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            context.go(Routes.shopSearchScreen);
                          },
                          icon: ImageIcon(
                            color: Colors.grey,
                            AssetImage('assets/010no.png'),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                    TabBar(
                      tabAlignment:
                          categories.length > 4
                              ? TabAlignment.start
                              : TabAlignment.center,
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
                      isScrollable: categories.length > 4,
                      tabs:
                          categories
                              .map((category) => Tab(text: category['name']))
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
            body: Padding(
              padding: EdgeInsets.only(right: 8, top: 15, bottom: 4),
              child: TabBarView(
                children:
                    categories
                        .map(
                          (category) => CategoryProductsScreen(
                            categoryId: category['id'],
                            categoryName: category['name'],
                            userData: userData,
                            isSub: isSub,
                            scrollController:
                                categoryProductsScreenScrollController,
                          ),
                        )
                        .toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isSub;
  final Map<String, dynamic>? userData;
  final ScrollController? scrollController;

  CategoryProductsScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    required this.userData,
    required this.scrollController,

    this.isSub = false,
  }) : super(key: key);

  @override
  _CategoryProductsScreenState createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? userAddressMap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shopState = context.findAncestorStateOfType<ShopState>();
    if (shopState != null && widget.userData != null) {
      final userData = widget.userData!;
      if (userData['defaultAddressId'] != null &&
          userData['defaultAddressId'] != '') {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userData['userId'])
            .collection('addresses')
            .doc(userData['defaultAddressId'] as String)
            .get()
            .then((doc) {
              if (doc.exists && mounted) {
                setState(() {
                  userAddressMap =
                      (doc.data() as Map<String, dynamic>)['addressMap'];
                });
              }
            });
      }
    }
  }

  bool _isSameRegion(
    Map<String, dynamic>? userAddress,
    Map<String, dynamic>? productAddress,
  ) {
    if (userAddress == null || productAddress == null) return false;
    final userRegion1 =
        userAddress['road_address']?['region_1depth_name'] ??
        userAddress['address']?['region_1depth_name'];
    final userRegion2 =
        userAddress['road_address']?['region_2depth_name'] ??
        userAddress['address']?['region_2depth_name'];
    final productRegion1 =
        productAddress['road_address']?['region_1depth_name'] ??
        productAddress['address']?['region_1depth_name'];
    final productRegion2 =
        productAddress['road_address']?['region_2depth_name'] ??
        productAddress['address']?['region_2depth_name'];
    return (userRegion1 != null &&
            productRegion1 != null &&
            userRegion1 == productRegion1) ||
        (userRegion2 != null &&
            productRegion2 != null &&
            userRegion2 == productRegion2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('products')
                  .where('categoryList', arrayContains: widget.categoryId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            final formatCurrency = NumberFormat('#,###');
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('아직 제품이 없습니다'));
            }
            final products = snapshot.data!.docs;

            List<Product> otherRegion = [];
            List<Product> soldOut = [];

            for (var p in products) {
              Product product = Product.fromMap(
                p.data() as Map<String, dynamic>,
              );
              if (product.stock == 0) {
                soldOut.add(product);
              } else {
                otherRegion.add(product);
              }
            }

            final sortedProducts = [...otherRegion, ...soldOut];

            return ListView.separated(
              controller: widget.scrollController,
              separatorBuilder: (context, index) {
                if (index == sortedProducts.length - 1) {
                  return SizedBox.shrink();
                }
                return Divider();
              },
              itemCount: sortedProducts.length,
              itemBuilder: (context, index) {
                final data2 = sortedProducts[index];
                Product p = data2;
                return InkWell(
                  onTap: () {
                    GoRouter.of(context).pushNamed(
                      'productDetails',
                      pathParameters: {'productId': p.product_id.toString()},
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
                                    : '${formatCurrency.format(p.price / 0.8)} 원',
                                style: TextStyles.abeezee16px400wPblack,
                              ),
                              verticalSpace(2),
                              Text(
                                '${p.arrivalDate ?? ''} ',
                                style: TextStyles.abeezee14px400wP600,
                              ),
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
