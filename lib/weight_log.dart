// Pure weight-log helpers, kept separate from widgets so they are
// unit-testable without a device or Flutter test harness quirks.

/// Key used to store one day's weight, e.g. 2026-11-02.
String dateKey(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final m = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$dd';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Parse what the user typed. Accepts "180", "180.5", "180,5".
/// Returns null for empty / non-numeric / out-of-range input.
double? parseWeight(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null) return null;
  if (value < 30 || value > 1000) return null;
  return value;
}

String formatWeight(double value) {
  // Show 180 not 180.0, but keep one decimal when it matters.
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

/// The most recent logged entry strictly before [day], or null.
MapEntry<DateTime, double>? previousEntry(
    Map<DateTime, double> entries, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  MapEntry<DateTime, double>? best;
  for (final e in entries.entries) {
    if (e.key.isBefore(target)) {
      if (best == null || e.key.isAfter(best.key)) best = e;
    }
  }
  return best;
}

/// Change vs the previous logged entry: null when there is none.
double? changeVsPrevious(Map<DateTime, double> entries, DateTime day) {
  final weight = entries[DateTime(day.year, day.month, day.day)];
  if (weight == null) return null;
  final prev = previousEntry(entries, day);
  if (prev == null) return null;
  return weight - prev.value;
}

String formatChange(double change) {
  final sign = change > 0 ? '+' : (change < 0 ? '\u2212' : '');
  return '$sign${formatWeight(change.abs())}';
}
