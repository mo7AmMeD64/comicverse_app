import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../theme.dart';

/// وضع القراءة: أفقي (صفحة-بصفحة مع تكبير/تصغير) أو عمودي (تمرير متواصل،
/// أسلوب الويب-تون الشائع في قراءة المانجا/الكوميكس على الموبايل).
enum ReaderMode { horizontal, vertical }

/// شاشة قراءة عدد واحد. تدعم وضعين قابلين للتبديل (أفقي/عمودي)، وتحمّل
/// صور الفصل مسبقًا في الخلفية بدل انتظار وصول المستخدم لكل صورة، بحيث لا
/// يشعر بتأخير أثناء التمرير/التنقل.
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
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  late ComicPost _currentIssue;
  late int _currentIndex;
  List<String> _images = [];
  int _currentPage = 0;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  ReaderMode _mode = ReaderMode.vertical;

  // عدد الصور المُحمَّلة مسبقًا حول موضع القراءة الحالي في كل اتجاه.
  // تحميل صورتين مقدمًا (وليس فقط الصورة التالية مباشرة) يضمن عدم شعور
  // المستخدم بأي تأخير حتى عند التمرير السريع.
  static const int _preloadRadius = 2;
  final Set<int> _precached = {};

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
      _currentPage = 0;
      _precached.clear();
    });
    try {
      // نجلب العدد المطلوب بعنوانه الدقيق فقط (مع تضييق البحث ضمن تصنيف
      // العمل عبر seriesLabel)، بدل تحميل كل أعداد العمل دفعة واحدة.
      var full = await _service.fetchSingleIssueByTitle(
          widget.seriesLabel, _currentIssue.title);

      // إن فشلت المطابقة الدقيقة عبر البحث المضيّق (نادر، قد يحدث مع
      // عناوين تحوي رموزًا خاصة)، نقع على خطة بديلة أبطأ لكنها أكيدة:
      // جلب كل أعداد العمل بمحتواها الكامل والبحث فيها عن التطابق الدقيق.
      // هذا أفضل من عرض عدد خاطئ من عمل مختلف تمامًا للمستخدم.
      if (full == null) {
        final allFull =
            await _service.fetchByLabel(widget.seriesLabel, maxResults: 500);
        for (final p in allFull) {
          if (p.title == _currentIssue.title) {
            full = p;
            break;
          }
        }
      }
      full ??= _currentIssue;
      final imgs = full.extractAllImages();
      if (!mounted) return;
      setState(() => _images = imgs);
      WidgetsBinding.instance.addPostFrameCallback((_) => _preloadAround(0));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل صفحات هذا العدد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// يحمّل مسبقًا صور الصفحات المجاورة لموضع القراءة الحالي (قبل وبعد) إلى
  /// ذاكرة Flutter للصور، بحيث تكون جاهزة فورًا عند وصول المستخدم إليها
  /// بدل الانتظار حتى يظهر العنصر فعليًا على الشاشة.
  void _preloadAround(int centerIndex) {
    if (!mounted) return;
    final start = (centerIndex - _preloadRadius).clamp(0, _images.length);
    final end = (centerIndex + _preloadRadius).clamp(0, _images.length - 1);
    for (var i = start; i <= end; i++) {
      if (_precached.contains(i) || i >= _images.length) continue;
      _precached.add(i);
      precacheImage(CachedNetworkImageProvider(_images[i]), context);
    }
  }

  void _goToIssue(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.allIssues.length) return;
    setState(() {
      _currentIndex = newIndex;
      _currentIssue = widget.allIssues[newIndex];
    });
    _loadIssueImages();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == ReaderMode.vertical
          ? ReaderMode.horizontal
          : ReaderMode.vertical;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (_showControls) _buildTopBar(),
            Expanded(child: _buildBody()),
            if (_showControls && _images.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_currentPage + 1} / ${_images.length}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          IconButton(
            icon: Icon(
              _mode == ReaderMode.vertical
                  ? Icons.swap_vert
                  : Icons.swap_horiz,
              color: Colors.white,
            ),
            tooltip: _mode == ReaderMode.vertical
                ? 'التبديل لوضع التمرير الأفقي'
                : 'التبديل لوضع التمرير العمودي',
            onPressed: _images.isEmpty ? null : _toggleMode,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _hasNext ? () => _goToIssue(_currentIndex + 1) : null,
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              label: const Text('العدد التالي',
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton.icon(
              onPressed: _hasPrev ? () => _goToIssue(_currentIndex - 1) : null,
              icon: const Icon(Icons.skip_next, color: Colors.white),
              label: const Text('العدد السابق',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
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
    return _mode == ReaderMode.vertical ? _buildVerticalReader() : _buildHorizontalReader();
  }

  Widget _buildHorizontalReader() {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: _images.length,
        reverse: true, // اتجاه القراءة من اليمين لليسار (RTL)
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          _preloadAround(index);
        },
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(_images[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: _images[index]),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
            ),
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }

  Widget _buildVerticalReader() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        // نقدّر أي صفحة في منتصف الشاشة تقريبًا بناءً على نسبة التمرير،
        // لتحديث رقم الصفحة المعروض وتحميل ما حولها مسبقًا أولًا بأول.
        final metrics = notification.metrics;
        if (metrics.maxScrollExtent > 0) {
          final ratio = (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
          final estimatedIndex = (ratio * (_images.length - 1)).round();
          if (estimatedIndex != _currentPage) {
            setState(() => _currentPage = estimatedIndex);
            _preloadAround(estimatedIndex);
          }
        }
        return false;
      },
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: ListView.builder(
          controller: _scrollController,
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
                child:
                    const Icon(Icons.broken_image, color: Colors.white38, size: 48),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }
}
