library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/settings.dart';
import 'services/progress.dart';
import 'services/ads.dart';
import 'services/audio.dart';
import 'services/iap.dart';
import 'screens/home_screen.dart';
import 'widgets/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  final settings = Settings();
  final progress = Progress();
  await settings.load();
  await progress.load();

  final ads = AdService(settings);
  final iap = IapService(settings);
  final audio = AudioService(settings);
  AudioService.install(audio);
  // Non-blocking: the game must open instantly, with or without a network.
  unawaited(ads.init());
  unawaited(iap.init());
  // Audio init touches platform channels; never block first paint on it.
  unawaited(audio.init());

  runApp(FutoshikiApp(
      settings: settings, progress: progress, ads: ads, iap: iap));
}

class FutoshikiApp extends StatelessWidget {
  final Settings settings;
  final Progress progress;
  final AdService ads;
  final IapService iap;
  const FutoshikiApp({
    super.key,
    required this.settings,
    required this.progress,
    required this.ads,
    required this.iap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Large Print Futoshiki',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(highContrast: settings.highContrast),
        darkTheme: AppTheme.dark(highContrast: settings.highContrast),
        themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: HomeScreen(
            settings: settings, progress: progress, ads: ads, iap: iap),
      ),
    );
  }
}
