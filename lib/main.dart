import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/progress/file_progress_repository.dart';
import 'ui/murdoku_app.dart';
import 'ui/session/game_progress_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GameProgressStore.instance.enablePersistence(
    FileProgressRepository(directory: getApplicationSupportDirectory),
  );
  runApp(const MurdokuApp());
}
