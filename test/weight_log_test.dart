import 'package:flutter_test/flutter_test.dart';
import 'package:weight_tracker/weight_log.dart';

void main() {
  test('dateKey formats with zero padding', () {
    expect(dateKey(DateTime(2026, 11, 2)), '2026-11-02');
  });

  test('parseWeight accepts decimals and commas, rejects junk', () {
    expect(parseWeight('185.5'), 185.5);
    expect(parseWeight('185,5'), 185.5);
    expect(parseWeight('180'), 180.0);
    expect(parseWeight(''), isNull);
    expect(parseWeight('abc'), isNull);
    expect(parseWeight('10'), isNull);
    expect(parseWeight('5000'), isNull);
  });

  test('formatWeight drops trailing .0', () {
    expect(formatWeight(180.0), '180');
    expect(formatWeight(185.5), '185.5');
  });

  test('changeVsPrevious compares to last logged day, not calendar neighbour', () {
    final entries = {
      DateTime(2026, 11, 1): 190.0,
      DateTime(2026, 11, 3): 187.5,
    };
    expect(changeVsPrevious(entries, DateTime(2026, 11, 3)), -2.5);
    expect(changeVsPrevious(entries, DateTime(2026, 11, 1)), isNull);
    expect(formatChange(-2.5), '−2.5');
    expect(formatChange(1.0), '+1');
  });
}
