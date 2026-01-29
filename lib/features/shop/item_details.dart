import 'package:ecommerece_app/core/helpers/drag_scroll_behavior.dart';
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
    // Not logged in: show product details, but disable purchase actions
    if (currentUser == null) {
      // Always show non-premium prices for not-logged-in users
      return Scaffold(
        body: ListView(
          children: [
            SizedBox(
              height: 428,
              child: Stack(
                children: [
                  if (imageUrls.isNotEmpty)
                    PageView.builder(
                      scrollBehavior: DragScrollBehavior(),
                      controller: _pageController,
                      itemCount: imageUrls.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder:
                          (context, index) => Image.network(
                            imageUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Placeholder(),
                          ),
                    )
                  else
                    const Center(child: Text("No images available")),
                  if (imageUrls.isNotEmpty)
                    Positioned.fill(
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 60,
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
                              onDotClicked: (index) {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back),
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
            Container(
              width: double.infinity,
              height: 500,
              color: Colors.black,
              child: Center(child: _ShiningPremiumBanner()),
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
                      children: [
                        Text(
                          widget.product.sellerName,
                          style: TextStyle(
                            color: const Color(0xFF121212),
                            fontSize: 14,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
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
                            height: 1.40,
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
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
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
                          color: Colors.grey,
                        ),
                      ),
                      IconButton(
                        onPressed: null,
                        icon: ImageIcon(
                          const AssetImage('assets/grey_007m.png'),
                          size: 32,
                          color: Colors.grey,
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
                    ...widget.product.pricePoints.asMap().entries.map((entry) {
                      int index = entry.key;
                      PricePoint pricePoint = entry.value;
                      double perUnit = pricePoint.price / pricePoint.quantity;
                      double perunitn =
                          (pricePoint.price / 0.8) / pricePoint.quantity;

                      return Column(
                        children: [
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Text(
                                  '${pricePoint.quantity}개 ',
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(width: 5),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '일반가 ${formatCurrency.format((pricePoint.price / 0.8).round())} 원',
                                          style: TextStyle(
                                            fontFamily: 'NotoSans',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 16,
                                            height: 1.4,
                                          ),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          '(1개 ${formatCurrency.format(perunitn.round())}원)',
                                          style: TextStyles.abeezee14px400wP600,
                                        ),
                                      ],
                                    ),
                                    Container(
                                      color: Colors.black,
                                      child: Row(
                                        children: [
                                          Text(
                                            '멤버십 ${formatCurrency.format(pricePoint.price)} 원',
                                            style: TextStyle(
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16,
                                              height: 1.4,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            '(1개 ${formatCurrency.format(perUnit.round())}원)',
                                            style: TextStyles
                                                .abeezee14px400wP600
                                                .copyWith(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                            activeColor: ColorsManager.primaryblack,
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
                ),
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
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다")),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: ColorsManager.white,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
              SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다")),
                    );
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
                        scrollBehavior: DragScrollBehavior(),
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        physics: const BouncingScrollPhysics(),
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
                                onDotClicked: (index) {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                },
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
                Container(
                  width: double.infinity,
                  height: 500,
                  color: Colors.black,
                  child: Center(child: _ShiningPremiumBanner()),
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
                        double perunitn =
                            (pricePoint.price / 0.8) / pricePoint.quantity;
                        return Column(
                          children: [
                            RadioListTile<String>(
                              title:
                                  isSub
                                      ? Row(
                                        children: [
                                          Text(
                                            '${pricePoint.quantity}개 ${formatCurrency.format(pricePoint.price)}원',
                                            style: TextStyle(
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16,
                                              height: 1.4,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            '(1개 ${formatCurrency.format(perUnit.round())}원)',
                                            style:
                                                TextStyles.abeezee14px400wP600,
                                          ),
                                        ],
                                      )
                                      : Row(
                                        children: [
                                          Text(
                                            '${pricePoint.quantity}개 ',
                                            style: TextStyle(
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 18,
                                              height: 1.4,
                                            ),
                                          ),
                                          SizedBox(width: 5),

                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '일반가 ${formatCurrency.format((pricePoint.price / 0.8).round())} 원',
                                                    style: TextStyle(
                                                      fontFamily: 'NotoSans',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      fontSize: 16,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    '(1개 ${formatCurrency.format(perunitn.round())}원)',
                                                    style:
                                                        TextStyles
                                                            .abeezee14px400wP600,
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                color: Colors.black,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      '멤버십 ${formatCurrency.format(pricePoint.price)} 원',
                                                      style: TextStyle(
                                                        fontFamily: 'NotoSans',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize: 16,
                                                        height: 1.4,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      '(1개 ${formatCurrency.format(perUnit.round())}원)',
                                                      style: TextStyles
                                                          .abeezee14px400wP600
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                        // Before adding to cart, check total quantity in cart
                        final cartQuery =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('cart')
                                .where(
                                  'product_id',
                                  isEqualTo: widget.product.product_id,
                                )
                                .get();

                        int cartTotalQuantity = 0;
                        for (var doc in cartQuery.docs) {
                          final data = doc.data();
                          cartTotalQuantity += (data['quantity'] ?? 0) as int;
                        }

                        if (cartTotalQuantity + pricePoint.quantity >
                            currentStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '해당 상품의 남은 수량은 ${currentStock - cartTotalQuantity}개 입니다.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // ...then call addProductAsNewEntryToCart(...)
                        await addProductAsNewEntryToCart(
                          userId: currentUser.uid,
                          productId: widget.product.product_id,
                          pricePointIndex: int.parse(_selectedOption!),
                          /* isSub
                                  ? pricePoint.price
                                  : (pricePoint.price / 0.8).round() */
                          deliveryManagerId:
                              widget.product.deliveryManagerId ?? '',
                          productName: widget.product.productName,
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
                        // Before adding to cart, check total quantity in cart
                        final cartQuery =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('cart')
                                .where(
                                  'product_id',
                                  isEqualTo: widget.product.product_id,
                                )
                                .get();

                        int cartTotalQuantity = 0;
                        for (var doc in cartQuery.docs) {
                          final data = doc.data();
                          cartTotalQuantity += (data['quantity'] ?? 0) as int;
                        }

                        if (cartTotalQuantity + pricePoint.quantity >
                            currentStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '해당 상품의 남은 수량은 ${currentStock - cartTotalQuantity}개 입니다.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // ...then call addProductAsNewEntryToCart(...)
                        // Navigate to BuyNow page with product info
                        context.go(
                          '/buy-now',
                          extra: {
                            'product': widget.product,
                            'quantity': pricePoint.quantity,
                            'price':
                                isSub
                                    ? pricePoint.price
                                    : (pricePoint.price / 0.8).round(),
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
class _ShiningPremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 370,
            decoration: ShapeDecoration(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 2, color: Colors.white),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  verticalSpace(15),
                  Text(
                    '멤버십 혜택',
                    style: TextStyles.abeezee30px800wW.copyWith(
                      fontFamily: 'ABeeZee',
                    ),
                  ),
                  verticalSpace(50),
                  Text(
                    '월회비 10,000원\n모든 제품 20% 할인',
                    textAlign: TextAlign.center,
                    style: TextStyles.abeezee18px400wPblack.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  verticalSpace(50),
                  Text(
                    '매월 5만원 이상 구매하시는 분은 멤버십 가입을 권합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyles.abeezee18px400wPblack.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          verticalSpace(15),

          TextButton(
            onPressed: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                _launchPaymentPage('10000', currentUser.uid);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다")),
                );
              }
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.white),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: WidgetStateProperty.all(Size(double.infinity, 80)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: BorderSide(color: Colors.black, width: 0.6),
                ),
              ),
            ),
            child: Text(
              '멤버십 가입하기',
              style: TextStyles.abeezee23px800wW.copyWith(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
