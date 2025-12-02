import 'package:flutter_test/flutter_test.dart';
import 'package:navmate/core/data/landmarks.dart';
import 'package:navmate/core/destination/landmark_matcher.dart';

void main() {
  const matcher = LandmarkMatcher();
  final store = LandmarkStore([
    const Landmark(
      id: 'lib',
      name: 'Main Library',
      type: 'Library',
      lat: 0,
      lng: 0,
    ),
    const Landmark(
      id: 'caf',
      name: 'Blue Cafe',
      type: 'Cafeteria',
      lat: 0,
      lng: 0,
    ),
    const Landmark(
      id: 'lab',
      name: 'Engineering Innovation Lab',
      type: 'Laboratory',
      lat: 0,
      lng: 0,
    ),
  ]);

  test('returns null when query is empty', () {
    expect(matcher.bestMatch(query: '   ', store: store), isNull);
  });

  test('prefers exact name match over partial matches', () {
    final result = matcher.bestMatch(query: 'Main Library', store: store);
    expect(result?.id, 'lib');
  });

  test('matches based on fuzzy token overlap', () {
    final result = matcher.bestMatch(query: 'innovation lab', store: store);
    expect(result?.id, 'lab');
  });

  test('falls back to type matches when name is absent', () {
    final result = matcher.bestMatch(query: 'cafeteria', store: store);
    expect(result?.id, 'caf');
  });
}
