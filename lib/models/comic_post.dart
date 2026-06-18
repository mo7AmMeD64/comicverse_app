import 'package:html_unescape/html_unescape.dart';

final _unescape = HtmlUnescape();

/// يمثل منشور Blogger واحد (قد يكون "عمل" Series أو "عدد" Issue)
class ComicPost {
  final String id;
  final String title;
  final String link;
  final String? thumbnailUrl;
  final String contentHtml;
  final List<String> labels;
  final DateTime published;
  final DateTime updated;

  ComicPost({
    required this.id,
    required this.title,
    required this.link,
    required this.thumbnailUrl,
    required this.contentHtml,
    required this.labels,
    required this.published,
    required this.updated,
  });

  factory ComicPost.fromJson(Map<String, dynamic> entry) {
    final id = (entry['id']?['\$t'] ?? '').toString();
    final rawTitle = (entry['title']?['\$t'] ?? 'بدون عنوان').toString();
    final title = _unescape.convert(rawTitle).trim();

    String link = '#';
    final links = entry['link'] as List<dynamic>?;
    if (links != null) {
      for (final l in links) {
        if (l['rel'] == 'alternate') {
          link = l['href'] ?? '#';
          break;
        }
      }
    }

    String? thumb;
    if (entry['media\$thumbnail'] != null) {
      thumb = entry['media\$thumbnail']['url'] as String?;
      if (thumb != null) {
        thumb = _upgradeImageUrl(thumb);
      }
    }

    final contentHtml = (entry['content']?['\$t'] ??
            entry['summary']?['\$t'] ??
            '')
        .toString();

    if (thumb == null) {
      final imgTagMatch = RegExp(r'<img[^>]*>').firstMatch(contentHtml);
      if (imgTagMatch != null) {
        final tag = imgTagMatch.group(0)!;
        final src = _extractAttr(tag, 'data-src') ?? _extractAttr(tag, 'src');
        if (src != null && src.isNotEmpty && !src.startsWith('data:')) {
          thumb = _upgradeImageUrl(src);
        }
      }
    }

    final labels = <String>[];
    final cats = entry['category'] as List<dynamic>?;
    if (cats != null) {
      for (final c in cats) {
        final term = (c['term'] ?? '').toString().trim();
        if (term.isNotEmpty) labels.add(term);
      }
    }

    DateTime published = DateTime.now();
    final pubStr = entry['published']?['\$t'] as String?;
    if (pubStr != null) {
      published = DateTime.tryParse(pubStr) ?? DateTime.now();
    }

    DateTime updated = published;
    final updStr = entry['updated']?['\$t'] as String?;
    if (updStr != null) {
      updated = DateTime.tryParse(updStr) ?? published;
    }

    return ComicPost(
      id: id,
      title: title,
      link: link,
      thumbnailUrl: thumb,
      contentHtml: contentHtml,
      labels: labels,
      published: published,
      updated: updated,
    );
  }

  /// يرفع جودة الصورة المصغرة القادمة من Blogger (s72-c) إلى دقة أعلى
  static String _upgradeImageUrl(String url) {
    return url
        .replaceAll(RegExp(r'/s\d+(-c)?/'), '/w600-h900-p-k-no-nu/')
        .replaceAll(RegExp(r'=s\d+(-c)?'), '=w600-h900-p-k-no-nu');
  }

  /// يحول رابط الصورة لدقة أصلية كاملة (يستخدم في القارئ)
  static String fullResImage(String url) {
    return url
        .replaceAll(RegExp(r'/s\d+(-c)?/'), '/s1600/')
        .replaceAll(RegExp(r'=s\d+(-c)?'), '=s1600');
  }

  /// يستخرج كل روابط الصور من محتوى HTML بترتيبها (تستخدم لصفحات قراءة العدد).
  /// الموقع يستخدم نظام Lazy-load حيث يخزَّن الرابط الحقيقي للصورة في
  /// data-src وليس src مباشرة (يُملأ src فقط عند ظهور الصورة على الشاشة
  /// في المتصفح)، لذلك نتحقق من data-src أولاً قبل src كحل بديل.
  List<String> extractAllImages() {
    final imgTagMatches = RegExp(r'<img[^>]*>').allMatches(contentHtml);
    final urls = <String>[];
    for (final tagMatch in imgTagMatches) {
      final tag = tagMatch.group(0)!;
      String? src = _extractAttr(tag, 'data-src') ?? _extractAttr(tag, 'src');
      if (src == null || src.isEmpty) continue;
      if (src.startsWith('data:')) continue;
      if (src.contains('no-image') || src.contains('placeholder')) continue;
      urls.add(fullResImage(src));
    }
    return urls;
  }

  static String? _extractAttr(String tag, String attr) {
    final match =
        RegExp('$attr=["\']([^"\']+)["\']').firstMatch(tag);
    return match?.group(1);
  }

  /// نص الوصف نظيفًا بدون أي وسوم HTML (للعرض في صفحة التفاصيل)
  String get plainDescription {
    final noTags = contentHtml.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final clean = _unescape.convert(noTags).replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  bool get isOngoing => labels.any((l) => l.trim() == 'مستمر');
  bool get isCompleted => labels.any((l) => l.trim() == 'مكتمل');

  String? get statusLabel {
    if (isOngoing) return 'مستمر';
    if (isCompleted) return 'مكتمل';
    return null;
  }

  /// التصنيفات الخاصة بالنوع (تستثني الحالة ووسوم النظام الداخلية)
  List<String> get genreLabels {
    const excluded = {
      'chap',
      'chapter',
      'end',
      'oneshot',
      'one shot',
      'vol',
      'volume',
      'update',
      'مستمر',
      'مكتمل',
      'marvel',
      'dc',
      'image',
      'boom',
      'crossover',
      'ghostmachine',
      'ultimate',
      'absolute',
    };
    return labels
        .where((l) => !excluded.contains(l.trim().toLowerCase()))
        .toList();
  }

  /// يحاول استخراج رقم العدد من العنوان (مثال: "العدد#144" أو "144")
  int? get issueNumber {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
