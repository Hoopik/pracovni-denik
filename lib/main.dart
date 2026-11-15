import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pracovní deník',
    theme: ThemeData(
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.dark,
    ),
    themeMode: ThemeMode.system,
    home: Diary(prefs: prefs),
  ));
}

class Diary extends StatefulWidget {
  final SharedPreferences prefs;

  const Diary({super.key, required this.prefs});

  @override
  State<Diary> createState() => _DiaryState();
}

class _DiaryState extends State<Diary> {
  DateTime month = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  Map<String, dynamic> records = {};

  static const months = [
    'Leden',
    'Únor',
    'Březen',
    'Duben',
    'Květen',
    'Červen',
    'Červenec',
    'Srpen',
    'Září',
    'Říjen',
    'Listopad',
    'Prosinec',
  ];

  static const weekdays = [
    'Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'
  ];

  @override
  void initState() {
    super.initState();

    try {
      records = Map<String, dynamic>.from(
        jsonDecode(
          widget.prefs.getString('diary') ?? '{}',
        ),
      );
    } catch (_) {
      records = {};
    }
  }

  String get prefix =>
      '${month.year}-${month.month}-';

  int get days =>
      DateTime(month.year, month.month + 1, 0).day;

  String keyFor(int d) => '$prefix$d';

  Map<String, dynamic> entry(int d) {
    return Map<String, dynamic>.from(
      records[keyFor(d)] ?? {},
    );
  }

  double? parse(String s) {
    final value = s.trim().replaceAll(',', '.');

    if (value.isEmpty) return null;

    final n = double.tryParse(value);

    if (n == null || !n.isFinite || n < 0) {
      return null;
    }

    return n;
  }

  String get total {
    double n = 0;

    for (int d = 1; d <= days; d++) {
      n += parse(
        (entry(d)['h'] ?? '').toString(),
      ) ?? 0;
    }

    return n
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  void update(int d, String field, String value) {
    setState(() {
      final e = entry(d);
      e[field] = value;
      records[keyFor(d)] = e;
    });

    widget.prefs.setString(
      'diary',
      jsonEncode(records),
    );
  }

  void shift(int n) {
    FocusScope.of(context).unfocus();

    setState(() {
      month = DateTime(
        month.year,
        month.month + n,
      );
    });
  }

  void currentMonth() {
    FocusScope.of(context).unfocus();

    setState(() {
      month = DateTime(
        DateTime.now().year,
        DateTime.now().month,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pracovní deník'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Aktuální měsíc',
            onPressed: currentMonth,
            icon: const Icon(Icons.today),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => shift(-1),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 30,
                    ),
                  ),
                  Text(
                    '${months[month.month - 1]} ${month.year}',
                    style: Theme.of(context)
                        .textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => shift(1),
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color: Theme.of(context)
                  .colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Celkem za měsíc',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$total h',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                12, 12, 12, 6,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      'Den',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 85,
                    child: Text(
                      'Hodiny',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Místo / poznámka',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            Expanded(
              child: ListView.builder(
                key: ValueKey(prefix),
                itemCount: days,
                itemBuilder: (context, i) {
                  final d = i + 1;

                  final date = DateTime(
                    month.year,
                    month.month,
                    d,
                  );

                  final e = entry(d);
                  final h = (e['h'] ?? '').toString();
                  final note =
                      (e['note'] ?? '').toString();

                  final weekend = date.weekday >= 6;

                  final today = DateTime.now();

                  final isToday =
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return Container(
                    color: isToday
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(80)
                        : null,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$d.${month.month}.',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 15,
                                  color: weekend
                                      ? Colors.orange
                                      : null,
                                ),
                              ),
                              Text(
                                weekdays[
                                    date.weekday - 1],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: weekend
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: 85,
                          child: TextFormField(
                            key: ValueKey(
                              '${keyFor(d)}-hours',
                            ),
                            initialValue: h,
                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              border:
                                  const OutlineInputBorder(),
                              hintText: '0',
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 13,
                              ),
                              errorText:
                                  h.trim().isNotEmpty &&
                                          parse(h) == null
                                      ? 'Číslo'
                                      : null,
                            ),
                            onChanged: (v) {
                              update(d, 'h', v);
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              '${keyFor(d)}-note',
                            ),
                            initialValue: note,
                            minLines: 1,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(
                              border:
                                  OutlineInputBorder(),
                              hintText: 'Kde / co',
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 13,
                              ),
                            ),
                            onChanged: (v) {
                              update(d, 'note', v);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Záznamy se ukládají automaticky.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
