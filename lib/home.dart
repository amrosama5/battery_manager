import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryMonitor extends StatefulWidget {
  @override
  _BatteryMonitorState createState() => _BatteryMonitorState();

  static Future<void> requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initNotification() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  static handleForGroundMessaging(title, body) {
    flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          icon: "ic_launcher",
        ),
      ),
    );
  }
}

class _BatteryMonitorState extends State<BatteryMonitor> {
  final Battery _battery = Battery();
  late AudioPlayer _audioPlayer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _alertTimer;
  int _batteryLevel = 100;
  bool _isMonitoring = false;
  bool _isPlayingSound = false;
  bool _isWaiting = false;
  bool _isLoading = false;
  bool _hasShownDialog = false; // Ensure dialog shows only once

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _batteryStateSubscription =
        _battery.onBatteryStateChanged.listen(_onBatteryStateChanged);
    _checkBatteryLevel();
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    _alertTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkBatteryLevel() async {
    final level = await _battery.batteryLevel;
    final isCharging = await _battery.batteryState == BatteryState.charging;
    setState(() {
      _batteryLevel = level;
    });

    if (_batteryLevel <= 20 && !_hasShownDialog) {
      if (_isMonitoring) {
        if (!isCharging) {
          if (!_isPlayingSound) {
            _playAlertSound();
          }
          _showLowBatteryDialog();
        }
      }
    } else {
      _alertTimer?.cancel();
      if (_isPlayingSound) {
        _audioPlayer.stop();
        setState(() {
          _isPlayingSound = false;
        });
      }
    }
  }

  void _onBatteryStateChanged(BatteryState state) async {
    final level = await _battery.batteryLevel;
    final isCharging = await _battery.batteryState == BatteryState.charging;
    setState(() {
      _batteryLevel = level;
    });

    if (isCharging) {
      if (_isPlayingSound) {
        _audioPlayer.stop();
        setState(() {
          _isPlayingSound = false;
        });
      }
      _alertTimer?.cancel();
    } else {
      if (_batteryLevel <= 20 && !_hasShownDialog) {
        if (_isMonitoring) {
          if (!_isPlayingSound) {
            _playAlertSound();
          }
          _showLowBatteryDialog();
        }
      } else {
        _alertTimer?.cancel();
        if (_isPlayingSound) {
          _audioPlayer.stop();
          setState(() {
            _isPlayingSound = false;
          });
        }
      }
    }
  }

  void _startTimerAfterSound() {
    _alertTimer = Timer(const Duration(minutes: 1), () {
      if (_isMonitoring) {
        _checkBatteryLevel();
      }
    });
  }

  Future<void> _playAlertSound() async {
    final isCharging = await _battery.batteryState == BatteryState.charging;
    if (!_isMonitoring || _batteryLevel > 20 || _isPlayingSound || isCharging)
      return;

    setState(() {
      _isPlayingSound = true;
    });

    await _audioPlayer.setSource(AssetSource('samsung_note_21.mp3'));
    await _audioPlayer.resume();

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlayingSound = false;
      });
      _startTimerAfterSound();
    });
  }

  Future<void> _showLowBatteryDialog() async {
    final isCharging = await _battery.batteryState == BatteryState.charging;
    if (!isCharging) {
      setState(() {
        _hasShownDialog = true;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Low Battery'),
            content: const Text(
                'Battery level is 20% or below. Please charge your phone.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      setState(() {
        _isLoading = true;
      });

      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _isLoading = false;
          _isMonitoring = false;
          _isWaiting = false;
          _alertTimer?.cancel();
          _hasShownDialog = false; // Reset dialog flag
          BatteryMonitor.handleForGroundMessaging(
              "Battery Manger", "Monitoring stopped");
          if (_isPlayingSound) {
            _audioPlayer.stop();
            _isPlayingSound = false;
          }
        });
      });
    } else {
      setState(() {
        _isWaiting = true;
      });
      BatteryMonitor.handleForGroundMessaging(
          "Battery Manger", "Monitoring started");
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _isMonitoring = true;
          _isWaiting = false;
        });
        _checkBatteryLevel();
      });
    }
  }

  void _exitApp() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    String statusText;
    Color buttonColor;
    IconData buttonIcon;

    if (_isLoading) {
      statusText = "جارٍ إلغاء التفعيل...";
      buttonColor = Colors.red;
      buttonIcon = Icons.hourglass_empty;
    } else if (_isMonitoring) {
      statusText = "حالة تتبع البطارية مفعلة";
      buttonColor = Colors.green;
      buttonIcon = Icons.stop;
    } else if (_isWaiting) {
      statusText = "انتظار...";
      buttonColor = Colors.red;
      buttonIcon = Icons.hourglass_empty;
    } else {
      statusText = "حالة تتبع البطارية غير مفعلة";
      buttonColor = Colors.grey;
      buttonIcon = Icons.play_arrow;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Battery Manager',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        actions: [
          Row(
            children: [
              Text('$_batteryLevel%',
                  style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(width: 5),
              Icon(
                _batteryLevel <= 20 ? Icons.battery_alert : Icons.battery_full,
                size: 24,
                color: _batteryLevel <= 20 ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.red,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Battery Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  Spacer(),
                  Align(
                      alignment: Alignment.bottomRight,
                      child: Text("by shushan team",style: TextStyle(color: Colors.white),)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit'),
              onTap: () {
                _exitApp;
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              statusText,
              style: TextStyle(fontSize: screenHeight * 0.03),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: screenWidth * 0.4,
              height: screenHeight * 0.15,
              child: FloatingActionButton(
                onPressed: _toggleMonitoring,
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(70),
                ),
                child: Icon(
                  buttonIcon,
                  size: screenHeight * 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
