import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable frosted-glass card using BackdropFilter.
/// Wraps any child in a blurred, translucent container with a soft border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.blur = 16,
    this.fillOpacity = 0.08,
    this.borderOpacity = 0.15,
    this.gradient,
    this.width,
    this.height,
    this.onTap,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double fillOpacity;
  final double borderOpacity;
  final Gradient? gradient;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  /// Optional top-edge accent line colour
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null
                  ? Colors.white.withOpacity(fillOpacity)
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: accentColor != null
                    ? BorderSide(color: accentColor!, width: 2)
                    : BorderSide(color: Colors.white.withOpacity(borderOpacity), width: 1),
                left:   BorderSide(color: Colors.white.withOpacity(borderOpacity), width: 1),
                right:  BorderSide(color: Colors.white.withOpacity(borderOpacity), width: 1),
                bottom: BorderSide(color: Colors.white.withOpacity(borderOpacity / 2), width: 1),
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pastel blob used as a background decoration
class BlobDecoration extends StatelessWidget {
  const BlobDecoration({
    super.key,
    required this.color,
    this.size = 300,
    this.blur = 80,
  });

  final Color color;
  final double size;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.35),
        ),
      ),
    );
  }
}

/// Scaffold with the standard ORACLE pastel blob background
class OracleBackground extends StatelessWidget {
  const OracleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF080C14), Color(0xFF0D1117), Color(0xFF131A24)],
            ),
          ),
        ),
        // Top-left blob — lavender
        Positioned(
          top: -80, left: -60,
          child: BlobDecoration(color: AppColors.blobLavender, size: 320),
        ),
        // Top-right blob — teal
        Positioned(
          top: -40, right: -80,
          child: BlobDecoration(color: AppColors.blobSky, size: 280),
        ),
        // Bottom-left blob — coral
        Positioned(
          bottom: -60, left: 100,
          child: BlobDecoration(color: AppColors.blobCoral, size: 240, blur: 100),
        ),
        // Bottom-right blob — gold
        Positioned(
          bottom: -40, right: -40,
          child: BlobDecoration(color: AppColors.blobGold, size: 200, blur: 80),
        ),
        // Content
        child,
      ],
    );
  }
}
