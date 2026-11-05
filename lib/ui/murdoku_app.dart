import 'package:flutter/material.dart';

import 'screens/case_selection_screen.dart';

class MurdokuApp extends StatelessWidget {
  const MurdokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Murdoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75B9BA),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF302F3D),
      ),
      home: const CaseSelectionScreen(),
    );
  }
}
