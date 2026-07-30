/// Persisted preferences. The app OPENS large; users can shrink it if they
/// want. Competing puzzle apps ship small type and expect people to hunt for
/// a settings screen.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _kFont = 'font_scale';
  static const _kContrast = 'high_contrast';
  static const _kDark = 'dark_mode';
  static const _kHaptics = 'haptics';
  static const _kAdFree = 'ad_free';
  static const _kMistakes = 'show_mistakes';
  static const _kHighlight = 'highlight_peers';
  static const _kSeen = 'seen_tutorial';

  SharedPreferences? _p;

  double _fontScale = 1.15;
  bool _highContrast = false;
  bool _darkMode = false;
  bool _haptics = true;
  bool _adFree = false;
  /// Flag wrong entries immediately. ON by default: finding an error 20 moves
  /// later means unpicking the whole grid.
  bool _showMistakes = true;
  /// Shade the row and column of the selected cell - the main scanning aid.
  bool _highlightPeers = true;
  bool _seenTutorial = false;

  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;
  bool get darkMode => _darkMode;
  bool get haptics => _haptics;
  bool get adFree => _adFree;
  bool get showMistakes => _showMistakes;
  bool get highlightPeers => _highlightPeers;
  bool get seenTutorial => _seenTutorial;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _fontScale = _p?.getDouble(_kFont) ?? 1.15;
    _highContrast = _p?.getBool(_kContrast) ?? false;
    _darkMode = _p?.getBool(_kDark) ?? false;
    _haptics = _p?.getBool(_kHaptics) ?? true;
    _adFree = _p?.getBool(_kAdFree) ?? false;
    _showMistakes = _p?.getBool(_kMistakes) ?? true;
    _highlightPeers = _p?.getBool(_kHighlight) ?? true;
    _seenTutorial = _p?.getBool(_kSeen) ?? false;
    notifyListeners();
  }

  Future<void> _set(String k, Object v) async {
    if (v is bool) await _p?.setBool(k, v);
    if (v is double) await _p?.setDouble(k, v);
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.85, 1.6);
    await _set(_kFont, _fontScale);
  }

  Future<void> setHighContrast(bool v) async { _highContrast = v; await _set(_kContrast, v); }
  Future<void> setDarkMode(bool v) async { _darkMode = v; await _set(_kDark, v); }
  Future<void> setHaptics(bool v) async { _haptics = v; await _set(_kHaptics, v); }
  Future<void> setAdFree(bool v) async { _adFree = v; await _set(_kAdFree, v); }
  Future<void> setShowMistakes(bool v) async { _showMistakes = v; await _set(_kMistakes, v); }
  Future<void> setHighlightPeers(bool v) async { _highlightPeers = v; await _set(_kHighlight, v); }
  Future<void> markTutorialSeen() async { _seenTutorial = true; await _set(_kSeen, true); }
}
