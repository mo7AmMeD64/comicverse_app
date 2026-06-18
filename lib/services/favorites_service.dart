import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة بسيطة لحفظ الأعمال المفضلة وآخر عدد تمت قراءته لكل عمل، محليًا على الجهاز.
class FavoritesService {
  static const _favKey = 'favorite_series';
  static const _progressKey = 'reading_progress';

  Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? [];
    return list.toSet();
  }

  Future<bool> isFavorite(String seriesLink) async {
    final favs = await getFavorites();
    return favs.contains(seriesLink);
  }

  Future<void> toggleFavorite(String seriesLink) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = (prefs.getStringList(_favKey) ?? []).toSet();
    if (favs.contains(seriesLink)) {
      favs.remove(seriesLink);
    } else {
      favs.add(seriesLink);
    }
    await prefs.setStringList(_favKey, favs.toList());
  }

  /// يحفظ آخر رابط عدد تمت قراءته ضمن عمل معيّن، مع اسم العمل وصورته للعرض السريع.
  Future<void> saveProgress({
    required String seriesLabel,
    required String seriesTitle,
    required String? seriesImage,
    required String lastIssueLink,
    required String lastIssueTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    final Map<String, dynamic> map = raw != null
        ? Map<String, dynamic>.from(json.decode(raw) as Map)
        : {};
    map[seriesLabel] = {
      'seriesTitle': seriesTitle,
      'seriesImage': seriesImage,
      'lastIssueLink': lastIssueLink,
      'lastIssueTitle': lastIssueTitle,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_progressKey, json.encode(map));
  }

  Future<Map<String, dynamic>> getAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(json.decode(raw) as Map);
  }
}
