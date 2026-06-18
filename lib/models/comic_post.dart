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
      final match = RegExp(r'''<img[^>]+src=["']([^"']+)["']''')
          .firstMatch(contentHtml);
      if (match != null) {
        thumb = _upgradeImageUrl(match.group(1)!);
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

  /// يستخرج كل روابط الصور من محتوى HTML بترتيبها (تستخدم لصفحات قراءة العدد)
  List<String> extractAllImages() {
    final matches =
        RegExp(r'''<img[^>]+src=["']([^"']+)["']''').allMatches(contentHtml);
    final urls = <String>[];
    for (final m in matches) {
      final src = m.group(1);
      if (src == null) continue;
      // تجاهل أيقونات السوشيال ميديا الصغيرة المعروفة
      if (src.contains('no-image') || src.contains('placeholder')) continue;
      urls.add(fullResImage(src));
    }
    return urls;
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
