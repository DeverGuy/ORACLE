import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Animated metric card shown in the top row of the dashboard.
/// Counts up to [value] on first render with a smooth animation.
class RevenueMetricCard extends StatelessWidget {
  const RevenueMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.blobSky,
    this.isLoading = false,
    this.trend,       // positive = up, negative = down, null = no trend
    this.onTap,
  });

  final String label;
  final double value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isLoading;
  final double? trend;
  final VoidCallback? onTap;

  String get _formatted {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentColor: accentColor,
      onTap: onTap,
      child: isLoading
          ? _buildShimmer()
          : _buildContent(context),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            if (trend != null)
              _TrendBadge(trend: trend!),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _formatted,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        )
            .animate(onPlay: (c) => c.forward())
            .custom(
              duration: 1200.ms,
              curve: Curves.easeOutCubic,
              builder: (ctx, v, child) {
                final animValue = v * value;
                final display = NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(animValue);
                return Text(
                  display,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerBox(width: 40, height: 40, radius: 12),
        const SizedBox(height: 16),
        _ShimmerBox(width: 120, height: 26),
        const SizedBox(height: 6),
        _ShimmerBox(width: 80, height: 13),
        const SizedBox(height: 6),
        _ShimmerBox(width: 60, height: 11),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});
  final double trend;

  @override
  Widget build(BuildContext context) {
    final isUp = trend >= 0;
    final color = isUp ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${trend.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height, this.radius = 8});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: AppColors.glassBorder,
        );
  }
}
