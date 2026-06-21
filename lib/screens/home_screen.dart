import 'package:flutter/material.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../theme.dart';
import '../widgets/comic_section_row.dart';
import 'comic_detail_screen.dart';
import 'search_screen.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ComicService _service = ComicService();

  bool _loading = true;
  String? _error;
  final Map<String, List<ComicPost>> _sections = {};

  static const List<String> _homeSections = ['MARVEL', 'DC', 'IMAGE'];

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      for (final cat in _homeSections) {
        final posts = await _service.fetchByLabel(cat, maxResults: 12);
        // فلترة: نريد فقط منشورات الأعمال (وليس الأعداد الفردية) في الصفحة الرئيسية
        final seriesOnly =
            posts.where((p) => !ComicService.isIssuePost(p)).toList();
        _sections[cat] = seriesOnly;
      }
    } catch (e) {
      _error = 'تعذر تحميل البيانات، تحقق من اتصال الإنترنت';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(ComicPost comic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComicDetailScreen(seriesPost: comic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comicverse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHome,
        color: AppTheme.primaryRed,
        child: _error != null
            ? _buildError()
            : ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 30),
                children: [
                  _buildCategoryChips(),
                  const SizedBox(height: 10),
                  for (final cat in _homeSections)
                    ComicSectionRow(
                      title: ComicService.categoryDisplayNames[cat] ?? cat,
                      comics: _sections[cat] ?? [],
                      loading: _loading,
                      onTapComic: _openDetail,
                      onSeeAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryScreen(category: cat),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: ComicService.mainCategories.length,
        itemBuilder: (context, index) {
          final cat = ComicService.mainCategories[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              label: Text(ComicService.categoryDisplayNames[cat] ?? cat),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryScreen(category: cat),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHome,
              child: const Text('إعادة المحاولة'),
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
