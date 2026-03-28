import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToPayButton extends StatefulWidget {
  final VoidCallback onSlideComplete;
  final Future<bool> Function() onValidate;
  final bool isProcessing;
  final double? height;

  const SlideToPayButton({
    super.key,
    required this.onSlideComplete,
    required this.onValidate,
    this.isProcessing = false,
    this.height,
  });

  @override
  State<SlideToPayButton> createState() => _SlideToPayButtonState();
}

class _SlideToPayButtonState extends State<SlideToPayButton>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  static const double _completeThreshold = 0.88;

  bool _completed = false;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _snapController.addListener(() {
      if (!_completed) {
        setState(() => _progress = _snapAnimation.value);
      }
    });
  }

  @override
  void didUpdateWidget(SlideToPayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isProcessing && !widget.isProcessing && _completed) {
      _resetHandle();
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _resetHandle() {
    setState(() {
      _completed = false;
      _validating = false;
      _progress = 0.0;
    });
  }

  void _snapBack() {
    final startProgress = _progress;
    _snapAnimation = Tween<double>(begin: startProgress, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.forward(from: 0.0);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (_completed || widget.isProcessing || _validating) return;
    _snapController.stop();

    final maxDrag = trackWidth - _trackHeight;
    if (maxDrag <= 0) return;

    setState(() {
      _progress = (_progress + details.delta.dx / maxDrag).clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) async {
    if (_completed || widget.isProcessing || _validating) return;

    if (_progress >= _completeThreshold) {
      setState(() {
        _progress = 1.0;
        _validating = true;
      });

      final allowed = await widget.onValidate();
      if (!mounted) return;

      if (allowed) {
        setState(() => _completed = true);
        HapticFeedback.heavyImpact();
        widget.onSlideComplete();
      } else {
        setState(() => _validating = false);
        _snapBack();
      }
    } else {
      _snapBack();
    }
  }

  double get _trackHeight => widget.height ?? 62.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final handleSize = _trackHeight;
        final maxDrag = trackWidth - handleSize;
        final handleOffset = _progress * maxDrag;

        final labelOpacity = (1.0 - (_progress * 2.0)).clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, trackWidth),
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Container(
            width: trackWidth,
            height: handleSize,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 165, 165, 165),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // ── Black fill grows left → right ──────────────────────
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: handleOffset + handleSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // ── Label ──────────────────────────────────────────────
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: labelOpacity,
                      child: const Text(
                        '밀어서 결제하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Handle ─────────────────────────────────────────────
                Positioned(
                  left: handleOffset,
                  top: 0,
                  child: _Handle(
                    size: handleSize,
                    isProcessing: widget.isProcessing || _validating,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  final double size;
  final bool isProcessing;

  const _Handle({required this.size, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child:
            isProcessing
                ? SizedBox(
                  width: size * 0.38,
                  height: size * 0.38,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : Image.asset(
                  'assets/swiper_logo.png',
                  width: size * 0.9,
                  height: size * 0.9,
                ),
      ),
    );
  }
}
