import 'dart:math' as math;

import '../data/landmarks.dart';

class LandmarkMatcher {
  const LandmarkMatcher();

  Landmark? bestMatch({required String query, required LandmarkStore store}) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;

    final queryTokens = _tokens(normalized);
    Landmark? best;
    double bestScore = -double.infinity;

    for (final landmark in store.items) {
      final score = _score(normalized, queryTokens, landmark);
      if (score > bestScore) {
        bestScore = score;
        best = landmark;
      }
    }
    return bestScore >= 45 ? best : null;
  }

  String _normalize(String value) {
    final lowered = value.toLowerCase();
    final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _tokens(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }

  double _score(
    String normalizedQuery,
    List<String> queryTokens,
    Landmark landmark,
  ) {
    final name = _normalize(landmark.name);
    if (name.isEmpty) return 0;

    double score = 0;
    if (name == normalizedQuery) {
      return 200;
    }
    if (name.contains(normalizedQuery)) {
      score += 90;
    } else if (normalizedQuery.contains(name)) {
      score += 70;
    }

    final nameTokens = _tokens(landmark.name);
    if (nameTokens.isNotEmpty && queryTokens.isNotEmpty) {
      score += _tokenOverlapScore(queryTokens, nameTokens) * 50;
      score += _prefixScore(queryTokens, nameTokens) * 20;
      score += _similarityScore(queryTokens, nameTokens) * 30;
    }

    final type = _normalize(landmark.type);
    if (type.isNotEmpty) {
      if (type.contains(normalizedQuery)) {
        score += 60;
      } else {
        score += _tokenOverlapScore(queryTokens, _tokens(landmark.type)) * 25;
      }
    }

    return score;
  }

  double _tokenOverlapScore(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = a.toSet();
    final setB = b.toSet();
    final overlap = setA.intersection(setB).length;
    return overlap / math.max(setA.length, setB.length);
  }

  double _prefixScore(List<String> queryTokens, List<String> nameTokens) {
    if (queryTokens.isEmpty || nameTokens.isEmpty) return 0;
    var matches = 0;
    for (final token in queryTokens) {
      if (nameTokens.any((t) => t.startsWith(token))) {
        matches += 1;
      }
    }
    return matches / queryTokens.length;
  }

  double _similarityScore(List<String> queryTokens, List<String> nameTokens) {
    if (queryTokens.isEmpty || nameTokens.isEmpty) return 0;
    var best = 0.0;
    for (final q in queryTokens) {
      for (final n in nameTokens) {
        final similarity = _similarity(q, n);
        if (similarity > best) best = similarity;
      }
    }
    return best;
  }

  double _similarity(String a, String b) {
    if (a == b) return 1;
    final distance = _levenshtein(a, b);
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1;
    return 1 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }
}
