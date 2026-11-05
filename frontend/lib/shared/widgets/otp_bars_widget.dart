import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Segmented 6-Digit OTP Box / Bar widget with high-visibility cursor and auto-focus
class OtpBarsWidget extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Color activeBorderColor;
  final Color inactiveBorderColor;
  final Color filledColor;

  const OtpBarsWidget({
    super.key,
    this.length = 6,
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.focusNode,
    this.autoFocus = true,
    this.activeBorderColor = AppColors.primaryRed,
    this.inactiveBorderColor = AppColors.border,
    this.filledColor = Colors.white,
  });

  @override
  State<OtpBarsWidget> createState() => _OtpBarsWidgetState();
}

class _OtpBarsWidgetState extends State<OtpBarsWidget> {
  late final FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
      widget.onChanged?.call(widget.controller.text);
      if (widget.controller.text.length == widget.length) {
        widget.onCompleted?.call(widget.controller.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return GestureDetector(
      onTap: () {
        if (!_effectiveFocusNode.hasFocus) {
          FocusScope.of(context).requestFocus(_effectiveFocusNode);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Invisible real input field capturing keyboard events, auto-paste & digits
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: widget.controller,
                focusNode: _effectiveFocusNode,
                autofocus: widget.autoFocus,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // 2. Visible 6 Individual OTP Bars / Digit Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final isFocused = _effectiveFocusNode.hasFocus &&
                  (text.length == index || (text.length == widget.length && index == widget.length - 1));
              final hasChar = index < text.length;
              final char = hasChar ? text[index] : '';

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.filledColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFocused
                        ? widget.activeBorderColor
                        : (hasChar
                            ? widget.activeBorderColor.withValues(alpha: 0.6)
                            : widget.inactiveBorderColor),
                    width: isFocused ? 2.2 : 1.4,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: widget.activeBorderColor.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: hasChar
                      ? Text(
                          char,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : (isFocused
                          ? Container(
                              width: 2,
                              height: 20,
                              decoration: BoxDecoration(
                                color: widget.activeBorderColor,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.inactiveBorderColor.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                            )),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

