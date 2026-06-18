import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comic_post.dart';

/// خدمة جلب البيانات من Comicverse (مدوّن Blogger) عبر Posts JSON Feed API الرسمي.
///
/// لا حاجة لتحليل HTML؛ Blogger يوفر واجهة JSON عامة وموثوقة:
///   /feeds/posts/default?alt=json
///   /feeds/posts/summary/-/{label}?alt=json
class ComicService {
  static const String baseUrl = 'https://arcomixverse.blogspot.com';

  /// التصنيفات الرئيسية الظاهرة في الصفحة الرئيسية للموقع (الناشرون/الأكوان)
  static const List<String> mainCategories = [
    'MARVEL',
    'DC',
    'IMAGE',
    'BOOM',
    'CROSSOVER',
    'GHOSTMACHINE',
    'ULTIMATE',
    'ABSOLUTE',
  ];

  /// خريطة لعرض اسم عربي مفهوم لكل تصنيف رئيسي
  static const Map<String, String> categoryDisplayNames = {
    'MARVEL': 'مارفل',
    'DC': 'دي سي',
    'IMAGE': 'إيميج',
    'BOOM': 'بووم',
    'CROSSOVER': 'كروس أوفر',
    'GHOSTMACHINE': 'غوست ماشين',
    'ULTIMATE': 'ألتيميت (مارفل)',
    'ABSOLUTE': 'المطلق (دي سي)',
  };

  final http.Client _client;
  ComicService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
    });
    if (response.statusCode != 200) {
      throw ComicServiceException(
          'فشل الاتصال بالموقع (كود ${response.statusCode})');
    }
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ComicServiceException('تعذر قراءة بيانات الموقع');
    }
  }

  List<ComicPost> _parseEntries(Map<String, dynamic> data) {
    final feed = data['feed'] as Map<String, dynamic>?;
    if (feed == null) return [];
    final entries = feed['entry'] as List<dynamic>?;
    if (entries == null) return [];
    return entries
        .map((e) => ComicPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// يجلب كل منشورات تصنيف معيّن (عمل واحد، أو ناشر، أو أي وسم).
  /// عند جلب تصنيف اسم عمل معيّن، ستُعاد كل أعداد ذلك العمل + منشور العمل نفسه
  /// لأنهم يتشاركون نفس الوسم في هذا الموقع.
  Future<List<ComicPost>> fetchByLabel(String label,
      {int maxResults = 100}) async {
    final uri = Uri.parse(
        '$baseUrl/feeds/posts/summary/-/${Uri.encodeComponent(label)}'
        '?alt=json&max-results=$maxResults');
    final data = await _fetchJson(uri);
    return _parseEntries(data);
  }

  /// يبحث في كل محتوى الموقع (العناوين والنصوص) عبر معامل البحث q
  /// المدمج في Blogger، والذي يعمل على الخادم بلا حاجة لتحميل كل المنشورات.
  Future<List<ComicPost>> searchPosts(String query, {int maxResults = 40}) async {
    final uri = Uri.parse('$baseUrl/feeds/posts/default'
        '?alt=json&max-results=$maxResults&q=${Uri.encodeComponent(query)}');
    final data = await _fetchJson(uri);
    return _parseEntries(data);
  }

  /// يجلب كل المنشورات في الموقع (تستخدم لشاشة "كل الأعمال" والبحث)
  Future<List<ComicPost>> fetchAllPosts({int maxResults = 150}) async {
    final uri = Uri.parse(
        '$baseUrl/feeds/posts/default?alt=json&max-results=$maxResults');
    final data = await _fetchJson(uri);
    return _parseEntries(data);
  }

  /// يجلب صفحة تالية بالاعتماد على start-index (لدعم Pagination عند الحاجة)
  Future<List<ComicPost>> fetchAllPostsPaged({
    int startIndex = 1,
    int maxResults = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/feeds/posts/default'
        '?alt=json&max-results=$maxResults&start-index=$startIndex');
    final data = await _fetchJson(uri);
    return _parseEntries(data);
  }

  /// يحاول تمييز "منشورات الأعمال" (Series) عن "منشورات الأعداد" (Issues)
  /// بالاعتماد على وجود وسم "Chapter" أو رقم في العنوان يبدأ بـ "العدد".
  static bool isIssuePost(ComicPost post) {
    final hasChapterLabel = post.labels
        .any((l) => l.toLowerCase().trim() == 'chap' || l.toLowerCase().trim() == 'chapter');
    final titleLooksLikeIssue = RegExp(r'العدد\s*#?\d+').hasMatch(post.title) ||
        RegExp(r'^\d+$').hasMatch(post.title.trim());
    return hasChapterLabel || titleLooksLikeIssue;
  }

  /// من قائمة منشورات نفس الوسم (label)، يفصل منشور "العمل" الأساسي عن أعداده.
  /// منشور العمل عادة هو الأقدم تاريخ نشر ولا يحمل صيغة "العدد#" في عنوانه،
  /// أو الذي يحوي أكبر قدر من تفاصيل وصفية (نأخذ أبسط معيار: العنوان لا يطابق نمط عدد).
  static ({ComicPost? series, List<ComicPost> issues}) splitSeriesAndIssues(
      List<ComicPost> posts) {
    ComicPost? series;
    final issues = <ComicPost>[];
    for (final p in posts) {
      if (isIssuePost(p)) {
        issues.add(p);
      } else {
        // أول منشور غير مصنف كعدد نعتبره صفحة العمل؛ إن وُجد أكثر من واحد
        // نأخذ الأقدم لأنه الأصل عادة.
        if (series == null || p.published.isBefore(series.published)) {
          series = p;
        }
      }
    }
    // ترتيب الأعداد تصاعديًا حسب رقم العدد إن توفر، وإلا حسب تاريخ النشر
    issues.sort((a, b) {
      final an = a.issueNumber;
      final bn = b.issueNumber;
      if (an != null && bn != null) return an.compareTo(bn);
      return a.published.compareTo(b.published);
    });
    return (series: series, issues: issues);
  }

  void dispose() {
    _client.close();
  }
}

class ComicServiceException implements Exception {
  final String message;
  ComicServiceException(this.message);
  @override
  String toString() => message;
}
