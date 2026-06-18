import 'package:flutter/material.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../theme.dart';
import '../widgets/comic_card.dart';
import '../widgets/comic_card_shimmer.dart';
import 'comic_detail_screen.dart';

/// شاشة تعرض كل أعمال تصنيف واحد (ناشر أو نوع) في شبكة مع تحميل تدريجي.
class CategoryScreen extends StatefulWidget {
  final String category;
  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ComicService _service = ComicService();
  final List<ComicPost> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts =
          await _service.fetchByLabel(widget.category, maxResults: 100);
      final seriesOnly =
          posts.where((p) => !ComicService.isIssuePost(p)).toList();
      setState(() {
        _items.clear();
        _items.addAll(seriesOnly);
      });
    } catch (e) {
      setState(() => _error = 'تعذر تحميل الأعمال');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        ComicService.categoryDisplayNames[widget.category] ?? widget.category;
    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _load, child: const Text('إعادة المحاولة')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryRed,
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                itemCount: _loading ? 9 : _items.length,
                itemBuilder: (context, index) {
                  if (_loading) return const ComicCardShimmer();
                  final comic = _items[index];
                  return ComicCard(
                    comic: comic,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComicDetailScreen(seriesPost: comic),
                      ),
                    ),
                  );
                },
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
