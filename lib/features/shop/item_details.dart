import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/shop/cart_func.dart';
import 'package:ecommerece_app/features/shop/fav_fnc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ItemDetails extends StatefulWidget {
  final Product product;
  final String arrivalDay;
  final bool isSub;
  const ItemDetails({
    super.key,
    required this.product,
    required this.arrivalDay,
    String?
    itemId, // Note: itemId is declared but not used in the provided snippet
    required this.isSub,
  });

  @override
  State<ItemDetails> createState() => _ItemDetailsState();
}

class _ItemDetailsState extends State<ItemDetails> {
  // late List<PricePoint> _options = widget.product.pricePoints; // Not used, can be removed

  late bool liked = false;
  @override
  void initState() {
    super.initState();
    // Ensure currentUser is not null before accessing uid
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      liked = isFavoritedByUser(p: widget.product, userId: currentUser.uid);
    }
  }

  final PageController _pageController = PageController();
  // int _currentPage = 0; // _currentPage is updated but not used elsewhere. Can be removed if not needed for other logic.

  String? _selectedOption; // Stores the selected value (index as string)

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showQuantityRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('수량을 선택해주세요!'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> imageUrls = [
      if (widget.product.imgUrl != null) widget.product.imgUrl,
      ...widget.product.imgUrls,
    ];

    final formatCurrency = NumberFormat('#,###');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Not logged in, fallback to widget.isSub
      bool isSub = widget.isSub;
      return Scaffold(
        // ...existing code for body and bottomNavigationBar, using isSub...
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
      builder: (context, snapshot) {
        bool isSub = widget.isSub;
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('isSub')) {
            isSub = data['isSub'] == true;
          }
        }
        return Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: 428,
                child: Stack(
                  children: [
                    if (imageUrls.isNotEmpty)
                      PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged:
                            (index) => setState(
                              () {},
                            ), // _currentPage = index (if _currentPage is needed)
                        itemBuilder:
                            (context, index) => Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      const Placeholder(), // Fallback
                            ),
                      )
                    else
                      const Center(
                        child: Text("No images available"),
                      ), // Handle empty image list
                    // Indicator with gradient background
                    if (imageUrls
                        .isNotEmpty) // Show indicator only if there are images
                      Positioned.fill(
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 60,
                            // decoration: BoxDecoration(), // Empty decoration, can be removed
                            child: Center(
                              child: SmoothPageIndicator(
                                controller: _pageController,
                                count: imageUrls.length,
                                effect: ScrollingDotsEffect(
                                  activeDotColor: Colors.black,
                                  dotColor: Colors.grey,
                                  dotHeight: 10,
                                  dotWidth: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 5, // adjust as needed for your design
                      left: 5,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back), // white, semi-transparent
                        // no background
                        onPressed: () {
                          if (GoRouter.of(context).canPop()) {
                            GoRouter.of(context).pop();
                          } else {
                            GoRouter.of(context).goNamed(Routes.navBar);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSub)
                GestureDetector(
                  onTap: () {
                    final currentUser = FirebaseAuth.instance.currentUser;

                    if (currentUser != null) {
                      _launchPaymentPage(
                        '3000', // This seems like a fixed amount
                        currentUser.uid,
                      );
                    } else {
                      // Handle case where user is not logged in, e.g., show a message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 33,
                    color: Colors.black,
                    child: Center(child: _ShiningPremiumBanner()),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // spacing: 10, // Column doesn't have a spacing property directly. Use SizedBox.
                        children: [
                          Text(
                            widget.product.sellerName,
                            style: TextStyle(
                              color: const Color(0xFF121212),
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40, // Removed  as height is a factor
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            widget.product.productName,
                            style: TextStyle(
                              color: const Color(0xFF121212),
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40, // Removed
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            widget.product.stock == 0
                                ? '품절'
                                : widget.product.arrivalDate ?? '',
                            style: TextStyle(
                              color: const Color(0xFF747474),
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40, // Removed
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(), // Spacer is fine here
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            final productId = widget.product.product_id;
                            final base = Uri.base.origin;
                            final url = '$base/product/$productId';
                            await Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('상품 링크가 복사되었습니다!')),
                            );
                          },
                          icon: ImageIcon(
                            const AssetImage('assets/grey_006m.png'),
                            size: 32,
                            color: liked ? Colors.black : Colors.grey,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                                ),
                              );
                              return;
                            }
                            if (liked) {
                              await removeProductFromFavorites(
                                userId: currentUser.uid,
                                productId: widget.product.product_id,
                              );
                            } else {
                              await addProductToFavorites(
                                userId: currentUser.uid,
                                productId: widget.product.product_id,
                              );
                            }
                            setState(() {
                              liked = !liked;
                            });
                          },
                          icon: ImageIcon(
                            const AssetImage(
                              'assets/grey_007m.png',
                            ), // Favorite icon
                            size: 32,
                            color: liked ? Colors.black : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 0.27,
                        color: Color(0xFF747474),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      ...widget.product.pricePoints.asMap().entries.map((
                        entry,
                      ) {
                        int index = entry.key;
                        PricePoint pricePoint = entry.value;
                        double perUnit = pricePoint.price / pricePoint.quantity;
                        return Column(
                          children: [
                            RadioListTile<String>(
                              title: Row(
                                children: [
                                  Text(
                                    '${pricePoint.quantity}개 ${formatCurrency.format(isSub ? pricePoint.price : (pricePoint.price / 0.9).round())}원',
                                    style: TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 16,
                                      height: 1.4, // Removed
                                    ),
                                  ),
                                  SizedBox(width: 5), // Spacing
                                  Text(
                                    '(1개 ${formatCurrency.format(isSub ? perUnit.round() : (perUnit / 0.9).round())}원)',
                                    style: TextStyles.abeezee14px400wP600,
                                  ),
                                ],
                              ),
                              value: index.toString(),
                              groupValue: _selectedOption,
                              onChanged: (value) {
                                setState(() {
                                  _selectedOption = value;
                                });
                              },
                              activeColor:
                                  ColorsManager
                                      .primaryblack, // Example active color
                            ),
                            if (index < widget.product.pricePoints.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 0.40,
                                color: Color(0xFF747474),
                              ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Container(
                  padding: EdgeInsets.only(
                    left: 15,
                    top: 15,
                    bottom: 15,
                    right: 15,
                  ), // Added right padding
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 0.27,
                        color: Color(0xFF747474),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // spacing: 10, // Column doesn't have a spacing property. Use SizedBox between children.
                    children: [
                      _buildInfoRow('배송', widget.product.arrivalDate ?? ''),
                      SizedBox(height: 10),
                      const Divider(
                        height: 1,
                        thickness: 0.40,
                        color: Color(0xFF747474),
                      ),
                      SizedBox(height: 10),
                      _buildInfoRow('보관법 및 소비기한', widget.product.instructions),
                      SizedBox(height: 10),
                      const Divider(
                        height: 1,
                        thickness: 0.40,
                        color: Color(0xFF747474),
                      ),
                      SizedBox(height: 10),
                      _buildInfoRow(
                        '남은 수량',
                        '${widget.product.stock.toString()} 개',
                      ),
                      SizedBox(height: 10),
                      const Divider(
                        height: 1,
                        thickness: 0.40,
                        color: Color(0xFF747474),
                      ),
                      SizedBox(height: 10),
                      _buildInfoRow('제품안내', widget.product.description ?? ''),
                    ],
                  ),
                ),
              ),
              // Padding(padding: EdgeInsets.symmetric(horizontal: 20.w)), // This empty padding does nothing
            ],
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                          ),
                        );
                        return;
                      }
                      if (_selectedOption == null) {
                        _showQuantityRequiredMessage();
                      } else {
                        // Stock validation before adding to cart
                        final pricePoint =
                            widget.product.pricePoints[int.parse(
                              _selectedOption!,
                            )];
                        final productRef = FirebaseFirestore.instance
                            .collection('products')
                            .doc(widget.product.product_id);
                        final productSnapshot = await productRef.get();
                        final currentStock =
                            productSnapshot.data()?['stock'] ?? 0;
                        if (pricePoint.quantity > currentStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('수량 부족'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        await addProductAsNewEntryToCart(
                          userId: currentUser.uid,
                          productId: widget.product.product_id,
                          quantity: pricePoint.quantity,
                          price:
                              isSub
                                  ? pricePoint.price
                                  : (pricePoint.price / 0.9).round(),
                          deliveryManagerId:
                              widget.product.deliveryManagerId ?? '',
                        );
                        if (mounted) {
                          // Check if the widget is still in the tree
                          GoRouter.of(context).pop();
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: ColorsManager.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '장바구니 담기',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'NotoSans',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10), // Use .w for consistency
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                          ),
                        );
                        return;
                      }
                      if (_selectedOption == null) {
                        _showQuantityRequiredMessage();
                      } else {
                        // Stock validation before Buy Now
                        final pricePoint =
                            widget.product.pricePoints[int.parse(
                              _selectedOption!,
                            )];
                        final productRef = FirebaseFirestore.instance
                            .collection('products')
                            .doc(widget.product.product_id);
                        final productSnapshot = await productRef.get();
                        final currentStock =
                            productSnapshot.data()?['stock'] ?? 0;
                        if (pricePoint.quantity > currentStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('수량 부족'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        // Navigate to BuyNow page with product info
                        context.go(
                          '/buy-now',
                          extra: {
                            'product': widget.product,
                            'quantity': pricePoint.quantity,
                            'price':
                                isSub
                                    ? pricePoint.price
                                    : (pricePoint.price / 0.9).round(),
                          },
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: ColorsManager.primaryblack,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '바로 구매',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'NotoSans',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper widget to reduce repetition for info rows
  Widget _buildInfoRow(String title, String content) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF121212),
            fontSize: 16,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w400,
            height: 1.40,
          ),
        ),
        SizedBox(height: 12 / 2), // Adjust spacing as needed
        Text(
          content,
          style: TextStyle(
            color: const Color(0xFF747474),
            fontSize: 14,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w400,
            height: 1.40,
          ),
        ),
      ],
    );
  }
}

void _launchPaymentPage(String amount, String userId) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/web-payment.html?amount=$amount&userId=$userId',
  );

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      // mode: LaunchMode.externalApplication, // Consider if this is needed
    );
  } else {
    // It's good practice to give feedback to the user if launching fails.
    // This could be a SnackBar or an AlertDialog.
    // For example:
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch payment page.')));
    debugPrint('Could not launch $url'); // For debugging
    throw 'Could not launch $url';
  }
}

// Shining animation widget for premium banner
class _ShiningPremiumBanner extends StatefulWidget {
  @override
  State<_ShiningPremiumBanner> createState() => _ShiningPremiumBannerState();
}

class _ShiningPremiumBannerState extends State<_ShiningPremiumBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: false);
    _shineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _shineAnimation,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (Rect bounds) {
                final double shineWidth = bounds.width * 0.35;
                final double shinePosition =
                    bounds.width * _shineAnimation.value;
                return LinearGradient(
                  colors: [
                    Colors.grey.shade700,
                    Colors.white,
                    Colors.grey.shade700,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(
                  Rect.fromLTWH(
                    shinePosition - shineWidth / 2,
                    0,
                    shineWidth,
                    bounds.height,
                  ),
                );
              },
              blendMode: BlendMode.srcATop,
              child: Text(
                '프리미엄 회원 모든 제품 10% 할인',
                style: TextStyles.abeezee16px400wW.copyWith(
                  color: Colors.black,
                ),
              ),
            );
          },
        ),
        horizontalSpace(3),
        AnimatedBuilder(
          animation: _shineAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: 1.0,
              child: Image.asset('assets/sub_bar.png'),
            );
          },
        ),
      ],
    );
  }
}
