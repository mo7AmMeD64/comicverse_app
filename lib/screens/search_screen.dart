import 'dart:async';
import 'package:flutter/material.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../theme.dart';
import '../widgets/comic_card.dart';
import '../widgets/comic_card_shimmer.dart';
import 'comic_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ComicService _service = ComicService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<ComicPost> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  /// نستخدم بحث Blogger الرسمي على الخادم (معامل q) بدلاً من تحميل كل
  /// منشورات الموقع محليًا وفلترتها؛ الموقع قد يحوي آلاف المنشورات (كل
  /// عدد منشور مستقل)، فتحميلها دفعة واحدة لن يغطي كل الأعمال أبدًا.
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });
    try {
      final posts = await _service.searchPosts(query, maxResults: 60);
      // نريد فقط منشورات الأعمال (Series) في نتائج البحث، لا الأعداد الفردية
      final seriesOnly =
          posts.where((p) => !ComicService.isIssuePost(p)).toList();
      if (!mounted) return;
      setState(() => _results = seriesOnly);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر إجراء البحث، تحقق من الاتصال');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: (v) {
            final q = v.trim();
            if (q.isNotEmpty) _runSearch(q);
          },
          decoration: const InputDecoration(
            hintText: 'ابحث عن اسم العمل...',
            border: InputBorder.none,
          ),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _runSearch(_controller.text.trim()),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => const ComicCardShimmer(),
      );
    }

    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ابدأ بكتابة اسم العمل الذي تبحث عنه',
            style: TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج مطابقة',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final comic = _results[index];
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
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }
}
