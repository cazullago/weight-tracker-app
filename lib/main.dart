import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weight_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeightTrackerApp());
}

const Color kRed = Color(0xFFE60000);
const Color kDeepRed = Color(0xFFB80000);
const Color kBrightRed = Color(0xFFFF1A1A);

class WeightTrackerApp extends StatelessWidget {
  const WeightTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        useMaterial3: true,
      ),
      home: const WeightTrackerPage(),
    );
  }
}

class WeightTrackerPage extends StatefulWidget {
  const WeightTrackerPage({super.key});

  @override
  State<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends State<WeightTrackerPage> {
  static const String _prefsKey = 'weight_entries_v1';

  Map<DateTime, double> _entries = {};
  DateTime _selected = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loaded = false;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final Map<DateTime, double> loaded = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          final value = (e.value as num).toDouble();
          loaded[parseDateKey(e.key)] = value;
        }
      } catch (_) {
        // Corrupt saved data: start fresh rather than crash.
      }
    }
    if (!mounted) return;
    setState(() {
      _entries = loaded;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, double>{
      for (final e in _entries.entries) dateKey(e.key): e.value,
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selected = _day(now);
      _month = DateTime(now.year, now.month, 1);
    });
  }

  Future<void> _openEntryDialog(DateTime day) async {
    final now = _day(DateTime.now());
    if (day.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That's a future day — its fight hasn't started yet! 🔥")),
      );
      return;
    }
    final existing = _entries[day];
    final controller = TextEditingController(
      text: existing == null ? '' : formatWeight(existing),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '💥 ${_monthNames[day.month - 1]} ${day.day}, ${day.year}',
          style: const TextStyle(color: kRed, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Weight',
            suffixText: 'lbs',
            hintText: 'e.g. 185.5',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: kRed, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          onSubmitted: (_) => Navigator.of(context).pop('save'),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Text('Delete', style: TextStyle(color: Colors.grey)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('SAVE IT! 🔥'),
          ),
        ],
      ),
    );
    if (result == null || result == 'cancel') return;
    if (result == 'delete') {
      setState(() => _entries.remove(day));
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted. Fresh start! 💪')),
        );
      }
      return;
    }
    final value = parseWeight(controller.text);
    if (value == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a weight between 30 and 1000 lbs.')),
        );
      }
      return;
    }
    setState(() {
      _entries[day] = value;
      _selected = day;
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kRed,
          content: Text(
            'BOOM! 💥 ${formatWeight(value)} lbs logged for ${_monthNames[day.month - 1]} ${day.day}! KEEP GOING!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  String _selectedMessage() {
    final weight = _entries[_day(_selected)];
    if (weight == null) return "NO WEIGHT YET — LET'S FIX THAT TODAY! 💪";
    final change = changeVsPrevious(_entries, _day(_selected));
    if (change == null) return 'FIRST ENTRY LOGGED! THE JOURNEY STARTS NOW! 🚀';
    if (change < 0) return 'DOWN ${formatWeight(change.abs())} lbs! UNSTOPPABLE! 🔥';
    if (change > 0) {
      return 'UP ${formatWeight(change)} lbs — DATA IS POWER, KEEP TRACKING! 💪';
    }
    return 'STEADY! CONSISTENCY WINS! 🏆';
  }

  @override
  Widget build(BuildContext context) {
    final now = _day(DateTime.now());
    final sorted = _entries.keys.toList()..sort();
    final latest = sorted.isEmpty ? null : _entries[sorted.last];
    double? sinceFirst;
    if (sorted.length >= 2) {
      sinceFirst = _entries[sorted.last]! - _entries[sorted.first]!;
    }
    final thisMonthCount = _entries.keys
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      final day = DateTime(_month.year, _month.month, dayNum);
      final isToday = day == now;
      final isSelected = day == _day(_selected);
      final isFuture = day.isAfter(now);
      final weight = _entries[day];
      final change = weight == null ? null : changeVsPrevious(_entries, day);
      cells.add(
        GestureDetector(
          onTap: () {
            setState(() => _selected = day);
            _openEntryDialog(day);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFE5E5)
                  : (weight != null ? Colors.white : const Color(0xFFFAFAFA)),
              border: Border.all(
                color: isToday
                    ? kRed
                    : (isSelected ? kRed : const Color(0xFFE0E0E0)),
                width: isToday || isSelected ? 2.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFuture ? Colors.grey : Colors.black54,
                  ),
                ),
                if (weight != null) ...[
                  Text(
                    formatWeight(weight),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kRed,
                    ),
                  ),
                  const Text('lbs',
                      style: TextStyle(fontSize: 9, color: Colors.black54)),
                  if (change != null && change != 0)
                    Text(
                      formatChange(change),
                      style: const TextStyle(fontSize: 9, color: Colors.black45),
                    ),
                ] else if (isFuture)
                  const Text('·', style: TextStyle(color: Colors.grey))
                else
                  const Text('+',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCCCCCC))),
              ],
            ),
          ),
        ),
      );
    }

    final recent = sorted.reversed.take(8).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBrightRed, kRed, kDeepRed],
          ),
        ),
        child: SafeArea(
          child: !_loaded
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "🔥 LET'S GO! 🔥",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        'EVERY DAY COUNTS. EVERY POUND COUNTS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _statCard('LATEST',
                              latest == null ? '—' : '${formatWeight(latest)} lbs')),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('DAYS LOGGED', '${sorted.length}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _statCard(
                              'CHANGE SINCE FIRST',
                              sinceFirst == null ? '—' : formatChange(sinceFirst))),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard(
                              'THIS MONTH', '$thisMonthCount days')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => _changeMonth(-1),
                                  icon: const Icon(Icons.chevron_left,
                                      color: kRed, size: 32),
                                ),
                                Expanded(
                                  child: Text(
                                    '${_monthNames[_month.month - 1]} ${_month.year}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: kRed,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeMonth(1),
                                  icon: const Icon(Icons.chevron_right,
                                      color: kRed, size: 32),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _goToday,
                              child: const Text('Back to today',
                                  style: TextStyle(
                                      color: kRed, fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              children: _weekdays
                                  .map((d) => Expanded(
                                        child: Text(d,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black54)),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 0.78,
                              children: cells,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap any day to type your weight in lbs!',
                              style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_monthNames[_selected.month - 1]} ${_selected.day}, ${_selected.year}',
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: kRed),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _entries[_day(_selected)] == null
                                  ? 'No weight logged yet.'
                                  : '${formatWeight(_entries[_day(_selected)]!)} lbs logged 💪',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedMessage(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: kRed),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: kRed,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14)),
                                onPressed: () => _openEntryDialog(_day(_selected)),
                                child: Text(
                                  _entries[_day(_selected)] == null
                                      ? 'LOG THIS DAY! 🔥'
                                      : 'EDIT THIS WEIGHT',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kRed,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            _goToday();
                            _openEntryDialog(now);
                          },
                          child: const Text(
                            "⚡ LOG TODAY'S WEIGHT!",
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                        ),
                      ),
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          '🏆 RECENT WINS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        ...recent.map((d) {
                          final w = _entries[d]!;
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '${_monthNames[d.month - 1]} ${d.day}, ${d.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(
                                '${formatWeight(w)} lbs',
                                style: const TextStyle(
                                    color: kRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17),
                              ),
                              onTap: () {
                                setState(() {
                                  _selected = d;
                                  _month = DateTime(d.year, d.month, 1);
                                });
                                _openEntryDialog(d);
                              },
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Your weights stay on your phone. No account, no cloud. Just you vs. yesterday. 🔥',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: kRed)),
        ],
      ),
    );
  }
}
