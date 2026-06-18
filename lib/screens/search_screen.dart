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

  List<ComicPost> _allSeries = [];
  List<ComicPost> _results = [];
  bool _loadingAll = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllForSearch();
  }

  /// نجلب كل المنشورات مرة واحدة، ثم نفلتر محليًا حسب العنوان عند كل بحث.
  /// هذا أسرع وأخف من إرسال طلب جديد لكل حرف يكتبه المستخدم.
  Future<void> _loadAllForSearch() async {
    setState(() {
      _loadingAll = true;
      _error = null;
    });
    try {
      final posts = await _service.fetchAllPosts(maxResults: 150);
      final seriesOnly =
          posts.where((p) => !ComicService.isIssuePost(p)).toList();
      setState(() => _allSeries = seriesOnly);
    } catch (e) {
      setState(() => _error = 'تعذر تحميل قائمة الأعمال للبحث');
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() {
        _results = _allSeries
            .where((p) => p.title.toLowerCase().contains(q))
            .toList();
      });
    });
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
                onPressed: _loadAllForSearch,
                child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_loadingAll) {
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

    if (_controller.text.trim().isEmpty) {
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
