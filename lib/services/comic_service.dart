import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comic_post.dart';

/// خدمة جلب البيانات من Comicverse (مدوّن Blogger) عبر Posts JSON Feed API الرسمي:
///   /feeds/posts/default/-/{label}?alt=json   → محتوى كامل (يحوي صور القراءة)
///   /feeds/posts/summary/-/{label}?alt=json   → ملخص فقط (content.$t فارغ تمامًا!)
///
/// ملاحظتان مهمتان اكتُشِفتا بالتجربة الفعلية على هذا الموقع:
///
/// 1) الأعداد التابعة لكل عمل لا ترتبط بعنوان العمل نفسه كوسم (label)،
///    بل بقيمة منفصلة data-label مخزَّنة يدويًا داخل HTML صفحة العمل
///    (مثال: عمل "Moon Knight (2021)" يحمل data-label="MoonKnight").
///    لذلك نحتاج لجلب HTML الخام لصفحة العمل أولًا (fetchSeriesDataLabel)
///    قبل التمكن من جلب أعداده بشكل صحيح عبر fetchByLabel/fetchByLabelSummary.
///
/// 2) endpoint "summary" يُرجع content.$t فارغًا تمامًا (0 حرف) — لا يحوي
///    أي صور قراءة على الإطلاق، فقط عنوان وصورة مصغّرة. لجلب صور القراءة
///    الفعلية يجب استخدام endpoint "default" الذي يُرجع المحتوى الكامل.
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

  /// يجلب كل منشورات تصنيف معيّن (عمل واحد، أو ناشر، أو أي وسم) مع المحتوى
  /// الكامل (content.$t). يستخدم "default" وليس "summary" لأن "summary"
  /// يُرجع content.$t فارغًا تمامًا (0 حرف) — لا يحوي صور القراءة على
  /// الإطلاق. استخدم هذه الدالة فقط عندما تحتاج صور القراءة الفعلية
  /// (قارئ العدد)، لأنها أثقل بكثير من fetchByLabelSummary.
  Future<List<ComicPost>> fetchByLabel(String label,
      {int maxResults = 100}) async {
    final uri = Uri.parse(
        '$baseUrl/feeds/posts/default/-/${Uri.encodeComponent(label)}'
        '?alt=json&max-results=$maxResults');
    final data = await _fetchJson(uri);
    return _parseEntries(data);
  }

  /// نسخة خفيفة من fetchByLabel تستخدم "summary" (عنوان + صورة مصغّرة فقط
  /// بدون محتوى كامل). تُستخدم لعرض قوائم الأعداد/الأعمال في الواجهة حيث
  /// لا حاجة لصور القراءة الكاملة، لتقليل استهلاك البيانات والوقت.
  Future<List<ComicPost>> fetchByLabelSummary(String label,
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

  /// يجلب صفحة العمل HTML الخام ويستخرج منها الوسم (label) الحقيقي
  /// المستخدم لربط الأعداد بهذا العمل. هذا الموقع لا يربط الأعداد بعنوان
  /// العمل نفسه، بل بقيمة منفصلة مخزَّنة يدويًا في خاصية data-label على
  /// عنصر HTML باسم <div class="manga-widget" data-label="..."></div>
  /// والتي قد تختلف كليًا عن العنوان المعروض (مثل "MoonKnight" بدل
  /// "Moon Knight (2021)"). نحاكي هنا تمامًا ما يفعله جافاسكريبت الموقع.
  Future<String?> fetchSeriesDataLabel(String seriesPageUrl) async {
    final response = await _client.get(Uri.parse(seriesPageUrl));
    if (response.statusCode != 200) {
      throw ComicServiceException('فشل تحميل صفحة العمل (كود ${response.statusCode})');
    }
    final body = response.body;

    // نبحث أولًا عن أي عنصر يحوي class="manga-widget" ضمن حدود معقولة
    // من النص، ثم نستخرج data-label من نفس العنصر بغض النظر عن ترتيب
    // الخصائص بداخله (قد تأتي قبل أو بعد class، بفواصل أو بدونها).
    final widgetMatch =
        RegExp(r'''<div[^>]*class=["']manga-widget["'][^>]*>''')
            .firstMatch(body);
    if (widgetMatch != null) {
      final tag = widgetMatch.group(0)!;
      final labelMatch =
          RegExp(r'''data-label=["']([^"']+)["']''').firstMatch(tag);
      if (labelMatch != null) return labelMatch.group(1);
    }

    // خطة بديلة: البحث عن data-label في أي عنصر div قريب من "manga-widget"
    // (تحوطًا لو اختلف ترتيب الخصائص عن النمط أعلاه بشكل غير متوقع).
    final anyMatch = RegExp(
            r'''manga-widget["'\s][^>]*?data-label=["']([^"']+)["']|data-label=["']([^"']+)["'][^>]*?manga-widget''')
        .firstMatch(body);
    if (anyMatch != null) {
      return anyMatch.group(1) ?? anyMatch.group(2);
    }
    return null;
  }

  /// يجلب منشور عدد واحد بعنوانه الدقيق ضمن تصنيف عمل معيّن، مع محتواه
  /// الكامل (لاستخراج صور القراءة). بدل تحميل كل أعداد العمل (قد تكون
  /// مئات الآلاف من الأحرف لعمل طويل) لمجرد عرض عدد واحد، نضيّق النتيجة
  /// بدمج تصنيف العمل مع نص عنوان العدد عبر معامل البحث q المدمج في Blogger.
  Future<ComicPost?> fetchSingleIssueByTitle(
      String seriesLabel, String issueTitle) async {
    final uri = Uri.parse('$baseUrl/feeds/posts/default/-/'
        '${Uri.encodeComponent(seriesLabel)}'
        '?alt=json&max-results=5&q=${Uri.encodeComponent(issueTitle)}');
    final data = await _fetchJson(uri);
    final entries = _parseEntries(data);
    for (final p in entries) {
      if (p.title == issueTitle) return p;
    }
    return entries.isNotEmpty ? entries.first : null;
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
