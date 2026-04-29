import 'package:flutter/material.dart';
import '../../styles/app_colors.dart';

class FabMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Duration delay;

  const FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.delay = Duration.zero,
    super.key,
  });

  @override
  State<FabMenuItem> createState() => _FabMenuItemState();
}

class _FabMenuItemState extends State<FabMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textWidth;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _textWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 234, 246, 235),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Оценка ширины текста
                final text = widget.label;
                const textStyle =
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
                final textPainter = TextPainter(
                  text: TextSpan(text: text, style: textStyle),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                )..layout();
                final textWidth = textPainter.size.width;
                const iconWidth = 32.0;
                const spacing = 10.0;
                const minWidth = iconWidth; // только иконка
                final maxWidth = textWidth + spacing + iconWidth;
                final width =
                    (minWidth + (maxWidth - minWidth)+20) * _textWidth.value;
                return SizedBox(
                  width: width,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              widget.label,
                              overflow: TextOverflow.clip,
                              style: textStyle,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        Icon(widget.icon, color: AppColors.primary, size: 38),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
