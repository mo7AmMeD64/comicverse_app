import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic_post.dart';
import '../theme.dart';

/// بطاقة عرض عمل واحد (صورة الغلاف + العنوان + شارة الحالة) تستخدم في الشبكات والقوائم.
class ComicCard extends StatelessWidget {
  final ComicPost comic;
  final VoidCallback onTap;

  const ComicCard({super.key, required this.comic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (comic.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: comic.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.surfaceVariant,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariant,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppTheme.textMuted),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surfaceVariant,
                      child: const Icon(Icons.menu_book_outlined,
                          color: AppTheme.textMuted, size: 32),
                    ),
                  if (comic.statusLabel != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: comic.isOngoing
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          comic.statusLabel!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            comic.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
