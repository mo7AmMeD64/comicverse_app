import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../services/favorites_service.dart';
import '../theme.dart';

/// شاشة قراءة عدد واحد: تعرض كل صور الفصل بالتمرير العمودي المتسلسل
/// (مطابق لتجربة قراءة الكوميكس الأصلية على الموقع)، مع أزرار للتنقل
/// إلى العدد السابق/التالي بدون الرجوع لصفحة التفاصيل.
class IssueReaderScreen extends StatefulWidget {
  final ComicPost issue;
  final List<ComicPost> allIssues;
  final int currentIndex;
  final ComicPost seriesPost;
  final String seriesLabel;

  const IssueReaderScreen({
    super.key,
    required this.issue,
    required this.allIssues,
    required this.currentIndex,
    required this.seriesPost,
    required this.seriesLabel,
  });

  @override
  State<IssueReaderScreen> createState() => _IssueReaderScreenState();
}

class _IssueReaderScreenState extends State<IssueReaderScreen> {
  final ComicService _service = ComicService();
  final FavoritesService _favService = FavoritesService();

  late ComicPost _currentIssue;
  late int _currentIndex;
  List<String> _images = [];
  bool _loading = true;
  String? _error;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIssue = widget.issue;
    _currentIndex = widget.currentIndex;
    _loadIssueImages();
  }

  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.allIssues.length - 1;

  Future<void> _loadIssueImages() async {
    setState(() {
      _loading = true;
      _error = null;
      _images = [];
    });
    try {
      // نجلب العدد المطلوب بعنوانه الدقيق فقط (مع تضييق البحث ضمن تصنيف
      // العمل)، بدل تحميل كل أعداد العمل بمحتواها الكامل دفعة واحدة - وهذا
      // قد يكون ثقيلًا جدًا لأعمال طويلة (مئات آلاف الأحرف لمجرد عدد واحد).
      final full = await _service.fetchSingleIssueByTitle(
              widget.seriesLabel, _currentIssue.title) ??
          _currentIssue;
      final imgs = full.extractAllImages();
      setState(() => _images = imgs);

      await _favService.saveProgress(
        seriesLabel: widget.seriesPost.title,
        seriesTitle: widget.seriesPost.title,
        seriesImage: widget.seriesPost.thumbnailUrl,
        lastIssueLink: _currentIssue.link,
        lastIssueTitle: _currentIssue.title,
      );
    } catch (e) {
      setState(() => _error = 'تعذر تحميل صفحات هذا العدد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.allIssues.length) return;
    setState(() {
      _currentIndex = index;
      _currentIssue = widget.allIssues[index];
    });
    _loadIssueImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: _buildReaderBody(),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _buildTopBar(),
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _buildBottomNav(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadIssueImages,
                child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_images.isEmpty) {
      return const Center(
        child: Text('لا توجد صور لهذا العدد',
            style: TextStyle(color: Colors.white)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 70, bottom: 90),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return CachedNetworkImage(
          imageUrl: _images[index],
          fit: BoxFit.fitWidth,
          width: double.infinity,
          placeholder: (_, __) => Container(
            height: 400,
            color: const Color(0xFF111111),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
                color: AppTheme.primaryRed, strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 200,
            color: const Color(0xFF111111),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: AppTheme.textMuted),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.seriesPost.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                  Text(
                    _currentIssue.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navButton(
                icon: Icons.arrow_forward_ios,
                label: 'التالي',
                enabled: _hasNext,
                onTap: () => _goTo(_currentIndex + 1),
              ),
              Text(
                '${_currentIndex + 1} / ${widget.allIssues.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              _navButton(
                icon: Icons.arrow_back_ios,
                label: 'السابق',
                enabled: _hasPrev,
                onTap: () => _goTo(_currentIndex - 1),
                iconFirst: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool iconFirst = true,
  }) {
    final children = [
      Icon(icon, size: 16, color: enabled ? Colors.white : Colors.white30),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              color: enabled ? Colors.white : Colors.white30, fontSize: 13)),
    ];
    return TextButton(
      onPressed: enabled ? onTap : null,
      child: Row(
        children: iconFirst ? children : children.reversed.toList(),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
