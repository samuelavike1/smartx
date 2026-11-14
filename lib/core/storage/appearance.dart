import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'progress.dart';

/// System, Light or Dark, chosen on Profile and saved. System (the default)
/// follows the phone.
final appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>(
  AppearanceController.new,
);

class AppearanceController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(progressRepositoryProvider).themeMode;
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> choose(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(progressRepositoryProvider).saveThemeMode(mode.name);
  }
}
