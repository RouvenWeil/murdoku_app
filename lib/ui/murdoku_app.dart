import 'package:flutter/material.dart';

import 'design/murdoku_theme.dart';
import 'screens/case_selection_screen.dart';

class MurdokuApp extends StatelessWidget {
  const MurdokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Murdoku',
      debugShowCheckedModeBanner: false,
      theme: MurdokuTheme.dark(),
      home: const CaseSelectionScreen(),
    );
  }
}
