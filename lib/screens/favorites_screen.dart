import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../services/favorites_service.dart';
import '../theme.dart';
import 'comic_detail_screen.dart';

/// شاشة المفضلة: تعرض الأعمال التي أضافها المستخدم، وآخر الأعداد التي قرأها.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favService = FavoritesService();
  final ComicService _service = ComicService();

  bool _loading = true;
  List<ComicPost> _favorites = [];
  Map<String, dynamic> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final favLinks = await _favService.getFavorites();
    _progress = await _favService.getAllProgress();

    if (favLinks.isEmpty) {
      setState(() {
        _favorites = [];
        _loading = false;
      });
      return;
    }

    try {
      // نجلب كل المنشورات الحديثة، ثم نطابقها مع روابط المفضلة المحفوظة.
      // (بديل أخف من إجراء طلب شبكة منفصل لكل عنصر مفضل)
      final all = await _service.fetchAllPosts(maxResults: 150);
      final matched = all.where((p) => favLinks.contains(p.link)).toList();
      setState(() => _favorites = matched);
    } catch (e) {
      // تجاهل بصمت، تُعرض القائمة الفارغة
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : _favorites.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryRed,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final comic = _favorites[index];
                      final prog = _progress[comic.title];
                      return _FavoriteTile(
                        comic: comic,
                        lastIssueTitle: prog != null
                            ? prog['lastIssueTitle'] as String?
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ComicDetailScreen(seriesPost: comic),
                          ),
                        ).then((_) => _load()),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'لا توجد أعمال في المفضلة بعد\nاضغط على أيقونة القلب في صفحة أي عمل لإضافته',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

class _FavoriteTile extends StatelessWidget {
  final ComicPost comic;
  final String? lastIssueTitle;
  final VoidCallback onTap;

  const _FavoriteTile({
    required this.comic,
    required this.lastIssueTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 50,
            height: 70,
            child: comic.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: comic.thumbnailUrl!, fit: BoxFit.cover)
                : Container(color: AppTheme.surfaceVariant),
          ),
        ),
        title: Text(comic.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          lastIssueTitle != null ? 'آخر قراءة: $lastIssueTitle' : 'لم تبدأ القراءة بعد',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppTheme.textMuted),
      ),
    );
  }
}
