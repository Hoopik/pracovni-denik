
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pracovní deník',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
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
    'Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne',
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

  String two(int n) =>
      n.toString().padLeft(2, '0');

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
        } else if (value.isEmpty) {
          e['h'] = '';
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

  // KOPIROVANI MESICE DO WHATSAPPU

  Future<void> copyMonth() async {
    FocusScope.of(context).unfocus();

    final text = StringBuffer();

    text.writeln(
      'PRACOVNÍ DENÍK – '
      '${months[month.month - 1].toUpperCase()} '
      '${month.year}',
    );

    text.writeln();

    int count = 0;

    for (int d = 1; d <= days; d++) {
      final e = entry(d);

      final h =
          (e['h'] ?? '').toString().trim();

      final from =
          (e['from'] ?? '').toString().trim();

      final to =
          (e['to'] ?? '').toString().trim();

      final note =
          (e['note'] ?? '').toString().trim();

      if (h.isEmpty &&
          from.isEmpty &&
          to.isEmpty &&
          note.isEmpty) {
        continue;
      }

      final date = DateTime(
        month.year,
        month.month,
        d,
      );

      final day = weekdays[date.weekday - 1];

      final time = from.isEmpty && to.isEmpty
          ? '–'
          : '${from.isEmpty ? "?" : from}'
            '–${to.isEmpty ? "?" : to}';

      final hours = h.isEmpty ? '–' : '$h h';

      text.writeln(
        '$d.${month.month}. $day | '
        '$time | $hours | '
        '${note.isEmpty ? "–" : note}',
      );

      count++;
    }

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tento měsíc je prázdný.'),
        ),
      );

      return;
    }

    text.writeln();
    text.writeln('CELKEM: $total h');

    await Clipboard.setData(
      ClipboardData(text: text.toString()),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Měsíc zkopírován! '
          'Nyní ho můžeš vložit do WhatsAppu.',
        ),
      ),
    );
  }

  // NASTAVENI

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

                        if (value) {
                          for (final key
                              in records.keys.toList()) {
                            final e =
                                Map<String, dynamic>.from(
                              records[key],
                            );

                            final hours =
                                calculateHours(
                              (e['from'] ?? '')
                                  .toString(),
                              (e['to'] ?? '')
                                  .toString(),
                            );

                            if (hours != null) {
                              e['h'] =
                                  formatHours(hours);
                              records[key] = e;
                            }
                          }
                        }
                      });

                      dialogSetState(() {});

                      widget.prefs.setBool(
                        'autoHours',
                        value,
                      );

                      save();
                    },
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Po vypnutí automatického '
                    'výpočtu můžeš zadávat čas '
                    'a počet hodin nezávisle.',
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Čas se vybírá rolováním '
                    'hodin a minut nebo pomocí '
                    'klávesnice.',
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

  // VYBER CASU

  Future<void> pickTime(
    int d,
    String field,
  ) async {
    FocusScope.of(context).unfocus();

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

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return TimeWheelSheet(
          initial: initial,
          title: field == 'from'
              ? 'Začátek směny'
              : 'Konec směny',
        );
      },
    );

    if (!mounted ||
        result == null ||
        prefix != selectedMonth) {
      return;
    }

    if (result == 'clear') {
      update(d, field, '');
      return;
    }

    if (result.startsWith('keyboard:')) {
      final value = result.substring(9);
      final selected = parseTime(value);

      final keyboardInitial = selected != null
          ? TimeOfDay(
              hour: selected ~/ 60,
              minute: selected % 60,
            )
          : initial;

      final picked = await showTimePicker(
        context: context,
        initialTime: keyboardInitial,
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

      update(
        d,
        field,
        '${two(picked.hour)}:${two(picked.minute)}',
      );

      return;
    }

    update(d, field, result);
  }

  Widget timeButton(
    int d,
    String field,
    String value,
  ) {
    return SizedBox(
      height: 38,
      width: 78,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 12,
      ),
    );
  }

  // HLAVNI OBRAZOVKA

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pracovní deník',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Kopírovat měsíc',
            onPressed: copyMonth,
            icon: const Icon(Icons.copy_all),
          ),
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

            // PREPINANI MESICU

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

            // MESICNI SOUCET

            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color: colors.primaryContainer,
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

            // KOPIROVAT MESIC

            Padding(
              padding: const EdgeInsets.fromLTRB(
                12, 2, 12, 6,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: copyMonth,
                  icon: const Icon(Icons.copy),
                  label: const Text(
                    'Kopírovat měsíc jako text',
                  ),
                ),
              ),
            ),

            // STAV AUTOMATIKY

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
                    color: colors.primary,
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

            // HLAVICKA TABULKY

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

            // SEZNAM DNI

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
                        ? colors.primaryContainer
                            .withAlpha(80)
                        : null,

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),

                    child: Row(
                      children: [

                        // DATUM

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

                        // CAS OD DO

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

                        // HODINY

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
                                    color: colors
                                        .secondaryContainer,
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
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

                                  inputFormatters: [
                                    FilteringTextInputFormatter
                                        .allow(
                                      RegExp(r'[0-9,.]'),
                                    ),
                                  ],

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

                        // POZNAMKA

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
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ROLOVACI VYBER CASU

class TimeWheelSheet extends StatefulWidget {
  final TimeOfDay initial;
  final String title;

  const TimeWheelSheet({
    super.key,
    required this.initial,
    required this.title,
  });

  @override
  State<TimeWheelSheet> createState() =>
      _TimeWheelSheetState();
}

class _TimeWheelSheetState
    extends State<TimeWheelSheet> {

  late int selectedHour;
  late int selectedMinute;

  late FixedExtentScrollController hourController;
  late FixedExtentScrollController minuteController;

  @override
  void initState() {
    super.initState();

    selectedHour = widget.initial.hour;
    selectedMinute = widget.initial.minute;

    hourController = FixedExtentScrollController(
      initialItem: selectedHour,
    );

    minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }

  String two(int n) =>
      n.toString().padLeft(2, '0');

  String get selectedTime =>
      '${two(selectedHour)}:${two(selectedMinute)}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16, 0, 16, 16,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // TITULEK A KLAVESNICE

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme.titleLarge,
                  ),

                  IconButton(
                    tooltip: 'Zadat klávesnicí',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        'keyboard:$selectedTime',
                      );
                    },
                    icon: const Icon(Icons.keyboard),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // VELKY NAHLED CASU

              Text(
                selectedTime,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Hodiny',
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(width: 20),

                  SizedBox(
                    width: 100,
                    child: Text(
                      'Minuty',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              // KOLECKA

              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    // HODINY

                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        scrollController:
                            hourController,

                        itemExtent: 44,
                        looping: true,

                        onSelectedItemChanged: (v) {
                          setState(() {
                            selectedHour = v;
                          });
                        },

                        children: List.generate(
                          24,
                          (i) => Center(
                            child: Text(
                              two(i),
                              style: TextStyle(
                                fontSize: 28,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 20,
                      child: Center(
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // MINUTY

                    SizedBox(
                      width: 100,
                      child: CupertinoPicker(
                        scrollController:
                            minuteController,

                        itemExtent: 44,
                        looping: true,

                        onSelectedItemChanged: (v) {
                          setState(() {
                            selectedMinute = v;
                          });
                        },

                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              two(i),
                              style: TextStyle(
                                fontSize: 28,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // POTVRDIT

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      selectedTime,
                    );
                  },
                  child: const Text('Potvrdit'),
                ),
              ),

              // RUCNI ZADAVANI

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      'keyboard:$selectedTime',
                    );
                  },
                  icon: const Icon(Icons.keyboard),
                  label: const Text(
                    'Zadat čas klávesnicí',
                  ),
                ),
              ),

              // VYMAZAT CAS

              TextButton(
                onPressed: () {
                  Navigator.pop(context, 'clear');
                },
                child: const Text('Vymazat čas'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
