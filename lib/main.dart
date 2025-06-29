import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/run_record.dart';
import 'pages/tracking_page.dart';
import 'pages/history_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(RunRecordAdapter());
  await Hive.openBox<RunRecord>('run_records');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunMinder',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TrackingPage(),
      routes: {HistoryPage.routeName: (_) => const HistoryPage()},
    );
  }
}
