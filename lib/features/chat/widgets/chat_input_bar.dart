import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ecommerece_app/core/theming/colors.dart';

const _kBgColor = Color(0xFFF2F2F2);
const _kBubbleColor = Color(0xFFEEEEEE);
const _kInputBg = Color(0xFFE8E8E8);
const _kSendActive = Color(0xFF1A1A1A);

class InputBar extends StatelessWidget {
  late final TextEditingController controller;
  late final XFile? pickedImage;
  late final VoidCallback onPickImage;
  late final VoidCallback onSend;

  InputBar({
    required this.controller,
    required this.pickedImage,
    required this.onPickImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasContent = controller.text.isNotEmpty || pickedImage != null;

    return SafeArea(
      top: false,
      child: Container(
        color: _kBgColor,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onPickImage,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(fontSize: 14, color: Colors.black),
                        decoration: InputDecoration(
                          hintText: '메시지 입력',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.only(
                            right: 12,
                            top: 10,
                            bottom: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final bool showButton =
                    value.text.trim().isNotEmpty || pickedImage != null;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child:
                      showButton
                          ? Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: onSend,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: _kSendActive,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
