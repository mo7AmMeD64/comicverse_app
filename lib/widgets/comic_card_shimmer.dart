import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme.dart';

/// نسخة بديلة لبطاقة العمل تظهر أثناء التحميل بتأثير لامع (Shimmer).
class ComicCardShimmer extends StatelessWidget {
  const ComicCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(color: AppTheme.surfaceVariant),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            width: double.infinity,
            color: AppTheme.surfaceVariant,
          ),
        ],
      ),
    );
  }
}
