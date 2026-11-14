import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final opacity = 0.3 + (_animCtrl.value * 0.4);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.surfaceLight.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 140, height: 20),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 28),
          SizedBox(height: 20),
          SkeletonBox(height: 80, borderRadius: 16),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 100, borderRadius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 100, borderRadius: 14)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 100, borderRadius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 100, borderRadius: 14)),
            ],
          ),
          SizedBox(height: 20),
          SkeletonBox(height: 160, borderRadius: 16),
        ],
      ),
    );
  }
}

class InventorySkeleton extends StatelessWidget {
  const InventorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 160, height: 26),
          const SizedBox(height: 16),
          const SkeletonBox(height: 48, borderRadius: 12),
          const SizedBox(height: 16),
          const SkeletonBox(height: 36, borderRadius: 10),
          const SizedBox(height: 16),
          ...List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 72, borderRadius: 12),
            ),
          ),
        ],
      ),
    );
  }
}
