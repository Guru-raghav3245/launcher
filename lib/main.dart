import 'package:flutter/material.dart';

import 'shell/launcher_shell.dart';

void main() {
  runApp(const YinYangLauncherApp());
}

class YinYangLauncherApp extends StatelessWidget {
  const YinYangLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yin Yang Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.black)),
      home: const LauncherShell(),
    );
  }
}
