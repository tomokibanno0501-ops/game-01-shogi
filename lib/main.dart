import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/shogi_board_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 画面向きは縦持ちに固定する（回転してもレイアウトが崩れないようにする）。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ゆる将棋',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゆる将棋')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ShogiBoardWidget(),
          ),
        ),
      ),
    );
  }
}
