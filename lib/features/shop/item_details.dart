import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/cart/services/favorites_service.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart'; // NEW UI
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart'; // NEW UI
import 'package:ecommerece_app/features/home/widgets/share_dialog.dart'; // NEW UI
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MERGE NOTES:
//   UI     → Branch Y  (Stack body with floating chat button, showShareDialog,
//                       responsive banner padding, bare Padding on bottomNav)
//   Logic  → Branch X  (pending_buynow write, paymentId generation, SafeArea
//                       on bottomNavigationBar for system nav bar protection)
//   Added  → imgUrl field in pending_buynow write (requested)
// ─────────────────────────────────────────────────────────────────────────────

class ItemDetails extends StatefulWidget {
  final Product product;
  final String arrivalDay;
  final bool isSub;
  const ItemDetails({
    super.key,
    required this.product,
    required this.arrivalDay,
    String? itemId,
    required this.isSub,
  });

  @override
  State<ItemDetails> createState() => _ItemDetailsState();
}

class _ItemDetailsState extends State<ItemDetails> {
  // NEW UI: chat service for floating seller chat button
  final ChatService _chatService = ChatService();

  late bool liked = false;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      liked = isFavoritedByUser(p: widget.product, userId: currentUser.uid);
    }
  }

  final PageController _pageController = PageController();
  String? _selectedOption;

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

  // ── NEW LOGIC: write pending_buynow to Firestore then navigate ─────────────
  Future<void> _handleBuyNow({
    required String uid,
    required bool isSub,
    required PricePoint pricePoint,
    required int currentStock,
  }) async {
    try {
      // Generate paymentId server-side style (Firestore doc id)
      final paymentId =
          FirebaseFirestore.instance.collection('orders').doc().id;

      final finalPrice =
          isSub ? pricePoint.price : (pricePoint.price / 0.8).round();

      final pendingColl = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pending_buynow');

      // Clear any stale pending_buynow docs for this user
      final existing = await pendingColl.get();
      for (final doc in existing.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }

      // Write new pending_buynow — includes imgUrl for BuyNow UI display
      await pendingColl.doc(paymentId).set({
        'product_id': widget.product.product_id,
        'product_name': widget.product.productName,
        'imgUrl': widget.product.imgUrl ?? '', // ← ADDED
        'deliveryManagerId': widget.product.deliveryManagerId,
        'price': finalPrice,
        'quantity': pricePoint.quantity,
        'pricePointIndex': int.parse(_selectedOption!),
        'paymentId': paymentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/buy-now?paymentId=$paymentId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    }
  }

  // ── Shared stock + cart check used by both buttons ─────────────────────────
  Future<int?> _getValidatedStock(PricePoint pricePoint) async {
    final productRef = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.product_id);
    final productSnapshot = await productRef.get();
    final currentStock = productSnapshot.data()?['stock'] ?? 0;
    if (pricePoint.quantity > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수량 부족'), backgroundColor: Colors.red),
      );
      return null;
    }
    return currentStock;
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> imageUrls = [
      if (widget.product.imgUrl != null) widget.product.imgUrl,
      ...widget.product.imgUrls,
    ];
    final formatCurrency = NumberFormat('#,###');
    final currentUser = FirebaseAuth.instance.currentUser;

    // ── Not logged in scaffold ─────────────────────────────────────────────
    if (currentUser == null) {
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
                        child: SizedBox(
                          height: 60,
                          child: Center(
                            child: SmoothPageIndicator(
                              controller: _pageController,
                              count: imageUrls.length,
                              effect: const ScrollingDotsEffect(
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
                      icon: const Icon(Icons.arrow_back),
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
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontSize: 14,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.product.productName,
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontSize: 16,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.product.stock == 0
                              ? '품절'
                              : widget.product.arrivalDate ?? '',
                          style: const TextStyle(
                            color: Color(0xFF747474),
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
                        onPressed: () {},
                        icon: const ImageIcon(
                          AssetImage('assets/grey_006m.png'),
                          size: 32,
                          color: Colors.grey,
                        ),
                      ),
                      IconButton(
                        onPressed: null,
                        icon: const ImageIcon(
                          AssetImage('assets/grey_007m.png'),
                          size: 32,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildPricePointsCard(formatCurrency: formatCurrency, isSub: false),
            _buildInfoCard(),
          ],
        ),
        // NEW LOGIC: SafeArea protects against system nav bar overlap
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildCartButton(isLoggedIn: false)),
                SizedBox(width: 10),
                Expanded(
                  child: _buildBuyNowButton(isLoggedIn: false, isSub: false),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Logged-in scaffold ─────────────────────────────────────────────────
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
          body: Stack(
            children: [
              // NEW UI: ListView inside Stack to allow floating chat button
              ListView(
                children: [
                  SizedBox(
                    height: 428,
                    child: Stack(
                      children: [
                        if (imageUrls.isNotEmpty)
                          PageView.builder(
                            controller: _pageController,
                            itemCount: imageUrls.length,
                            onPageChanged: (index) => setState(() {}),
                            itemBuilder:
                                (context, index) => Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Placeholder(),
                                ),
                          )
                        else
                          const Center(child: Text("No images available")),
                        if (imageUrls.isNotEmpty)
                          Positioned.fill(
                            bottom: 0,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
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
                                  ),
                                ),
                              ),
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
                            // NEW UI: showShareDialog instead of ShareService
                            IconButton(
                              onPressed: () {
                                final url =
                                    'https://app.pang2chocolate.com/product/${widget.product.product_id}';
                                showShareDialog(
                                  context,
                                  'product',
                                  url,
                                  widget.product.product_id,
                                  widget.product.productName,
                                  widget.product.imgUrl.toString(),
                                  widget.product.toMap(),
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
                                setState(() => liked = !liked);
                              },
                              icon: ImageIcon(
                                const AssetImage('assets/grey_007m.png'),
                                size: 32,
                                color: liked ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildPricePointsCard(
                    formatCurrency: formatCurrency,
                    isSub: isSub,
                  ),
                  _buildInfoCard(),
                ],
              ),

              // NEW UI: floating chat with seller button
              Positioned(
                right: 0,
                bottom: -10,
                child: IconButton(
                  onPressed: () async {
                    try {
                      final returnList = await _chatService
                          .createDirectChatRoomWithSeller(
                            widget.product.deliveryManagerId.toString(),
                          );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatScreen(
                                chatRoomId: returnList[0],
                                chatRoomName: returnList[1],
                              ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: Image.asset(
                    'assets/chat_with_seller.png',
                    width: 50,
                    height: 50,
                  ),
                ),
              ),
            ],
          ),

          // NEW LOGIC: SafeArea protects against system nav bar overlap (Android + iOS)
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCartButton(
                      isLoggedIn: true,
                      uid: currentUser.uid,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _buildBuyNowButton(
                      isLoggedIn: true,
                      isSub: isSub,
                      uid: currentUser.uid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom button builders ─────────────────────────────────────────────────

  Widget _buildCartButton({required bool isLoggedIn, String? uid}) {
    return TextButton(
      onPressed: () async {
        if (!isLoggedIn || uid == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다")),
          );
          return;
        }
        if (_selectedOption == null) {
          _showQuantityRequiredMessage();
          return;
        }
        final pricePoint =
            widget.product.pricePoints[int.parse(_selectedOption!)];
        final currentStock = await _getValidatedStock(pricePoint);
        if (currentStock == null) return;

        final cartQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('cart')
                .where('product_id', isEqualTo: widget.product.product_id)
                .get();

        int cartTotalQuantity = 0;
        for (var doc in cartQuery.docs) {
          cartTotalQuantity += (doc.data()['quantity'] ?? 0) as int;
        }

        if (cartTotalQuantity + pricePoint.quantity > currentStock) {
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

        await addProductAsNewEntryToCart(
          userId: uid,
          productId: widget.product.product_id,
          pricePointIndex: int.parse(_selectedOption!),
          deliveryManagerId: widget.product.deliveryManagerId ?? '',
          productName: widget.product.productName,
        );
        if (mounted) Navigation(context).pop();
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
    );
  }

  Widget _buildBuyNowButton({
    required bool isLoggedIn,
    required bool isSub,
    String? uid,
  }) {
    return TextButton(
      onPressed: () async {
        if (!isLoggedIn || uid == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다")),
          );
          return;
        }
        if (_selectedOption == null) {
          _showQuantityRequiredMessage();
          return;
        }
        final pricePoint =
            widget.product.pricePoints[int.parse(_selectedOption!)];
        final currentStock = await _getValidatedStock(pricePoint);
        if (currentStock == null) return;

        // NEW LOGIC: write pending_buynow then navigate with paymentId
        await _handleBuyNow(
          uid: uid,
          isSub: isSub,
          pricePoint: pricePoint,
          currentStock: currentStock,
        );
      },
      style: TextButton.styleFrom(
        backgroundColor: ColorsManager.primaryblack,
        padding: EdgeInsets.symmetric(vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        '바로 구매',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'NotoSans',
          fontSize: 18,
        ),
      ),
    );
  }

  // ── Reusable card builders ─────────────────────────────────────────────────

  Widget _buildPricePointsCard({
    required NumberFormat formatCurrency,
    required bool isSub,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 0.27, color: Color(0xFF747474)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            ...widget.product.pricePoints.asMap().entries.map((entry) {
              final index = entry.key;
              final pricePoint = entry.value;
              final perUnit = pricePoint.price / pricePoint.quantity;
              final perUnitN = (pricePoint.price / 0.8) / pricePoint.quantity;

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
                                  style: TextStyles.abeezee14px400wP600,
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
                                          '(1개 ${formatCurrency.format(perUnitN.round())}원)',
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
                    onChanged:
                        (value) => setState(() => _selectedOption = value),
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
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Container(
        padding: EdgeInsets.only(left: 15, top: 15, bottom: 15, right: 15),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 0.27, color: Color(0xFF747474)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('배송', widget.product.arrivalDate ?? ''),
            SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.40, color: Color(0xFF747474)),
            SizedBox(height: 10),
            _buildInfoRow('보관법 및 소비기한', widget.product.instructions),
            SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.40, color: Color(0xFF747474)),
            SizedBox(height: 10),
            _buildInfoRow('남은 수량', '${widget.product.stock.toString()} 개'),
            SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.40, color: Color(0xFF747474)),
            SizedBox(height: 10),
            _buildInfoRow('제품안내', widget.product.description ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String content) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        SizedBox(height: 12 / 2),
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

// ─────────────────────────────────────────────────────────────────────────────

void _launchPaymentPage(String amount, String userId) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/web-payment.html?amount=$amount&userId=$userId',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    debugPrint('Could not launch $url');
    throw 'Could not launch $url';
  }
}

class _ShiningPremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      // NEW UI: responsive padding with .r
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
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
              padding: EdgeInsets.all(20), // NEW UI: responsive
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
                  side: const BorderSide(color: Colors.black, width: 0.6),
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
