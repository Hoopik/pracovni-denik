
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
  bool autoHours = true;

  static const months = [
    'Leden', 'Únor', 'Březen', 'Duben',
    'Květen', 'Červen', 'Červenec', 'Srpen',
    'Září', 'Říjen', 'Listopad', 'Prosinec',
  ];

  static const weekdays = [
    'Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'
  ];

  @override
  void initState() {
    super.initState();

    autoHours =
        widget.prefs.getBool('autoHours') ?? true;

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

  String formatHours(double n) {
    return n
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  int? parseTime(String s) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(s.trim());

    if (match == null) return null;

    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);

    if (h > 23 || m > 59) return null;

    return h * 60 + m;
  }

  double? calculateHours(
    String from,
    String to,
  ) {
    final start = parseTime(from);
    final end = parseTime(to);

    if (start == null || end == null) {
      return null;
    }

    int minutes = end - start;

    if (minutes < 0) {
      minutes += 24 * 60;
    }

    return minutes / 60;
  }

  String get total {
    double n = 0;

    for (int d = 1; d <= days; d++) {
      n += parse(
        (entry(d)['h'] ?? '').toString(),
      ) ?? 0;
    }

    return formatHours(n);
  }

  void save() {
    widget.prefs.setString(
      'diary',
      jsonEncode(records),
    );
  }

  void update(
    int d,
    String field,
    String value,
  ) {
    setState(() {
      final e = entry(d);
      e[field] = value;

      if (autoHours &&
          (field == 'from' || field == 'to')) {
        final hours = calculateHours(
          (e['from'] ?? '').toString(),
          (e['to'] ?? '').toString(),
        );

        if (hours != null) {
          e['h'] = formatHours(hours);
        }
      }

      records[keyFor(d)] = e;
    });

    save();
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

  void openSettings() {
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Nastavení'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Automatický výpočet hodin',
                    ),
                    subtitle: const Text(
                      'Vypočítá hodiny podle '
                      'začátku a konce směny.',
                    ),
                    value: autoHours,
                    onChanged: (value) {
                      setState(() {
                        autoHours = value;
                      });

                      dialogSetState(() {});

                      widget.prefs.setBool(
                        'autoHours',
                        value,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pokud automatický výpočet '
                    'vypneš, můžeš zadávat čas '
                    'a počet hodin nezávisle.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Přestávky se automaticky '
                    'neodečítají.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hotovo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> pickTime(
    int d,
    String field,
  ) async {
    final selectedMonth = prefix;
    final e = entry(d);
    final old = (e[field] ?? '').toString();
    final minutes = parseTime(old);

    final initial = minutes != null
        ? TimeOfDay(
            hour: minutes ~/ 60,
            minute: minutes % 60,
          )
        : TimeOfDay(
            hour: field == 'from' ? 7 : 15,
            minute: 0,
          );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: field == 'from'
          ? 'Začátek směny'
          : 'Konec směny',
      hourLabelText: 'Hodiny',
      minuteLabelText: 'Minuty',
      cancelText: 'Zrušit',
      confirmText: 'Potvrdit',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (!mounted ||
        picked == null ||
        prefix != selectedMonth) {
      return;
    }

    final h = picked.hour
        .toString()
        .padLeft(2, '0');

    final m = picked.minute
        .toString()
        .padLeft(2, '0');

    update(d, field, '$h:$m');
  }

  Widget timeButton(
    int d,
    String field,
    String value,
  ) {
    return SizedBox(
      height: 34,
      width: 78,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        onPressed: () => pickTime(d, field),
        child: Text(
          value.isEmpty
              ? (field == 'from' ? 'Od' : 'Do')
              : value,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 12,
      ),
    );
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
          IconButton(
            tooltip: 'Nastavení',
            onPressed: openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
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
                    '${months[month.month - 1]} '
                    '${month.year}',
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
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                10, 4, 10, 8,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    autoHours
                        ? Icons.auto_awesome
                        : Icons.edit,
                    size: 15,
                    color: Theme.of(context)
                        .colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    autoHours
                        ? 'Automatický výpočet zapnutý'
                        : 'Ruční zadávání hodin',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                8, 6, 8, 6,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 47,
                    child: Text(
                      'Datum',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      'Čas od–do',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 65,
                    child: Text(
                      'Hodiny',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Kde / co',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView.separated(
                key: ValueKey(prefix),
                itemCount: days,
                separatorBuilder: (context, i) {
                  return const Divider(height: 1);
                },
                itemBuilder: (context, i) {
                  final d = i + 1;
                  final date = DateTime(
                    month.year,
                    month.month,
                    d,
                  );

                  final e = entry(d);

                  final h =
                      (e['h'] ?? '').toString();
                  final note =
                      (e['note'] ?? '').toString();
                  final from =
                      (e['from'] ?? '').toString();
                  final to =
                      (e['to'] ?? '').toString();

                  final hasTimes =
                      calculateHours(from, to) != null;

                  final locked = autoHours && hasTimes;
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
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 47,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$d.${month.month}.',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 14,
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
                          width: 78,
                          child: Column(
                            children: [
                              timeButton(
                                d, 'from', from,
                              ),
                              const SizedBox(height: 4),
                              timeButton(
                                d, 'to', to,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        SizedBox(
                          width: 65,
                          child: locked
                              ? Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 13,
                                    horizontal: 5,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme
                                        .secondaryContainer,
                                    borderRadius:
                                        BorderRadius
                                            .circular(7),
                                  ),
                                  child: Text(
                                    h,
                                    textAlign:
                                        TextAlign.center,
                                    style:
                                        const TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                )
                              : TextFormField(
                                  key: ValueKey(
                                    '${keyFor(d)}-hours',
                                  ),
                                  initialValue: h,
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal: true,
                                  ),
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      const TextStyle(
                                    fontSize: 14,
                                  ),
                                  decoration:
                                      fieldDecoration('0'),
                                  onChanged: (v) {
                                    update(d, 'h', v);
                                  },
                                ),
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              '${keyFor(d)}-note',
                            ),
                            initialValue: note,
                            minLines: 2,
                            maxLines: 5,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                            decoration:
                                fieldDecoration(
                              'Kde / co',
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

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Záznamy se ukládají automaticky.',
                style: TextStyle(
                  fontSize: 11,
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
