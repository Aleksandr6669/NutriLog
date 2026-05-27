import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../styles/app_colors.dart';

class FabMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Duration delay;
  final bool isLocked;

  const FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.delay = Duration.zero,
    this.isLocked = false,
    super.key,
  });

  @override
  State<FabMenuItem> createState() => _FabMenuItemState();
}

class _FabMenuItemState extends State<FabMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _textWidth;
  late Animation<double> _opacity;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Иконка "выскакивает" первой (0.0 -> 0.5)
    _iconScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Текст "выезжает" и появляется после иконки (0.4 -> 1.0)
    _textWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // Скольжение снизу вверх (0.0 -> 0.6)
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideUp,
      child: GestureDetector(
        onTap: () {
          if (widget.isLocked) {
            HapticFeedback.heavyImpact();
          } else {
            HapticFeedback.lightImpact();
          }
          widget.onTap();
        },
        child: Opacity(
          opacity: widget.isLocked ? 0.6 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Текст
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final textStyle = TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        widget.isLocked ? Colors.grey.shade600 : Colors.black87,
                  );

                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: _textWidth.value,
                      child: Opacity(
                        opacity: _opacity.value,
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.label,
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Кружок с иконкой
              ScaleTransition(
                scale: _iconScale,
                child: Container(
                  width: 48,
                  height: 48,
                  // Небольшой отступ справа, чтобы выровнять с главной FAB кнопкой (которая 58x58)
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isLocked ? Colors.grey[200] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        color:
                            widget.isLocked ? Colors.grey : AppColors.primary,
                        size: 24,
                      ),
                      if (widget.isLocked)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
