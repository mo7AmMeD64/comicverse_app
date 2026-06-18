import 'package:flutter/material.dart';
import '../models/comic_post.dart';
import '../theme.dart';
import 'comic_card.dart';
import 'comic_card_shimmer.dart';

/// قسم أفقي قابل للتمرير بعنوان (مثل "MARVEL" أو "الأكثر مشاهدة") وزر "عرض الكل".
class ComicSectionRow extends StatelessWidget {
  final String title;
  final List<ComicPost> comics;
  final bool loading;
  final void Function(ComicPost) onTapComic;
  final VoidCallback? onSeeAll;

  const ComicSectionRow({
    super.key,
    required this.title,
    required this.comics,
    required this.onTapComic,
    this.loading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && comics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'عرض الكل',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: loading ? 6 : comics.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 130,
                    child: loading
                        ? const ComicCardShimmer()
                        : ComicCard(
                            comic: comics[index],
                            onTap: () => onTapComic(comics[index]),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
