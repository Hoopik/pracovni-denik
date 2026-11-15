import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, title: 'Pracovní deník', theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.light), darkTheme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.dark), home: Diary(prefs: prefs)));
}
class Diary extends StatefulWidget {
  final SharedPreferences prefs;
  const Diary({super.key, required this.prefs});
  @override State<Diary> createState() => _DiaryState();
}
class _DiaryState extends State<Diary> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String,dynamic> records = {};
  static const months = ['Leden','Únor','Březen','Duben','Květen','Červen','Červenec','Srpen','Září','Říjen','Listopad','Prosinec'];
  static const weekdays = ['Po','Út','St','Čt','Pá','So','Ne'];
  @override void initState() { super.initState(); try { records = Map<String,dynamic>.from(jsonDecode(widget.prefs.getString('diary') ?? '{}')); } catch (_) {} }
  String get prefix => '${month.year}-${month.month}-';
