import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'home.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  BatteryMonitor. requestNotificationPermission();
  BatteryMonitor.initNotification();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BatteryMonitor(),
    );
  }
}