import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic_post.dart';
import '../services/comic_service.dart';
import '../services/favorites_service.dart';
import '../theme.dart';
import 'issue_reader_screen.dart';

/// شاشة تفاصيل عمل (Series): الغلاف، الوصف، التصنيفات، وقائمة الأعداد.
/// تجلب أعداد العمل عبر نفس وسم (label) اسم العمل، لأن هذا الموقع
/// يربط بين منشور العمل وكل أعداده بمشاركتهم نفس التصنيف.
class ComicDetailScreen extends StatefulWidget {
  final ComicPost seriesPost;
  const ComicDetailScreen({super.key, required this.seriesPost});

  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  final ComicService _service = ComicService();
  final FavoritesService _favService = FavoritesService();

  List<ComicPost> _issues = [];
  bool _loading = true;
  bool _isFavorite = false;
  String? _error;
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _loadIssues();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final fav = await _favService.isFavorite(widget.seriesPost.link);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _loadIssues() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // اسم العمل نفسه هو الوسم (label) الذي يربط كل الأعداد به في هذا الموقع
      final seriesLabel = widget.seriesPost.title;
      final posts =
          await _service.fetchByLabel(seriesLabel, maxResults: 200);
      final split = ComicService.splitSeriesAndIssues(posts);
      setState(() => _issues = split.issues);
    } catch (e) {
      setState(() => _error = 'تعذر تحميل قائمة الأعداد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    await _favService.toggleFavorite(widget.seriesPost.link);
    await _loadFavoriteState();
  }

  void _openIssue(ComicPost issue, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueReaderScreen(
          issue: issue,
          allIssues: _issues,
          currentIndex: index,
          seriesPost: widget.seriesPost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comic = widget.seriesPost;
    final displayIssues =
        _sortDescending ? _issues.reversed.toList() : _issues;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppTheme.primaryRed : null,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (comic.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: ComicPost.fullResImage(comic.thumbnailUrl!),
                      fit: BoxFit.cover,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.background.withOpacity(0.9),
                          AppTheme.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoChips(comic),
                  const SizedBox(height: 14),
                  if (comic.plainDescription.isNotEmpty)
                    Text(
                      comic.plainDescription,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الأعداد${_issues.isNotEmpty ? " (${_issues.length})" : ""}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_issues.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _sortDescending
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 20,
                          ),
                          tooltip: _sortDescending
                              ? 'الأحدث أولاً'
                              : 'الأقدم أولاً',
                          onPressed: () => setState(
                              () => _sortDescending = !_sortDescending),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryRed)),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _loadIssues,
                        child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            )
          else if (_issues.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا توجد أعداد متاحة حاليًا',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final issue = displayIssues[i];
                  final realIndex =
                      _sortDescending ? _issues.length - 1 - i : i;
                  return _IssueListTile(
                    issue: issue,
                    onTap: () => _openIssue(issue, realIndex),
                  );
                },
                childCount: displayIssues.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildInfoChips(ComicPost comic) {
    final chips = <Widget>[];
    if (comic.statusLabel != null) {
      chips.add(_chip(comic.statusLabel!,
          color: comic.isOngoing ? Colors.orange : Colors.green));
    }
    for (final genre in comic.genreLabels) {
      chips.add(_chip(genre));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryRed).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (color ?? AppTheme.primaryRed).withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppTheme.primaryRed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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

class _IssueListTile extends StatelessWidget {
  final ComicPost issue;
  final VoidCallback onTap;

  const _IssueListTile({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 46,
          height: 64,
          child: issue.thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: issue.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: AppTheme.surfaceVariant),
                )
              : Container(color: AppTheme.surfaceVariant),
        ),
      ),
      title: Text(
        issue.title,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${issue.published.year}/${issue.published.month.toString().padLeft(2, '0')}/${issue.published.day.toString().padLeft(2, '0')}',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left, color: AppTheme.textMuted),
    );
  }
}
