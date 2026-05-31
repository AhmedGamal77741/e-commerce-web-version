import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:ecommerece_app/features/review/ui/exchange_or_refund.dart';
import 'package:ecommerece_app/features/review/ui/track_order.dart';
import 'package:ecommerece_app/features/review/ui/widgets/text_and_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// OrderHistory — main page
// ---------------------------------------------------------------------------
class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  final Map<String, Map<String, dynamic>?> _productCache = {};

  Future<Map<String, dynamic>?> _getProduct(String productId) async {
    if (_productCache.containsKey(productId)) return _productCache[productId];
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .get();
      final data = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _productCache[productId] = data;
      return data;
    } catch (_) {
      _productCache[productId] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return const Center(child: Text('내 페이지 탭에서 회원가입 후 이용가능합니다.'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('orderDate', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            // ── First load: show shimmer skeletons ──────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _OrderSkeletonList();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('주문 내역이 없습니다.'));
            }

            final orders = snapshot.data!.docs;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: ListView.separated(
                itemCount: orders.length,
                separatorBuilder:
                    (_, __) => Divider(color: ColorsManager.primary300),
                itemBuilder: (context, index) {
                  final data = orders[index].data() as Map<String, dynamic>;
                  final productId = data['productId'] as String? ?? '';

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getProduct(productId),
                    builder: (context, productSnapshot) {
                      // Per-item skeleton only on true first fetch
                      if (productSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !_productCache.containsKey(productId)) {
                        return const _OrderCardSkeleton();
                      }

                      final product = productSnapshot.data;

                      if (product == null || product.isEmpty) {
                        return _FadeIn(
                          delay: Duration(milliseconds: index * 60),
                          child: _DeletedProductCard(orderData: data),
                        );
                      }

                      return _FadeIn(
                        delay: Duration(milliseconds: index * 60),
                        child: _OrderItem(
                          orderData: data,
                          product: product,
                          user: user,
                          onDelete: () => deleteOrder(data, context),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fade-in wrapper — staggered reveal for each card
// ---------------------------------------------------------------------------
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton — full page version shown on first load
// ---------------------------------------------------------------------------
class _OrderSkeletonList extends StatelessWidget {
  const _OrderSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => Divider(color: ColorsManager.primary300),
        itemBuilder: (_, index) => _ShimmerCard(index: index),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer card — each skeleton item animates with a staggered delay
// ---------------------------------------------------------------------------
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.index});
  final int index;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Stagger each card's shimmer phase slightly
    _shimmer = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final gradient = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
            stops: [
              (_shimmer.value - 0.5).clamp(0.0, 1.0),
              _shimmer.value.clamp(0.0, 1.0),
              (_shimmer.value + 0.5).clamp(0.0, 1.0),
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: gradient,
                ),
              ),
              horizontalSpace(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    verticalSpace(6),
                    // Seller name line
                    _ShimmerLine(gradient: gradient, width: 80, height: 11),
                    verticalSpace(8),
                    // Product name line
                    _ShimmerLine(gradient: gradient, width: 160, height: 13),
                    verticalSpace(8),
                    // Price line
                    _ShimmerLine(gradient: gradient, width: 100, height: 11),
                    verticalSpace(14),
                    // Buttons row
                    Row(
                      children: [
                        _ShimmerLine(
                          gradient: gradient,
                          width: 72,
                          height: 28,
                          radius: 6,
                        ),
                        horizontalSpace(8),
                        _ShimmerLine(
                          gradient: gradient,
                          width: 100,
                          height: 28,
                          radius: 6,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({
    required this.gradient,
    required this.width,
    required this.height,
    this.radius = 4,
  });

  final LinearGradient gradient;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-item skeleton (used while product data loads individually)
// ---------------------------------------------------------------------------
class _OrderCardSkeleton extends StatefulWidget {
  const _OrderCardSkeleton();

  @override
  State<_OrderCardSkeleton> createState() => _OrderCardSkeletonState();
}

class _OrderCardSkeletonState extends State<_OrderCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final gradient = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
            stops: [
              (_shimmer.value - 0.5).clamp(0.0, 1.0),
              _shimmer.value.clamp(0.0, 1.0),
              (_shimmer.value + 0.5).clamp(0.0, 1.0),
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: gradient,
                ),
              ),
              horizontalSpace(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    verticalSpace(6),
                    _ShimmerLine(gradient: gradient, width: 80, height: 11),
                    verticalSpace(8),
                    _ShimmerLine(gradient: gradient, width: 160, height: 13),
                    verticalSpace(8),
                    _ShimmerLine(gradient: gradient, width: 100, height: 11),
                    verticalSpace(14),
                    Row(
                      children: [
                        _ShimmerLine(
                          gradient: gradient,
                          width: 72,
                          height: 28,
                          radius: 6,
                        ),
                        horizontalSpace(8),
                        _ShimmerLine(
                          gradient: gradient,
                          width: 100,
                          height: 28,
                          radius: 6,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single order row
// ---------------------------------------------------------------------------
class _OrderItem extends StatelessWidget {
  const _OrderItem({
    required this.orderData,
    required this.product,
    required this.user,
    required this.onDelete,
  });

  final Map<String, dynamic> orderData;
  final Map<String, dynamic> product;
  final User user;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            product['imgUrl'] ?? '',
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
          ),
        ),
        horizontalSpace(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextAndButtons(
                sellerName: product['sellerName'] ?? '',
                productName: product['productName'] ?? '',
                qunatity: orderData['quantity'].toString(),
                orderPrice: orderData['totalPrice'],
                baselineTime: product['baselineTime'],
                meridiem: product['meridiem'],
              ),
              Row(
                children: [
                  BlackTextButton(
                    txt: '배송조회',
                    style: TextStyles.abeezee14px400wW,
                    func: () async {
                      final arrivalDate = await getArrivalDay2(
                        product['meridiem'],
                        product['baselineTime'],
                      );
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => TrackOrder(
                                order: orderData,
                                arrivalDate: arrivalDate,
                              ),
                        ),
                      );
                    },
                  ),
                  horizontalSpace(5),
                  if (orderData['confirmed'] == true) ...[
                    if (orderData['isRequested'] == true)
                      BlackTextButton(
                        txt: '교환 · 반품 신청',
                        style: TextStyles.abeezee14px400wW.copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red,
                          decorationThickness: 2,
                        ),
                        func: () {},
                      )
                    else
                      BlackTextButton(
                        txt: '교환 · 반품 신청',
                        style: TextStyles.abeezee14px400wW,
                        func: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ExchangeOrRefund(
                                    userId: user.uid,
                                    orderId: orderData['orderId'],
                                  ),
                            ),
                          );
                        },
                      ),
                  ] else
                    BlackTextButton(
                      txt: '주문취소',
                      style: TextStyles.abeezee14px400wW,
                      func: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.more_horiz,
            color: ColorsManager.primary600,
            size: 18,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Deleted product card
// ---------------------------------------------------------------------------
class _DeletedProductCard extends StatelessWidget {
  const _DeletedProductCard({required this.orderData});
  final Map<String, dynamic> orderData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade500,
              size: 32,
            ),
          ),
          horizontalSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '판매 종료된 상품',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                verticalSpace(4),
                Text(
                  '이 상품은 더 이상 판매되지 않습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                verticalSpace(4),
                Text(
                  '결제금액: ₩${orderData['totalPrice']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Future<Map<String, dynamic>> fetchProductDetails(String productId) async {
  final doc =
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
  return doc.exists ? doc.data() as Map<String, dynamic> : {};
}

bool isDispatched(Map<String, dynamic> product, String orderDate) {
  final now = DateTime.now();
  final orderTime = DateTime.parse(orderDate);
  int adjustedHour = product['baselineTime'] as int;
  final meridiem = (product['meridiem'] as String).toLowerCase();
  if (meridiem == 'pm' && adjustedHour < 12)
    adjustedHour += 12;
  else if (meridiem == 'am' && adjustedHour == 12)
    adjustedHour = 0;
  final cutoff = DateTime(
    orderTime.year,
    orderTime.month,
    orderTime.day,
    adjustedHour,
  );
  final nextDay = cutoff.add(const Duration(days: 1));
  if (orderTime.isBefore(cutoff) && now.isAfter(cutoff)) return true;
  if (orderTime.isAfter(cutoff) && now.isAfter(nextDay)) return true;
  return false;
}

Future<void> deleteOrder(
  Map<String, dynamic> order,
  BuildContext context,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '주문취소',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '정말로 주문을 취소하시겠습니까?\n취소 시 결제 금액이 환불됩니다.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => navigator.pop(true),
              child: const Text('확인', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final orderId = order['orderId'] as String?;
    final refundTotalRaw = order['totalPrice'];
    final refundTotal =
        refundTotalRaw is int
            ? refundTotalRaw
            : refundTotalRaw is double
            ? refundTotalRaw.toInt()
            : int.tryParse(refundTotalRaw.toString());

    if (orderId == null || refundTotal == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('주문 정보가 올바르지 않습니다.')),
      );
      return;
    }

    final callable = FirebaseFunctions.instance.httpsCallable('requestRefund');
    final result = await callable.call({
      'uid': user.uid,
      'orderId': orderId,
      'type': 'cancel',
    });

    navigator.pop();

    final data = result.data;
    if (data != null &&
        (data['status'] == 'refunded' || data['status'] == 'canceled')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('주문이 성공적으로 취소되었습니다.')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('주문 취소에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('주문 취소 중 오류가 발생했습니다. 다시 시도해주세요.')),
    );
  }
}
