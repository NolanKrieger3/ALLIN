import 'package:flutter/material.dart';

/// A wrapper that constrains content to mobile width for a mobile-first design.
/// On larger screens, content is centered with a max width.
class MobileWrapper extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double maxWidth;

  const MobileWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
    this.maxWidth = 430, // iPhone 14 Pro Max width
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.black,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.black,
            border: MediaQuery.of(context).size.width > maxWidth
                ? Border.symmetric(
                    vertical: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
